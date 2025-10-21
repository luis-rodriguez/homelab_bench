#!/usr/bin/env bash

# Minimal orchestrator for local benchmarking. This file sources modular
# components from bin/local/ to keep the logic small and easy to read.

set -euo pipefail

# Configuration (can be overridden by environment or callers)
RESULTS_DIR="${RESULTS_BASE_DIR:-${HOME}/homelab_bench_results}"
LOGS_DIR="$RESULTS_DIR/logs"
RAW_DIR="$RESULTS_DIR/raw"
REPORTS_DIR="$RESULTS_DIR/reports"
LOCAL_HOST="localhost"

# CLI flags
INSTALL_TOOLS=false
AUTO_YES=false
DRY_RUN=false
while [[ ${1:-} != "" ]]; do
    case "$1" in
        --install-tools) INSTALL_TOOLS=true; shift ;;
        --yes|-y) AUTO_YES=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) break ;;
    esac
done

# Ensure modular directory exists
MODULE_DIR="$(dirname "${BASH_SOURCE[0]}")/local"
if [[ ! -d "$MODULE_DIR" ]]; then
    echo "Module directory $MODULE_DIR missing. Please run the migration that creates bin/local/*." >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$MODULE_DIR/utils.sh"
# shellcheck source=/dev/null
source "$MODULE_DIR/setup.sh"
# shellcheck source=/dev/null
source "$MODULE_DIR/install_tools.sh"
# shellcheck source=/dev/null
source "$MODULE_DIR/collect_sysinfo.sh"
# shellcheck source=/dev/null
source "$MODULE_DIR/benchmark_cpu.sh"
# shellcheck source=/dev/null
source "$MODULE_DIR/benchmark_memory.sh"
# shellcheck source=/dev/null
source "$MODULE_DIR/benchmark_disk.sh"
# shellcheck source=/dev/null
source "$MODULE_DIR/benchmark_network.sh"
# shellcheck source=/dev/null
source "$MODULE_DIR/monitor_power.sh"
# shellcheck source=/dev/null
source "$MODULE_DIR/update_reports.sh"

main() {
    log "Starting Local Homelab Benchmark"
    log "Results will be stored in: $RESULTS_DIR"

    preflight_checks
    setup_local_bench "$RAW_DIR" "$LOCAL_HOST"

    if [[ "$INSTALL_TOOLS" == "true" ]]; then
        install_tools "$AUTO_YES"
    fi

    collect_sysinfo "$RAW_DIR" "$LOCAL_HOST"
    benchmark_cpu "$RAW_DIR" "$LOCAL_HOST"
    benchmark_memory "$RAW_DIR" "$LOCAL_HOST"
    benchmark_disk "$RAW_DIR" "$LOCAL_HOST"
    benchmark_network "$RAW_DIR" "$LOCAL_HOST"
    monitor_power "$RAW_DIR" "$LOCAL_HOST"
    update_reports "$RESULTS_DIR"

    log "Local benchmarking complete!"
    echo
    echo "Results available at:"
    echo "  Summary: $REPORTS_DIR/homelab_comparison.md"
    echo "  CSV Data: $REPORTS_DIR/homelab_metrics.csv"
    echo "  Raw Data: $RAW_DIR/localhost/"
    echo "  Logs: $LOGS_DIR/"
    echo
}

main "$@"
