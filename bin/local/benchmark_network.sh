#!/usr/bin/env bash
# benchmark_network: run iperf3 loopback test

set -euo pipefail

benchmark_network() {
    local raw_dir="$1"
    local host="$2"
    log "Running network benchmark (loopback test)..."

    if ! command -v iperf3 &>/dev/null; then
        echo "iperf3 not available" > network_bench.txt
        warn "iperf3 not found, skipping network benchmark"
        return
    fi

    {
        echo "=== NETWORK LOOPBACK TEST ==="

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            safe_echo "[DRY-RUN] iperf3 -s -D -1"
            safe_echo "[DRY-RUN] iperf3 -c localhost -P 4 -t 15"
            safe_echo "[DRY-RUN] pkill iperf3"
        else
            iperf3 -s -D -1 2>/dev/null || echo "Failed to start iperf3 server"
            sleep 2
            iperf3 -c localhost -P 4 -t 15 2>/dev/null || echo "iperf3 loopback test failed"
            pkill iperf3 2>/dev/null || true
        fi

    } > network_bench.txt

    success "Network benchmark completed"
}
