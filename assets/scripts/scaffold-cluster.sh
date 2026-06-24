#!/usr/bin/env bash
# scaffold-cluster.sh — scaffold the per-cluster folders + Flux wiring for a cluster whose
# kro `Cluster` instance lives in clusters/main-configs/clusters/<name>.yaml.
#
# Division of labour:
#   - the kro RGD (cluster-rgd.yaml) emits the CAPI objects AND the `critical` Flux Kustomization
#     (Cilium CNI / CCM / metrics-server) — so a new cluster gets its CNI as soon as the control
#     plane is up, with no dependency on this scaffolding.
#   - THIS script (run by .github/workflows/new-cluster.yml on instances under
#     clusters/main-configs/clusters/) scaffolds the per-cluster folders for cluster-specific
#     workloads + the tenant / controllers / configs Flux Kustomizations that deploy them.
#
# Renders (idempotent, scaffold-if-missing):
#   clusters/<name>-controllers/     controllers layer (unified-controllers -> infra/controllers
#                                    + monitoring/ vmagent forwarder + custom space)
#   clusters/<name>-configs/         configs layer (unified-configs -> infra/configs + cilium/
#                                    + logging/ & monitoring/ stub global services + custom space)
#   clusters/<name>-tenant/          tenant layer (unified -> infra/tenant)
#   clusters/main-configs/clusters/<name>-flux.yaml   tenant/controllers/configs Flux Kustomizations
#   + registers <name>.yaml and <name>-flux.yaml in clusters/main-configs/clusters/kustomization.yaml
#
# Inputs (env): required CLUSTER_NAME DNS_NAME EXTERNAL_IP CLUSTERMESH_IP
# (the workflow extracts these from the instance's metadata.name + spec.networking/cilium.)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

_missing=()
for v in CLUSTER_NAME DNS_NAME EXTERNAL_IP CLUSTERMESH_IP; do
  [[ -n "${!v:-}" ]] || _missing+=("$v")
done
if (( ${#_missing[@]} )); then
  echo "ERROR: missing required env vars: ${_missing[*]}" >&2
  exit 1
fi
if [[ ! "$CLUSTER_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "ERROR: CLUSTER_NAME '${CLUSTER_NAME}' must be a lowercase DNS label (a-z0-9-)." >&2
  exit 1
fi

NS="${CLUSTER_NAME}-cluster"           # namespace holding CAPI objects + kubeconfig secret
CAPI_CLUSTER="proxmox-${CLUSTER_NAME}"
KUBECONFIG_SECRET="${CAPI_CLUSTER}-kubeconfig"
CLUSTERS_DIR="clusters/main-configs/clusters"

info() { echo "  ✓ $*"; }
write() { local rel="$1"; mkdir -p "$(dirname "${REPO_ROOT}/$1")"; cat > "${REPO_ROOT}/$1"; info "$rel"; }

echo "==> Scaffolding cluster '${CLUSTER_NAME}' (namespace ${NS})"

#######################################
# 1. Per-cluster TENANT folder
#######################################
write "clusters/${CLUSTER_NAME}-tenant/unified/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../infra/tenant
YAML

write "clusters/${CLUSTER_NAME}-tenant/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- unified/
# Add cluster-specific tenant resources for '${CLUSTER_NAME}' below (namespaces, RBAC, ...).
YAML

#######################################
# 2. Per-cluster CONTROLLERS folder (clusters/<name>-controllers/)
#######################################
write "clusters/${CLUSTER_NAME}-controllers/unified-controllers/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../infra/controllers
YAML

write "clusters/${CLUSTER_NAME}-controllers/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- unified-controllers/
- monitoring/
# Add cluster-specific controllers for '${CLUSTER_NAME}' below (HelmReleases, operators, ...).
YAML

# Spoke metrics forwarder: vmagent-only victoria-metrics-k8s-stack that scrapes the
# local node-exporter and remote-writes to main's vmsingle over ClusterMesh (via the
# vmsingle-vm stub global service in the configs layer).
write "clusters/${CLUSTER_NAME}-controllers/monitoring/repository.yaml" <<YAML
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: vm
spec:
  interval: 1h
  url: https://victoriametrics.github.io/helm-charts/
YAML

write "clusters/${CLUSTER_NAME}-controllers/monitoring/vm-release.yaml" <<YAML
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

write "clusters/${CLUSTER_NAME}-controllers/monitoring/vm-values.yaml" <<YAML
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

write "clusters/${CLUSTER_NAME}-controllers/monitoring/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: monitoring
resources:
- repository.yaml
- vm-values.yaml
- vm-release.yaml
YAML

#######################################
# 3. Per-cluster CONFIGS folder (clusters/<name>-configs/)
#######################################
write "clusters/${CLUSTER_NAME}-configs/unified-configs/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../infra/configs
YAML

write "clusters/${CLUSTER_NAME}-configs/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- unified-configs/
- cilium/
- logging/
- monitoring/
# Add cluster-specific configs for '${CLUSTER_NAME}' below.
YAML

# --- cilium per-cluster: LB IP pool + L2 announcement (literal IPs) ---
write "clusters/${CLUSTER_NAME}-configs/cilium/ipPool.yaml" <<YAML
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

write "clusters/${CLUSTER_NAME}-configs/cilium/L2Announcement.yaml" <<'YAML'
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

# --- cilium per-cluster: ClusterMesh peering with the hub (main) ---
# Agent-facing peer config: the entry is named after the REMOTE cluster (main),
# NOT this one, but points at the LOCAL apiserver — kvstoremesh mirrors the hub's
# state into the local etcd. A self-named entry makes the agent treat it as the
# local cluster and report 0 remote clusters (no global-service backends).
write "clusters/${CLUSTER_NAME}-configs/cilium/external-secret-clustermesh.yaml" <<YAML
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

write "clusters/${CLUSTER_NAME}-configs/cilium/external-secret-kvstoremesh.yaml" <<YAML
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

write "clusters/${CLUSTER_NAME}-configs/cilium/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ipPool.yaml
- L2Announcement.yaml
- external-secret-clustermesh.yaml
- external-secret-kvstoremesh.yaml
YAML

# --- stub global services: let the spoke resolve + route to main's sinks over the mesh ---
write "clusters/${CLUSTER_NAME}-configs/logging/vlsingle-main.yaml" <<'YAML'
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

write "clusters/${CLUSTER_NAME}-configs/logging/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- vlsingle-main.yaml
YAML

write "clusters/${CLUSTER_NAME}-configs/monitoring/vmsingle-vm.yaml" <<'YAML'
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

write "clusters/${CLUSTER_NAME}-configs/monitoring/kustomization.yaml" <<YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- vmsingle-vm.yaml
YAML

#######################################
# 4. Flux wiring: tenant -> controllers -> configs (critical comes from the kro RGD)
#######################################
# tenant & configs: plain manifests applied directly to the workload cluster (Kustomization-level
#   kubeConfig). controllers: HelmReleases that must run on the management cluster's helm-controller,
#   so NO Kustomization kubeConfig — they are placed in ${NS} and each HelmRelease is patched with
#   kubeConfig + serviceAccountName to deploy to the workload cluster.
write "${CLUSTERS_DIR}/${CLUSTER_NAME}-flux.yaml" <<YAML
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
  # No wait: true — node-exporter here needs the dhi-registry pull secret created by
  # the configs layer, which dependsOn this one; waiting would deadlock the chain.
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

#######################################
# 5. Register the instance + flux wiring in the clusters kustomization
#######################################
KUST="${REPO_ROOT}/${CLUSTERS_DIR}/kustomization.yaml"
if [[ ! -f "$KUST" ]]; then
  printf 'apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources:\n' > "$KUST"
  info "${CLUSTERS_DIR}/kustomization.yaml (created)"
fi
for entry in "${CLUSTER_NAME}.yaml" "${CLUSTER_NAME}-flux.yaml"; do
  if grep -qE "^- ${entry}$" "$KUST"; then
    info "${CLUSTERS_DIR}/kustomization.yaml (already lists ${entry})"
  else
    printf -- '- %s\n' "$entry" >> "$KUST"
    info "${CLUSTERS_DIR}/kustomization.yaml (+ ${entry})"
  fi
done

# Ensure the clusters/ dir is reconciled by the main-configs Kustomization (one-time).
MC_KUST="${REPO_ROOT}/clusters/main-configs/kustomization.yaml"
if grep -qE "^- clusters/?$" "$MC_KUST"; then
  info "clusters/main-configs/kustomization.yaml (already lists clusters/)"
else
  printf -- '- clusters/\n' >> "$MC_KUST"
  info "clusters/main-configs/kustomization.yaml (+ clusters/)"
fi

cat <<EOF

==> Scaffolded. The kro instance (clusters/main-configs/clusters/${CLUSTER_NAME}.yaml) drives CAPI,
    the critical (CNI) layer, the dhi-registry secret AND the hub-side clustermesh peer; the folders
    above carry tenant/controllers/configs + the spoke metrics/logs forwarder. After merge:
  - Vault secret clustermesh/${CLUSTER_NAME} is populated automatically by the cluster's own PushSecret
    once Cilium is up; the hub peer is generated by the kro RGD (no manual edit needed).
  - task add-kubeconfig CLUSTER=${CLUSTER_NAME} ; task add-sops NAMESPACE=${NS}
EOF
