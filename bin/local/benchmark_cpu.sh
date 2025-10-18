#!/usr/bin/env bash
# benchmark_cpu: run sysbench CPU test and write cpu_bench.txt

set -euo pipefail

benchmark_cpu() {
    local raw_dir="$1"
    local host="$2"
    log "Running CPU benchmark..."

    if ! command -v sysbench &>/dev/null; then
        echo "sysbench not available" > cpu_bench.txt
        warn "sysbench not found, skipping CPU benchmark"
        return
    fi

    log "Running sysbench CPU test (this may take a few minutes)..."
    sysbench cpu --cpu-max-prime=20000 run > cpu_bench.txt 2>&1 || echo "CPU benchmark failed" > cpu_bench.txt

    success "CPU benchmark completed"
}
