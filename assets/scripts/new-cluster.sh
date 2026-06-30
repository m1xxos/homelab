#!/usr/bin/env bash
# new-cluster.sh — scaffold a new CAPI-managed Talos cluster in the homelab repo.
#
# This emits the kro `Cluster` CR (homelab.m1xxos.online/v1alpha1) — the
# ResourceGraphDefinition in clusters/main-configs/kro/cluster-rgd.yaml expands it
# into the CAPI objects, the hub-side clustermesh peer, and the `<name>-critical`
# Flux Kustomization. The script only writes the small CR plus the per-cluster
# Flux wiring and the spoke folder layout (tenant / controllers / configs).
#
# Usage: ./assets/scripts/new-cluster.sh

set -euo pipefail

# Script lives at <repo>/assets/scripts/, so the repo root is two levels up.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TASKFILE="${REPO_ROOT}/Taskfile.yml"

#######################################
# Helpers
#######################################
ask() {
  local prompt="$1" var="$2" default="${3:-}"
  if [[ -n "$default" ]]; then
    read -rp "  ${prompt} [${default}]: " _val
    printf -v "$var" '%s' "${_val:-$default}"
  else
    while true; do
      read -rp "  ${prompt}: " _val
      [[ -n "$_val" ]] && break
      echo "  (required)"
    done
    printf -v "$var" '%s' "$_val"
  fi
}

header() { echo -e "\n\033[1;34m==> $*\033[0m"; }
info()   { echo -e "  \033[0;32m✓\033[0m $*"; }
warn()   { echo -e "  \033[0;33m!\033[0m $*"; }

#######################################
# Gather inputs
#######################################
header "New Cluster — Parameters"

ask "Cluster short name (e.g. staging, prod2)"         CLUSTER_NAME
ask "DNS domain (e.g. staging.m1xxos.online)"          DNS_NAME
ask "Proxmox node name"                                PROX_NODE     "plusha"
ask "Proxmox VM template ID"                           TEMPLATE_ID   "110"

echo ""
header "Control Plane"
ask "Control plane VIP / endpoint IP"                  CP_VIP
ask "Control plane replicas"                           CP_REPLICAS   "1"
ask "CP CPU cores"                                     CP_CPU        "4"
ask "CP RAM (MiB)"                                     CP_RAM        "4096"
ask "CP disk size (GiB)"                               CP_DISK       "30"

echo ""
header "Workers"
ask "Worker replicas"                                  WK_REPLICAS   "2"
ask "Worker CPU cores"                                 WK_CPU        "4"
ask "Worker RAM (MiB)"                                 WK_RAM        "6144"
ask "Worker disk size (GiB)"                           WK_DISK       "30"
ask "Worker IP range (e.g. 192.168.1.41-192.168.1.50)" WK_IP_RANGE
ask "Pod CIDR"                                         POD_CIDR      "10.169.0.0/16"
ask "Gateway"                                          GATEWAY       "192.168.1.1"

echo ""
header "Networking / ClusterMesh"
ask "Cilium cluster ID (integer, unique per cluster)"  CILIUM_ID
ask "External/L2 IP for load balancer"                 EXTERNAL_IP
ask "ClusterMesh advertised IP"                        CLUSTERMESH_IP

echo ""
header "Versions"
ask "Kubernetes version"                               K8S_VERSION   "v1.35.0"
ask "Talos version"                                    TALOS_VERSION "v1.12.2"

# Derived names
NS="${CLUSTER_NAME}-cluster"             # namespace on main + kro-derived prefix
CAPI_CLUSTER="proxmox-${CLUSTER_NAME}"   # kro names CAPI objects proxmox-<name>
KUBECONFIG_SECRET="${CAPI_CLUSTER}-kubeconfig"

echo ""
header "Summary"
echo "  Cluster name     : ${CLUSTER_NAME}"
echo "  Namespace (main) : ${NS}"
echo "  DNS domain       : ${DNS_NAME}"
echo "  CP VIP           : ${CP_VIP}  (${CP_REPLICAS}× ${CP_CPU}C/${CP_RAM}MiB/${CP_DISK}GiB)"
echo "  Workers          : ${WK_REPLICAS}× ${WK_CPU}C/${WK_RAM}MiB/${WK_DISK}GiB  IPs: ${WK_IP_RANGE}"
echo "  Pod CIDR         : ${POD_CIDR}"
echo "  Cilium ID        : ${CILIUM_ID}   ClusterMesh IP: ${CLUSTERMESH_IP}"
echo "  External IP      : ${EXTERNAL_IP}"
echo ""
read -rp "Proceed? [y/N] " _confirm
[[ "${_confirm,,}" == "y" ]] || { echo "Aborted."; exit 0; }

#######################################
# 1. clusters/main-configs/clusters/<name>.yaml  (kro Cluster CR)
#######################################
header "Creating clusters/main-configs/clusters/${CLUSTER_NAME}.yaml"
CLUSTERS_DIR="${REPO_ROOT}/clusters/main-configs/clusters"
mkdir -p "${CLUSTERS_DIR}"

cat > "${CLUSTERS_DIR}/${CLUSTER_NAME}.yaml" << YAML
apiVersion: homelab.m1xxos.online/v1alpha1
kind: Cluster
metadata:
  name: ${CLUSTER_NAME}
  namespace: ${NS}
spec:
  controlPlane:
    replicas: ${CP_REPLICAS}
    vip: ${CP_VIP}
    cpu: ${CP_CPU}
    ramMiB: ${CP_RAM}
    diskGiB: ${CP_DISK}
  workers:
    replicas: ${WK_REPLICAS}
    cpu: ${WK_CPU}
    ramMiB: ${WK_RAM}
    diskGiB: ${WK_DISK}
    ipRange: ${WK_IP_RANGE}
  networking:
    podCidr: ${POD_CIDR}
    gateway: ${GATEWAY}
    dnsName: ${DNS_NAME}
    externalIp: ${EXTERNAL_IP}
  cilium:
    id: ${CILIUM_ID}
    clustermeshEndpoint: ${CLUSTERMESH_IP}
  proxmox:
    node: ${PROX_NODE}
    templateID: ${TEMPLATE_ID}
  versions:
    kubernetes: ${K8S_VERSION}
    talos: ${TALOS_VERSION}
YAML
info "${CLUSTER_NAME}.yaml (kro Cluster CR)"

#######################################
# 2. clusters/main-configs/clusters/<name>-flux.yaml  (Flux Kustomizations)
#######################################
# tenant + configs apply ONTO the workload cluster (kubeConfig); controllers
# applies on main and installs HelmReleases onto the workload cluster via the
# per-HelmRelease kubeConfig patch. `<name>-critical` is minted by the kro RGD.
cat > "${CLUSTERS_DIR}/${CLUSTER_NAME}-flux.yaml" << YAML
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: ${CLUSTER_NAME}-tenant
  namespace: ${NS}
spec:
  dependsOn:
  - name: flux-system
    namespace: flux-system
  interval: 10m0s
  path: ./clusters/${CLUSTER_NAME}-tenant
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  kubeConfig:
    secretRef:
      name: ${KUBECONFIG_SECRET}
  decryption:
    provider: sops
    secretRef:
      name: sops-gpg
  postBuild:
    substitute:
      CLUSTER_NAME: ${NS}
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: ${CLUSTER_NAME}-controllers
  namespace: ${NS}
spec:
  dependsOn:
  - name: ${CLUSTER_NAME}-tenant
  - name: ${CLUSTER_NAME}-critical
  targetNamespace: ${NS}
  interval: 1h
  retryInterval: 3m
  timeout: 5m
  path: ./clusters/${CLUSTER_NAME}-controllers
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  postBuild:
    substitute:
      CLUSTER_NAME: ${CLUSTER_NAME}
  patches:
  - target:
      kind: HelmRelease
    patch: |
      - op: add
        path: /spec/kubeConfig
        value:
          secretRef:
            name: ${KUBECONFIG_SECRET}
      - op: add
        path: /spec/serviceAccountName
        value: flux-cluster-admin
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: ${CLUSTER_NAME}-configs
  namespace: ${NS}
spec:
  dependsOn:
  - name: ${CLUSTER_NAME}-tenant
  - name: ${CLUSTER_NAME}-critical
  - name: ${CLUSTER_NAME}-controllers
  interval: 10m0s
  path: ./clusters/${CLUSTER_NAME}-configs
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  kubeConfig:
    secretRef:
      name: ${KUBECONFIG_SECRET}
  postBuild:
    substitute:
      DNS_NAME: ${DNS_NAME}
      CILIUM_CLUSTER_NAME: ${CLUSTER_NAME}
      CILIUM_CLUSTERMESH_ENDPOINT: "${CLUSTERMESH_IP}"
YAML
info "${CLUSTER_NAME}-flux.yaml (Flux Kustomizations)"

# Register the CR + flux files in the clusters kustomization.
CLUSTERS_KUST="${CLUSTERS_DIR}/kustomization.yaml"
for f in "${CLUSTER_NAME}.yaml" "${CLUSTER_NAME}-flux.yaml"; do
  if grep -q "^- ${f}$" "${CLUSTERS_KUST}"; then
    warn "${f} already registered, skipping."
  else
    printf -- '- %s\n' "${f}" >> "${CLUSTERS_KUST}"
    info "Registered ${f} in clusters/kustomization.yaml"
  fi
done

#######################################
# 3. clusters/<name>-tenant/  (tenant layer → infra/tenant)
#######################################
header "Creating clusters/${CLUSTER_NAME}-tenant/"
CT_DIR="${REPO_ROOT}/clusters/${CLUSTER_NAME}-tenant"
mkdir -p "${CT_DIR}/unified"

cat > "${CT_DIR}/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- unified/
# Add cluster-specific tenant resources for '${CLUSTER_NAME}' below (namespaces, RBAC, ...).
YAML

cat > "${CT_DIR}/unified/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../infra/tenant
YAML
info "clusters/${CLUSTER_NAME}-tenant/"

#######################################
# 4. clusters/<name>-controllers/  (controllers layer → infra/controllers + spoke vmagent)
#######################################
header "Creating clusters/${CLUSTER_NAME}-controllers/"
CL_DIR="${REPO_ROOT}/clusters/${CLUSTER_NAME}-controllers"
mkdir -p "${CL_DIR}/unified-controllers" "${CL_DIR}/monitoring"

cat > "${CL_DIR}/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- unified-controllers/
- monitoring/
# Add cluster-specific controllers for '${CLUSTER_NAME}' below (HelmReleases, operators, ...).
YAML

cat > "${CL_DIR}/unified-controllers/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../infra/controllers
YAML

# Spoke metrics forwarder: vmagent-only victoria-metrics-k8s-stack that scrapes
# the local node-exporter and remote-writes to main's vmsingle over ClusterMesh
# (via the vmsingle-vm stub global service in the configs layer).
cat > "${CL_DIR}/monitoring/repository.yaml" << YAML
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: vm
spec:
  interval: 1h
  url: https://victoriametrics.github.io/helm-charts/
YAML

cat > "${CL_DIR}/monitoring/vm-release.yaml" << YAML
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: vm-stack
spec:
  interval: 20m
  chart:
    spec:
      chart: victoria-metrics-k8s-stack
      version: 0.72.2
      sourceRef:
        kind: HelmRepository
        name: vm
  targetNamespace: monitoring
  valuesFrom:
  - kind: ConfigMap
    name: vm-values
    valuesKey: values.yaml
YAML

cat > "${CL_DIR}/monitoring/vm-values.yaml" << YAML
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vm-values
  labels:
    reconcile.fluxcd.io/watch: Enabled
data:
  values.yaml: |
    # Scrape-and-forward only — no local TSDB. vmagent remote-writes to main's
    # vmsingle over ClusterMesh. Everything else in the stack is off to keep the
    # memory footprint minimal (memory is the cluster bottleneck).
    nameOverride: "vm"
    fullnameOverride: "vm"
    victoria-metrics-operator:
      enabled: true
      # The Talos/Cilium apiserver can't reach the operator webhook ClusterIP
      # (EPERM :9443), which deadlocks the Helm install. Webhooks are
      # validation-only; the operator reconciles VMAgent/scrapes without them.
      admissionWebhooks:
        enabled: false
    vmsingle:
      enabled: false
    vmcluster:
      enabled: false
    vmalert:
      enabled: false
    alertmanager:
      enabled: false
    grafana:
      enabled: false
    defaultDashboards:
      enabled: false
    # Standalone node-exporter (infra/controllers/node-exporter) already runs here.
    prometheus-node-exporter:
      enabled: false
    kube-state-metrics:
      enabled: true
    vmagent:
      enabled: true
      spec:
        selectAllByDefault: true
        externalLabels:
          cluster: ${CLUSTER_NAME}
        remoteWrite:
        - url: http://vmsingle-vm.monitoring.svc.cluster.local:8428/api/v1/write
YAML

cat > "${CL_DIR}/monitoring/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: monitoring
resources:
- repository.yaml
- vm-values.yaml
- vm-release.yaml
YAML
info "clusters/${CLUSTER_NAME}-controllers/ (+ spoke vmagent)"

#######################################
# 5. clusters/<name>-configs/  (configs layer → infra/configs + cilium + stub global svcs)
#######################################
header "Creating clusters/${CLUSTER_NAME}-configs/"
CC_DIR="${REPO_ROOT}/clusters/${CLUSTER_NAME}-configs"
mkdir -p "${CC_DIR}/unified-configs" "${CC_DIR}/cilium" "${CC_DIR}/logging" "${CC_DIR}/monitoring"

cat > "${CC_DIR}/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- unified-configs/
- cilium/
- logging/
- monitoring/
# Add cluster-specific configs for '${CLUSTER_NAME}' below.
YAML

cat > "${CC_DIR}/unified-configs/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../infra/configs
YAML

# --- cilium: peer with the hub + advertise LB/clustermesh IPs ---
# Agent-facing peer config: entry is named after the REMOTE cluster (main) but
# points at the LOCAL apiserver (kvstoremesh mirrors the hub's state locally).
cat > "${CC_DIR}/cilium/external-secret-clustermesh.yaml" << YAML
---
apiVersion: v1
kind: Secret
metadata:
  name: cilium-clustermesh
  namespace: kube-system
stringData:
  main: |
    endpoints:
    - https://clustermesh-apiserver.kube-system.svc:2379
    trusted-ca-file: /var/lib/cilium/clustermesh/local-etcd-client-ca.crt
    key-file: /var/lib/cilium/clustermesh/local-etcd-client.key
    cert-file: /var/lib/cilium/clustermesh/local-etcd-client.crt
YAML

# kvstoremesh fetches the hub's etcd certs from Vault so it mirrors main locally.
cat > "${CC_DIR}/cilium/external-secret-kvstoremesh.yaml" << YAML
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cilium-kvstoremesh
  namespace: kube-system
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-general
    kind: ClusterSecretStore
  target:
    name: cilium-kvstoremesh
    creationPolicy: Owner
  dataFrom:
  - extract:
      key: clustermesh/main
YAML

cat > "${CC_DIR}/cilium/ipPool.yaml" << YAML
apiVersion: cilium.io/v2
kind: CiliumLoadBalancerIPPool
metadata:
  name: default-ippool
spec:
  blocks:
  - start: ${EXTERNAL_IP}
    stop: ${EXTERNAL_IP}
---
apiVersion: cilium.io/v2
kind: CiliumLoadBalancerIPPool
metadata:
  name: clustermesh-pool
spec:
  blocks:
  - start: ${CLUSTERMESH_IP}
    stop: ${CLUSTERMESH_IP}
  serviceSelector:
    matchLabels:
      app.kubernetes.io/name: clustermesh-apiserver
YAML

cat > "${CC_DIR}/cilium/L2Announcement.yaml" << 'YAML'
# yaml-language-server: $schema=https://datreeio.github.io/CRDs-catalog/cilium.io/ciliuml2announcementpolicy_v2alpha1.json
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: default
spec:
  nodeSelector:
    matchExpressions:
    - key: node-role.kubernetes.io/control-plane
      operator: DoesNotExist
  interfaces:
  - ^eth[0-9]+
  externalIPs: true
  loadBalancerIPs: true
YAML

cat > "${CC_DIR}/cilium/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ipPool.yaml
- L2Announcement.yaml
- external-secret-clustermesh.yaml
- external-secret-kvstoremesh.yaml
YAML

# --- stub global services: let the spoke resolve + route to main's sinks ---
cat > "${CC_DIR}/logging/vlsingle-main.yaml" << 'YAML'
---
# Stub for main's VictoriaLogs sink. Selector-less + global so CoreDNS resolves
# the name and Cilium attaches main's remote backends. The OTel logs daemonset
# (infra/configs/otel) exports here.
apiVersion: v1
kind: Service
metadata:
  name: vlsingle-main
  namespace: logging
  annotations:
    service.cilium.io/global: "true"
spec:
  ports:
  - name: http
    port: 9428
    targetPort: 9428
    protocol: TCP
YAML

cat > "${CC_DIR}/logging/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- vlsingle-main.yaml
YAML

cat > "${CC_DIR}/monitoring/vmsingle-vm.yaml" << 'YAML'
---
# Stub for main's VictoriaMetrics sink. Selector-less + global so CoreDNS resolves
# the name and Cilium attaches main's remote backends. The spoke vmagent
# (clusters/<name>-controllers/monitoring) remote-writes here.
apiVersion: v1
kind: Service
metadata:
  name: vmsingle-vm
  namespace: monitoring
  annotations:
    service.cilium.io/global: "true"
spec:
  ports:
  - name: http
    port: 8428
    targetPort: 8428
    protocol: TCP
YAML

cat > "${CC_DIR}/monitoring/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- vmsingle-vm.yaml
YAML
info "clusters/${CLUSTER_NAME}-configs/ (+ cilium, stub global svcs)"

#######################################
# 6. Add reconcile task to Taskfile.yml
#######################################
header "Updating Taskfile.yml"
if grep -q "^  ${CLUSTER_NAME}:" "${TASKFILE}"; then
  warn "Task '${CLUSTER_NAME}' already exists in Taskfile, skipping."
else
  python3 - << PYEOF
path = "${TASKFILE}"
with open(path) as f:
    content = f.read()
new_task = """  ${CLUSTER_NAME}:
    cmds:
    - flux reconcile source git flux-system
    - flux reconcile kustomization ${CLUSTER_NAME}-tenant -n ${NS}
    - flux reconcile kustomization ${CLUSTER_NAME}-critical -n ${NS}
    - flux reconcile kustomization ${CLUSTER_NAME}-controllers -n ${NS}
    - flux reconcile kustomization ${CLUSTER_NAME}-configs -n ${NS}
"""
content = content.rstrip("\n") + "\n" + new_task + "\n"
with open(path, "w") as f:
    f.write(content)
print("  updated")
PYEOF
  info "Task '${CLUSTER_NAME}' added to Taskfile.yml"
fi

#######################################
# Done
#######################################
header "Done! Files created:"
cat << EOF
  clusters/main-configs/clusters/
    ├── ${CLUSTER_NAME}.yaml        (kro Cluster CR — RGD expands to CAPI + hub peer + ${CLUSTER_NAME}-critical)
    └── ${CLUSTER_NAME}-flux.yaml   (Flux Kustomizations: tenant / controllers / configs)
  clusters/${CLUSTER_NAME}-tenant/        → infra/tenant
  clusters/${CLUSTER_NAME}-controllers/   → infra/controllers + spoke vmagent forwarder
  clusters/${CLUSTER_NAME}-configs/       → infra/configs + cilium + stub global services

  Updated: clusters/main-configs/clusters/kustomization.yaml
  Updated: ${TASKFILE}
EOF
echo ""
warn "Next steps:"
echo "  1. Commit & push — Flux applies the Cluster CR; the kro RGD provisions the VMs."
echo "  2. Once the cluster is up:   task add-kubeconfig CLUSTER=${CLUSTER_NAME}"
echo ""
echo "  The SOPS key is mirrored into ${NS} automatically by reflector — no manual copy."
echo "  (One-time per cluster lifetime: 'task enable-sops-reflection' must have been run.)"
echo "  Hub-side clustermesh peer + dhi-registry are created automatically by the"
echo "  kro RGD; Vault clustermesh/${CLUSTER_NAME} is populated by the cluster's own"
echo "  PushSecret once its configs layer reconciles."
