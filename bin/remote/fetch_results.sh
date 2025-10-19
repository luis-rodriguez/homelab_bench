#!/usr/bin/env bash
# fetch_results: copy remote results directory back into local results/raw/<host>/
set -euo pipefail

fetch_results() {
    local host="$1"
    local remote_tmp="$2"
    local results_dir="$3"

    local dest_dir="$results_dir/raw/$host"
    mkdir -p "$dest_dir"

    log "Fetching results from $host:$remote_tmp to $dest_dir"
    scp -q -r "$host":"$remote_tmp/"* "$dest_dir/" || warn "scp fetch returned non-zero for $host"
}
