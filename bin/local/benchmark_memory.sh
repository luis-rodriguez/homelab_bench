#!/usr/bin/env bash
# benchmark_memory: run sysbench memory test and write memory_bench.txt

set -euo pipefail

benchmark_memory() {
    local raw_dir="$1"
    local host="$2"
    log "Running memory benchmark..."

    if ! command -v sysbench &>/dev/null; then
        echo "sysbench not available" > memory_bench.txt
        warn "sysbench not found, skipping memory benchmark"
        return
    fi

    log "Running sysbench memory test..."
    sysbench memory --memory-block-size=1M --memory-total-size=2G run > memory_bench.txt 2>&1 || echo "Memory benchmark failed" > memory_bench.txt

    success "Memory benchmark completed"
}
