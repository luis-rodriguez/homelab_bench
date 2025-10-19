#!/usr/bin/env bash
# Utilities for remote benchmark modules
set -euo pipefail

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
warn() { echo "[WARN] $*" >&2; }
error() { echo "[ERROR] $*" >&2; }

cleanup_remote_tmp() {
    if [[ -n "${REMOTE_TMP:-}" && -n "${REMOTE_HOST:-}" ]]; then
        ssh "$REMOTE_HOST" "rm -rf '$REMOTE_TMP'" 2>/dev/null || true
    fi
}
