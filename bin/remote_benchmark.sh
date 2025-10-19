#!/bin/bash
# Remote benchmark helper script (meant to be copied to remote host)
set -euo pipefail

BENCH_DIR="$HOME/homelab_bench"
mkdir -p "$BENCH_DIR"
cd "$BENCH_DIR"

# Parse flags passed from orchestrator
INSTALL_TOOLS=false
AUTO_YES=false
while [[ ${1:-} != "" ]]; do
    case "$1" in
        --install-tools) INSTALL_TOOLS=true; shift ;;
        --yes|-y) AUTO_YES=true; shift ;;
        *) break ;;
    esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }

install_tools() {
    log "(remote) check/install tools (skipped unless orchestrator requested)"
    if [[ "$INSTALL_TOOLS" != "true" ]]; then
        log "INSTALL_TOOLS not enabled; skipping"
        return 0
    fi
    # Remote package logic intentionally minimal in helper
}

collect_sysinfo() {
    log "(remote) collect sysinfo"
    {
        hostname || true
        uname -a || true
        lscpu || true
    } > sysinfo.txt 2>/dev/null || true
}

main() {
    install_tools
    collect_sysinfo
    echo "Remote benchmark helper completed" > remote_helper.done
}

main "$@"
#!/bin/bash
set -euo pipefail
# Minimal remote benchmark script - real content preserved in history; this is a safe stub
BENCH_DIR="$HOME/homelab_bench"
mkdir -p "$BENCH_DIR"
cd "$BENCH_DIR"
echo "Remote benchmark stub - actual benchmark code managed from orchestrator"
