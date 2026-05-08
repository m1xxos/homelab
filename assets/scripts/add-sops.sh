#!/usr/bin/env bash
# add-sops.sh — copy the sops-gpg secret from flux-system to a target namespace.
#
# Flux kustomizations that use SOPS decryption reference the `sops-gpg` secret
# in whatever namespace the Kustomization object lives in.
# New CAPI-managed clusters need this secret in their management namespace on main.
#
# Usage:  ./scripts/add-sops.sh <namespace>
#   or:   task add-sops NAMESPACE=staging-cluster

set -euo pipefail

NAMESPACE="${1:-${NAMESPACE:-}}"
if [[ -z "$NAMESPACE" ]]; then
  echo "ERROR: target namespace is required."
  echo "Usage: $0 <namespace>   or   task add-sops NAMESPACE=<ns>"
  exit 1
fi

SOURCE_NS="flux-system"
SECRET_NAME="sops-gpg"

echo "==> Copying ${SOURCE_NS}/${SECRET_NAME} → ${NAMESPACE}/${SECRET_NAME}"

# Check source secret exists
if ! kubectl get secret "${SECRET_NAME}" -n "${SOURCE_NS}" &>/dev/null; then
  echo "ERROR: Secret '${SECRET_NAME}' not found in namespace '${SOURCE_NS}'."
  exit 1
fi

# Check target namespace exists
if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
  echo "ERROR: Namespace '${NAMESPACE}' does not exist."
  echo "       Create it first or wait for Flux to provision it."
  exit 1
fi

# Check if secret already exists in target
if kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  echo "  ! Secret '${SECRET_NAME}' already exists in '${NAMESPACE}', overwriting..."
fi

# Copy: strip runtime metadata, set target namespace
kubectl get secret "${SECRET_NAME}" -n "${SOURCE_NS}" -o json \
  | python3 -c "
import json, sys
s = json.load(sys.stdin)
s['metadata'] = {
    'name':      s['metadata']['name'],
    'namespace': '${NAMESPACE}',
}
print(json.dumps(s))
" \
  | kubectl apply -f -

echo "  ✓ Secret '${SECRET_NAME}' is now present in namespace '${NAMESPACE}'"
