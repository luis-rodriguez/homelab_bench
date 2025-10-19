#!/usr/bin/env bash
# Setup helpers for remote orchestrator
set -euo pipefail

prepare_remote_paths() {
    local host="$1"
    REMOTE_HOST="$host"
    # Create a unique tmp dir on the remote side
    REMOTE_TMP=$(ssh "$REMOTE_HOST" "mktemp -d /tmp/homelab_remote.XXXXXX" 2>/dev/null || echo "/tmp/homelab_remote.$$")
    log "Remote tmp dir on $REMOTE_HOST: $REMOTE_TMP"
}
