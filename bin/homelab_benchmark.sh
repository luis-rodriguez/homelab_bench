#!/usr/bin/env bash
set -euo pipefail

RESULTS_DIR="${RESULTS_BASE_DIR:-${HOME}/homelab_bench_results}"
DRY_RUN=false
HOSTS=()

usage() { echo "Usage: $0 [--dry-run] host1 [host2 ...]"; exit 1; }

while [[ ${1:-} != "" ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage ;;
    *) HOSTS+=("$1"); shift ;;
  esac
done

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  echo "No hosts provided. Example: $0 --dry-run host1.example.com" >&2
  exit 1
fi

echo "[orchestrator] Results dir: $RESULTS_DIR"
mkdir -p "$RESULTS_DIR" || true

HELPER_LOCAL="$(dirname "${BASH_SOURCE[0]}")/remote/remote_benchmark.sh"
if [[ ! -f "$HELPER_LOCAL" ]]; then
  echo "Remote helper $HELPER_LOCAL not found" >&2
  exit 1
fi

# make helper readable/executable for scp
chmod +x "$HELPER_LOCAL" || true

source "$(dirname "${BASH_SOURCE[0]}")/remote/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/remote/setup.sh"
source "$(dirname "${BASH_SOURCE[0]}")/remote/run_remote.sh"
source "$(dirname "${BASH_SOURCE[0]}")/remote/fetch_results.sh"

for host in "${HOSTS[@]}"; do
  echo "\n[orchestrator] Processing host: $host"

  # quick host validation (ssh connectivity)
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN: would validate SSH connectivity to $host"
  else
    if ! ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" 'true' 2>/dev/null; then
      warn "Unable to SSH to $host (BatchMode=yes). Skipping."
      continue
    fi
  fi

  # run remote helper
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY-RUN: would scp and run helper on $host"
    run_remote "$host" "$HELPER_LOCAL" true || true
    continue
  fi

  remote_tmp=$(run_remote "$host" "$HELPER_LOCAL" false) || { warn "run_remote failed for $host"; continue; }

  # fetch results
  fetch_results "$host" "$remote_tmp" "$RESULTS_DIR"

  # cleanup remote tmp
  cleanup_remote_tmp || true

  echo "[orchestrator] Completed host: $host"
done

echo "Orchestrator run complete"
