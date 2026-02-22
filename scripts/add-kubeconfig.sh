#!/usr/bin/env bash
# add-kubeconfig.sh — fetch CA cert from CAPI-generated kubeconfig secret and
# add an OIDC context to the local kubeconfig.
#
# Usage:  ./scripts/add-kubeconfig.sh <cluster-name>
#   or:   task add-kubeconfig CLUSTER=gitlab
#
# The CAPI kubeconfig secret (proxmox-<name>-kubeconfig) is created automatically
# by Cluster API in namespace <name>-cluster on the main cluster.

set -euo pipefail

CLUSTER="${1:-${CLUSTER:-}}"
if [[ -z "$CLUSTER" ]]; then
  echo "ERROR: cluster name is required."
  echo "Usage: $0 <cluster-name>   or   task add-kubeconfig CLUSTER=<name>"
  exit 1
fi

KUBECONFIG_FILE="${HOME}/.kube/config"

CAPI_CLUSTER="proxmox-${CLUSTER}"
NS="${CLUSTER}-cluster"
SECRET_NAME="${CAPI_CLUSTER}-kubeconfig"

echo "==> Fetching CAPI kubeconfig secret: ${SECRET_NAME} (ns: ${NS})"

RAW_VALUE="$(kubectl get secret "${SECRET_NAME}" -n "${NS}" -o jsonpath='{.data.value}' 2>/dev/null)"
if [[ -z "$RAW_VALUE" ]]; then
  echo "ERROR: Secret '${SECRET_NAME}' not found in namespace '${NS}'."
  echo "       Make sure the cluster has been bootstrapped and CAPI created the secret."
  exit 1
fi

echo "==> Patching local kubeconfig: ${KUBECONFIG_FILE}"

python3 - "$RAW_VALUE" "$CAPI_CLUSTER" "$KUBECONFIG_FILE" << 'PYEOF'
import base64, yaml, sys, json

raw_value, capi_cluster, kc_path = sys.argv[1], sys.argv[2], sys.argv[3]

# Parse the CAPI-generated kubeconfig stored in the secret
capi_kc = yaml.safe_load(base64.b64decode(raw_value).decode())
ca_data = capi_kc["clusters"][0]["cluster"]["certificate-authority-data"]
server  = capi_kc["clusters"][0]["cluster"]["server"]

with open(kc_path) as f:
    kc = yaml.safe_load(f) or {}

kc.setdefault("clusters", [])
kc.setdefault("users", [])
kc.setdefault("contexts", [])

# Replace cluster entry (idempotent)
kc["clusters"] = [c for c in kc["clusters"] if c["name"] != capi_cluster]
kc["clusters"].append({
    "name": capi_cluster,
    "cluster": {
        "certificate-authority-data": ca_data,
        "server": server,
    },
})

# Add shared `oidc` user once
if not any(u["name"] == "oidc" for u in kc["users"]):
    kc["users"].append({
        "name": "oidc",
        "user": {
            "exec": {
                "apiVersion": "client.authentication.k8s.io/v1",
                "command": "kubectl",
                "args": [
                    "oidc-login", "get-token",
                    "--oidc-issuer-url=https://authentik.local.m1xxos.tech/application/o/k8s/",
                    "--oidc-client-id=k8s",
                    "--oidc-extra-scope=profile",
                    "--oidc-extra-scope=email",
                    "--oidc-extra-scope=groups",
                ],
            }
        },
    })

# Replace context entry (idempotent)
context_name = f"oidc@{capi_cluster}"
kc["contexts"] = [c for c in kc["contexts"] if c["name"] != context_name]
kc["contexts"].append({
    "name": context_name,
    "context": {
        "cluster": capi_cluster,
        "namespace": "default",
        "user": "oidc",
    },
})

with open(kc_path, "w") as f:
    yaml.dump(kc, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

print(f"  ✓ Context 'oidc@{capi_cluster}' added/updated in {kc_path}")
print(f"  ✓ Server: {server}")
PYEOF

echo "==> Done. Switch context with:"
echo "    kubectl config --kubeconfig=${KUBECONFIG_FILE} use-context oidc@${CAPI_CLUSTER}"
