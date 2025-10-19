#!/usr/bin/env bash
# setup_local_bench: create host-specific raw directory and cd into it

set -euo pipefail

setup_local_bench() {
    local raw_dir="$1"
    local host="$2"

    local bench_dir="$raw_dir/$host"
    mkdir -p "$bench_dir"
    cd "$bench_dir" || exit 1

    log "Local benchmark directory: $bench_dir"
}
