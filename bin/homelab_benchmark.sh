#!/usr/bin/env bash
set -euo pipefail

RESULTS_DIR="/media/luis/sec-hdd/homelab_bench_results"
DRY_RUN=false
while [[ ${1:-} != "" ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) break ;;
  esac
done

echo "[orchestrator] Results dir: $RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# Copy standalone remote helper into results so remote hosts can execute it
if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY-RUN: would copy bin/remote_benchmark.sh to $RESULTS_DIR/remote_benchmark.sh"
else
  cp "$(dirname "${BASH_SOURCE[0]}")/remote_benchmark.sh" "$RESULTS_DIR/remote_benchmark.sh" || true
  chmod +x "$RESULTS_DIR/remote_benchmark.sh" || true
  echo "Copied remote helper to $RESULTS_DIR/remote_benchmark.sh"
fi

echo "Orchestrator minimal run complete"
