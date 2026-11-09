#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. Applying machineconfig patches to live nodes on 192.168.1.x ==="

echo "Patching main-cp-0 (192.168.1.70 -> 192.168.20.70)..."
talosctl patch machineconfig -n 192.168.1.70 --patch @"${SCRIPT_DIR}/cp-0.yaml" --mode reboot || true

echo "Patching main-worker-0 (192.168.1.10 -> 192.168.20.10)..."
talosctl patch machineconfig -n 192.168.1.10 --patch @"${SCRIPT_DIR}/worker-0.yaml" --mode reboot || true

echo "Patching main-worker-1 (192.168.1.11 -> 192.168.20.11)..."
talosctl patch machineconfig -n 192.168.1.11 --patch @"${SCRIPT_DIR}/worker-1.yaml" --mode reboot || true

echo "Patching main-worker-2 (192.168.1.12 -> 192.168.20.12)..."
talosctl patch machineconfig -n 192.168.1.12 --patch @"${SCRIPT_DIR}/worker-2.yaml" --mode reboot || true

echo "=== All node patches sent ==="
