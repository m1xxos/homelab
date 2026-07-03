#!/usr/bin/env bash
# Annotate flux-system/sops-gpg so the emberstack reflector mirrors it into every
# `*-cluster` namespace. Run once after each Flux (re-)bootstrap. Idempotent.
# Usage: ./scripts/enable-sops-reflection.sh  |  task enable-sops-reflection

set -euo pipefail

SOURCE_NS="flux-system"
SECRET_NAME="sops-gpg"
NS_REGEX=".*-cluster"

echo "==> Enabling reflector reflection for ${SOURCE_NS}/${SECRET_NAME} → namespaces matching '${NS_REGEX}'"

if ! kubectl get secret "${SECRET_NAME}" -n "${SOURCE_NS}" &>/dev/null; then
  echo "ERROR: Secret '${SECRET_NAME}' not found in namespace '${SOURCE_NS}'."
  echo "       Seed it at Flux bootstrap before enabling reflection."
  exit 1
fi

kubectl annotate secret "${SECRET_NAME}" -n "${SOURCE_NS}" --overwrite \
  "reflector.v1.k8s.emberstack.com/reflection-allowed=true" \
  "reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces=${NS_REGEX}" \
  "reflector.v1.k8s.emberstack.com/reflection-auto-enabled=true" \
  "reflector.v1.k8s.emberstack.com/reflection-auto-namespaces=${NS_REGEX}"

echo "  ✓ Annotations applied. Reflector will mirror '${SECRET_NAME}' into existing and"
echo "    future namespaces matching '${NS_REGEX}'."
