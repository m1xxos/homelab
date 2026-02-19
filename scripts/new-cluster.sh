#!/usr/bin/env bash
# new-cluster.sh — scaffold a new CAPI-managed Talos cluster in the homelab repo
# Usage: ./scripts/new-cluster.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECONFIG_FILE="${REPO_ROOT}/terraform/0-infra/kubeconfig"
TASKFILE="${REPO_ROOT}/Taskfile.yml"
MAIN_KVSTOREMESH="${REPO_ROOT}/clusters/main-configs/cilium/external-secret-kvstoremesh.yaml"

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

ask "Cluster short name (e.g. staging, prod2)"      CLUSTER_NAME
ask "CAPI namespace on main cluster"                 CAPI_NS       "gitlab-cluster"
ask "DNS domain (e.g. staging.m1xxos.tech)"         DNS_NAME
ask "Proxmox node name"                              PROX_NODE     "plusha"
ask "Proxmox VM template ID"                         TEMPLATE_ID   "110"

echo ""
header "Control Plane"
ask "Control plane VIP / endpoint IP"                CP_VIP
ask "Control plane replicas"                         CP_REPLICAS   "1"
ask "CP CPU cores"                                   CP_CPU        "4"
ask "CP RAM (MiB)"                                   CP_RAM        "4096"
ask "CP disk size (GiB)"                             CP_DISK       "30"

echo ""
header "Workers"
ask "Worker replicas"                                WK_REPLICAS   "2"
ask "Worker CPU cores"                               WK_CPU        "4"
ask "Worker RAM (MiB)"                               WK_RAM        "6144"
ask "Worker disk size (GiB)"                         WK_DISK       "30"
ask "Worker IP range (e.g. 192.168.1.41-192.168.1.50)" WK_IP_RANGE
ask "Pod CIDR"                                       POD_CIDR      "10.169.0.0/16"
ask "Gateway"                                        GATEWAY       "192.168.1.1"

echo ""
header "Networking / ClusterMesh"
ask "Cilium cluster ID (integer, unique per cluster)" CILIUM_ID
ask "External/L2 IP for load balancer"               EXTERNAL_IP
ask "ClusterMesh advertised IP"                      CLUSTERMESH_IP

echo ""
header "Versions"
ask "Kubernetes version"                             K8S_VERSION   "v1.35.0"
ask "Talos version"                                  TALOS_VERSION "v1.12.2"

# Derived names
NS="${CLUSTER_NAME}-cluster"          # namespace & CAPI object prefix
CAPI_CLUSTER="proxmox-${CLUSTER_NAME}"

echo ""
header "Summary"
echo "  Cluster name     : ${CLUSTER_NAME}"
echo "  Namespace        : ${NS}"
echo "  CAPI cluster     : ${CAPI_CLUSTER}"
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
# 1. clusters/main-configs/{NS}/
#######################################
header "Creating clusters/main-configs/${NS}/"
MC_DIR="${REPO_ROOT}/clusters/main-configs/${NS}"
mkdir -p "${MC_DIR}"

### namespace.yaml
cat > "${MC_DIR}/namespace.yaml" << YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${NS}
YAML
info "namespace.yaml"

### {cluster}-cluster.yaml  (CAPI objects)
cat > "${MC_DIR}/${NS}.yaml" << YAML
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: ${CAPI_CLUSTER}
  namespace: ${NS}
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
      - ${POD_CIDR}
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
    kind: TalosControlPlane
    name: ${CAPI_CLUSTER}-control-plane
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
    kind: ProxmoxCluster
    name: ${CAPI_CLUSTER}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxCluster
metadata:
  name: ${CAPI_CLUSTER}
  namespace: ${NS}
spec:
  schedulerHints:
    memoryAdjustment: 0
  allowedNodes:
  - ${PROX_NODE}
  controlPlaneEndpoint:
    host: ${CP_VIP}
    port: 6443
  dnsServers:
  - 1.1.1.1
  - 1.1.0.0
  ipv4Config:
    addresses:
    - ${WK_IP_RANGE}
    gateway: ${GATEWAY}
    prefix: 24
    metric: 100
---
apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
kind: TalosControlPlane
metadata:
  name: ${CAPI_CLUSTER}-control-plane
  namespace: ${NS}
spec:
  version: ${K8S_VERSION}
  replicas: ${CP_REPLICAS}
  infrastructureTemplate:
    kind: ProxmoxMachineTemplate
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
    name: ${CAPI_CLUSTER}-control-plane
    namespace: ${NS}
  controlPlaneConfig:
    controlplane:
      generateType: controlplane
      talosVersion: ${TALOS_VERSION}
      configPatches:
      - op: replace
        path: /machine/install
        value:
          disk: /dev/sda
      - op: add
        path: /cluster/network/cni
        value:
          name: none
      - op: add
        path: /cluster/proxy
        value:
          disabled: true
      - op: add
        path: /machine/install/extraKernelArgs
        value:
        - net.ifnames=0
      - op: add
        path: /machine/network/interfaces
        value:
        - interface: eth0
          dhcp: false
          vip:
            ip: ${CP_VIP}
      - op: add
        path: /machine/kubelet/extraArgs
        value:
          rotate-server-certificates: true
          cloud-provider: external
      - op: add
        path: /machine/features/kubernetesTalosAPIAccess
        value:
          enabled: true
          allowedRoles:
          - os:reader
          allowedKubernetesNamespaces:
          - kube-system
      - op: add
        path: /cluster/apiServer/extraArgs
        value:
          oidc-issuer-url: "https://authentik.local.m1xxos.tech/application/o/k8s/"
          oidc-client-id: "k8s"
          oidc-username-claim: name
          oidc-groups-claim: groups
          oidc-signing-algs: "ES256,RS256"
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxMachineTemplate
metadata:
  name: ${CAPI_CLUSTER}-control-plane
  namespace: ${NS}
spec:
  template:
    spec:
      disks:
        bootVolume:
          disk: scsi0
          sizeGb: ${CP_DISK}
      format: qcow2
      full: true
      memoryMiB: ${CP_RAM}
      network:
        default:
          bridge: vmbr0
          model: virtio
      numCores: ${CP_CPU}
      numSockets: 1
      sourceNode: ${PROX_NODE}
      templateID: ${TEMPLATE_ID}
      checks:
        skipCloudInitStatus: true
      metadataSettings:
        providerIDInjection: true
---
apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
kind: TalosConfigTemplate
metadata:
  name: ${CAPI_CLUSTER}-worker
  namespace: ${NS}
spec:
  template:
    spec:
      generateType: worker
      talosVersion: ${TALOS_VERSION}
      configPatches:
      - op: replace
        path: /machine/install
        value:
          disk: /dev/sda
      - op: add
        path: /machine/kubelet/extraArgs
        value:
          cloud-provider: external
      - op: add
        path: /machine/kubelet/extraArgs/rotate-server-certificates
        value: "true"
---
apiVersion: cluster.x-k8s.io/v1beta1
kind: MachineDeployment
metadata:
  name: ${CAPI_CLUSTER}-workers
  namespace: ${NS}
spec:
  clusterName: ${CAPI_CLUSTER}
  replicas: ${WK_REPLICAS}
  selector:
    matchLabels:
      cluster.x-k8s.io/cluster-name: ${CAPI_CLUSTER}
  template:
    metadata:
      labels:
        node-role.kubernetes.io/node: "worker"
        cluster.x-k8s.io/cluster-name: ${CAPI_CLUSTER}
    spec:
      bootstrap:
        configRef:
          apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
          kind: TalosConfigTemplate
          name: ${CAPI_CLUSTER}-worker
      clusterName: ${CAPI_CLUSTER}
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
        kind: ProxmoxMachineTemplate
        name: ${CAPI_CLUSTER}-worker
      version: ${K8S_VERSION}
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: ProxmoxMachineTemplate
metadata:
  name: ${CAPI_CLUSTER}-worker
  namespace: ${NS}
spec:
  template:
    spec:
      disks:
        bootVolume:
          disk: scsi0
          sizeGb: ${WK_DISK}
      format: qcow2
      full: true
      memoryMiB: ${WK_RAM}
      network:
        default:
          bridge: vmbr0
          model: virtio
      numCores: ${WK_CPU}
      numSockets: 1
      sourceNode: ${PROX_NODE}
      templateID: ${TEMPLATE_ID}
      checks:
        skipCloudInitStatus: true
      metadataSettings:
        providerIDInjection: true
YAML
info "${NS}.yaml (CAPI cluster)"

### {cluster}-flux.yaml  (Flux kustomizations)
cat > "${MC_DIR}/${CLUSTER_NAME}-flux.yaml" << YAML
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: ${CLUSTER_NAME}-cluster-tenant
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
      name: ${CAPI_CLUSTER}-kubeconfig
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
  name: ${CLUSTER_NAME}-cluster-critical
  namespace: ${NS}
spec:
  dependsOn:
  - name: ${CLUSTER_NAME}-cluster-tenant
  targetNamespace: ${NS}
  interval: 1h
  retryInterval: 3m
  timeout: 5m
  path: ./infra/critical
  prune: true
  wait: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  postBuild:
    substitute:
      CILIUM_CLUSTER_NAME: ${CLUSTER_NAME}
      CILIUM_CLUSTER_ID: "${CILIUM_ID}"
      CILIUM_CLUSTERMESH_ENDPOINT: "${CLUSTERMESH_IP}"
  patches:
  - target:
      kind: HelmRelease
    patch: |
      - op: add
        path: /spec/kubeConfig
        value:
          secretRef:
            name: ${CAPI_CLUSTER}-kubeconfig
      - op: add
        path: /spec/serviceAccountName
        value: flux-cluster-admin
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: ${CLUSTER_NAME}-cluster-infra
  namespace: ${NS}
spec:
  dependsOn:
  - name: ${CLUSTER_NAME}-cluster-tenant
  - name: ${CLUSTER_NAME}-cluster-critical
  targetNamespace: ${NS}
  interval: 1h
  retryInterval: 3m
  timeout: 5m
  path: ./clusters/${CLUSTER_NAME}
  prune: true
  wait: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  patches:
  - target:
      kind: HelmRelease
    patch: |
      - op: add
        path: /spec/kubeConfig
        value:
          secretRef:
            name: ${CAPI_CLUSTER}-kubeconfig
      - op: add
        path: /spec/serviceAccountName
        value: flux-cluster-admin
      - op: replace
        path: /metadata/namespace
        value: ${NS}
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: ${CLUSTER_NAME}-cluster-configs
  namespace: ${NS}
spec:
  dependsOn:
  - name: ${CLUSTER_NAME}-cluster-tenant
  - name: ${CLUSTER_NAME}-cluster-critical
  interval: 10m0s
  path: ./clusters/${CLUSTER_NAME}-configs
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  kubeConfig:
    secretRef:
      name: ${CAPI_CLUSTER}-kubeconfig
  postBuild:
    substitute:
      DNS_NAME: ${DNS_NAME}
      CILIUM_CLUSTER_NAME: ${CLUSTER_NAME}
      CILIUM_CLUSTERMESH_ENDPOINT: "${CLUSTERMESH_IP}"
YAML
info "${CLUSTER_NAME}-flux.yaml"

#######################################
# 2. clusters/{cluster}/  (infra)
#######################################
header "Creating clusters/${CLUSTER_NAME}/"
CL_DIR="${REPO_ROOT}/clusters/${CLUSTER_NAME}"
mkdir -p "${CL_DIR}/unified-controllers"

cat > "${CL_DIR}/unified-controllers/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../infra/controllers
YAML
info "clusters/${CLUSTER_NAME}/unified-controllers/kustomization.yaml"

#######################################
# 3. clusters/{cluster}-configs/
#######################################
header "Creating clusters/${CLUSTER_NAME}-configs/"
CC_DIR="${REPO_ROOT}/clusters/${CLUSTER_NAME}-configs"
mkdir -p "${CC_DIR}/cilium"
mkdir -p "${CC_DIR}/unified-configs"

# clustermesh secret — points to THIS cluster's local etcd
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
info "cilium/external-secret-clustermesh.yaml"

# kvstoremesh — fetches main cluster's etcd certs from Vault
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
info "cilium/external-secret-kvstoremesh.yaml"

cat > "${CC_DIR}/unified-configs/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../infra/configs
YAML
info "unified-configs/kustomization.yaml"

#######################################
# 4. clusters/{cluster}-tenant/
#######################################
header "Creating clusters/${CLUSTER_NAME}-tenant/"
CT_DIR="${REPO_ROOT}/clusters/${CLUSTER_NAME}-tenant"
mkdir -p "${CT_DIR}/unified"

cat > "${CT_DIR}/unified/kustomization.yaml" << YAML
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../../../infra/tenant
YAML
info "clusters/${CLUSTER_NAME}-tenant/unified/kustomization.yaml"

#######################################
# 5. Update main kvstoremesh (add new cluster)
#######################################
header "Updating main-configs/cilium/external-secret-kvstoremesh.yaml"

# Check if cluster already present
if grep -q "clustermesh/${CLUSTER_NAME}" "${MAIN_KVSTOREMESH}"; then
  warn "Entry for ${CLUSTER_NAME} already present in kvstoremesh, skipping."
else
  # Append a new extract entry inside dataFrom
  # We need to add before the end of file, after the last 'extract' block
  python3 - << PYEOF
import re, sys

path = "${MAIN_KVSTOREMESH}"
with open(path, "r") as f:
    content = f.read()

new_entry = """  - extract:
      key: clustermesh/${CLUSTER_NAME}
"""

# Insert before the last blank line / EOF
content = content.rstrip("\n") + "\n" + new_entry + "\n"
with open(path, "w") as f:
    f.write(content)
print("  updated")
PYEOF
  info "Added clustermesh/${CLUSTER_NAME} to kvstoremesh"
fi

#######################################
# 6. Update kubeconfig (OIDC entry)
#######################################
header "Updating kubeconfig (OIDC, no client cert)"

if grep -q "name: ${CAPI_CLUSTER}$" "${KUBECONFIG_FILE}" 2>/dev/null; then
  warn "Cluster ${CAPI_CLUSTER} already in kubeconfig, skipping."
else
  python3 - << PYEOF
import yaml, sys

path = "${KUBECONFIG_FILE}"
with open(path, "r") as f:
    kc = yaml.safe_load(f)

# --- cluster entry ---
new_cluster = {
    "cluster": {
        "certificate-authority-data": "# REPLACE_WITH_BASE64_CA_AFTER_BOOTSTRAP",
        "server": "https://${CP_VIP}:6443",
    },
    "name": "${CAPI_CLUSTER}",
}

# --- user entry (oidc via kubectl-oidc-login) ---
new_user = {
    "name": "${CAPI_CLUSTER}-oidc",
    "user": {
        "exec": {
            "apiVersion": "client.authentication.k8s.io/v1beta1",
            "command": "kubectl",
            "args": [
                "oidc-login",
                "get-token",
                "--oidc-issuer-url=https://authentik.local.m1xxos.tech/application/o/k8s/",
                "--oidc-client-id=k8s",
                "--oidc-extra-scope=profile",
                "--oidc-extra-scope=email",
                "--oidc-extra-scope=groups",
            ],
        }
    },
}

# --- context entry ---
new_context = {
    "context": {
        "cluster": "${CAPI_CLUSTER}",
        "user": "${CAPI_CLUSTER}-oidc",
    },
    "name": "${CAPI_CLUSTER}-oidc@${CAPI_CLUSTER}",
}

kc.setdefault("clusters", []).append(new_cluster)
kc.setdefault("users", []).append(new_user)
kc.setdefault("contexts", []).append(new_context)

with open(path, "w") as f:
    yaml.dump(kc, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
print("  updated")
PYEOF
  info "Added ${CAPI_CLUSTER} context to kubeconfig (OIDC)"
  warn "Remember to replace 'certificate-authority-data' in kubeconfig after cluster bootstrap!"
fi

#######################################
# 7. Add task to Taskfile.yml
#######################################
header "Updating Taskfile.yml"

TASK_NAME="${CLUSTER_NAME}"
if grep -q "^  ${TASK_NAME}:" "${TASKFILE}"; then
  warn "Task '${TASK_NAME}' already exists in Taskfile, skipping."
else
  python3 - << PYEOF
path = "${TASKFILE}"
with open(path, "r") as f:
    content = f.read()

new_task = """  ${TASK_NAME}:
    cmds:
    - flux reconcile source git flux-system
    - flux reconcile kustomization ${CLUSTER_NAME}-cluster-tenant -n ${NS}
    - flux reconcile kustomization ${CLUSTER_NAME}-cluster-critical -n ${NS}
    - flux reconcile kustomization ${CLUSTER_NAME}-cluster-infra -n ${NS}
    - flux reconcile kustomization ${CLUSTER_NAME}-cluster-configs -n ${NS}
"""

content = content.rstrip("\n") + "\n" + new_task + "\n"
with open(path, "w") as f:
    f.write(content)
print("  updated")
PYEOF
  info "Task '${TASK_NAME}' added to Taskfile.yml"
fi

#######################################
# Done
#######################################
echo ""
header "Done! Files created:"
echo "  clusters/main-configs/${NS}/"
echo "    ├── namespace.yaml"
echo "    ├── ${NS}.yaml         (CAPI Cluster, ProxmoxCluster, TalosControlPlane, MachineDeployment, ProxmoxMachineTemplates)"
echo "    └── ${CLUSTER_NAME}-flux.yaml  (Flux Kustomizations)"
echo "  clusters/${CLUSTER_NAME}/"
echo "    └── unified-controllers/kustomization.yaml"
echo "  clusters/${CLUSTER_NAME}-configs/"
echo "    ├── cilium/external-secret-clustermesh.yaml"
echo "    ├── cilium/external-secret-kvstoremesh.yaml"
echo "    └── unified-configs/kustomization.yaml"
echo "  clusters/${CLUSTER_NAME}-tenant/"
echo "    └── unified/kustomization.yaml"
echo ""
echo "  Updated: ${MAIN_KVSTOREMESH}"
echo "  Updated: ${KUBECONFIG_FILE}"
echo "  Updated: ${TASKFILE}"
echo ""
warn "Next steps:"
echo "  1. Add Vault secrets:  clustermesh/${CLUSTER_NAME}  (etcd client certs for new cluster)"
echo "  2. After cluster bootstrap, replace certificate-authority-data in kubeconfig"
echo "  3. Commit & push — Flux will pick up the new Kustomizations automatically"
