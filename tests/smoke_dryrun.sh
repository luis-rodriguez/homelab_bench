#!/usr/bin/env bash
set -euo pipefail

mkdir -p results/logs

echo "Smoke dry-run: homelab"
TERM=dumb SUDO_NOPASS=false bin/homelab_benchmark.sh --dry-run </dev/null > results/logs/smoke_homelab.txt 2>&1 || true
echo "Smoke dry-run: local"
TERM=dumb SUDO_NOPASS=false bin/local_benchmark.sh --dry-run </dev/null > results/logs/smoke_local.txt 2>&1 || true

echo "Logs written to results/logs/"
