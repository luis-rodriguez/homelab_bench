#!/usr/bin/env bash
# run_remote: scp the helper to remote and execute it, leaving results in the remote tmp dir
set -euo pipefail

run_remote() {
    local host="$1"
    local helper_local="$2"  # path to local remote helper
    local dry_run="${3:-false}"

    log "Running remote helper on $host"
    REMOTE_HOST="$host"

    if [[ "$dry_run" == "true" ]]; then
        log "DRY-RUN: would create remote tmp and copy helper to $host"
        echo "DRY-RUN"
        return 0
    fi

    prepare_remote_paths "$host"

    # copy helper
    scp -q "$helper_local" "$REMOTE_HOST":"$REMOTE_TMP/remote_benchmark.sh"
    ssh "$REMOTE_HOST" "chmod +x '$REMOTE_TMP/remote_benchmark.sh'"

    # run helper on remote
    ssh "$REMOTE_HOST" "'$REMOTE_TMP/remote_benchmark.sh' --host '$REMOTE_HOST'" || warn "remote helper returned non-zero"

    echo "$REMOTE_TMP"
}
