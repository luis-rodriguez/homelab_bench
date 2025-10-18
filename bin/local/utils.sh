#!/usr/bin/env bash
# Utility helpers for local benchmark modules

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TMPFILES=()

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

safe_echo() { if [[ "${DRY_RUN:-false}" == "true" ]]; then echo "DRY-RUN: $*"; else echo "$*"; fi }

cleanup() {
    for f in "${TMPFILES[@]:-}"; do
        if [[ -n "$f" && -e "$f" ]]; then
            rm -f -- "$f" 2>/dev/null || true
        fi
    done
}
trap cleanup EXIT INT TERM

preflight_checks() {
    : "Ensure RESULTS_DIR, LOGS_DIR, RAW_DIR, and REPORTS_DIR exist and are writable"
    if [[ -z "${RESULTS_DIR:-}" ]]; then
        error "RESULTS_DIR is not set. Aborting."
        exit 1
    fi
    mkdir -p "${RESULTS_DIR}" "${LOGS_DIR:-$RESULTS_DIR/logs}" "${RAW_DIR:-$RESULTS_DIR/raw}" "${REPORTS_DIR:-$RESULTS_DIR/reports}" || {
        error "Failed to create results directories under $RESULTS_DIR"
        exit 1
    }
    if [[ ! -w "$RESULTS_DIR" ]]; then
        error "Results directory $RESULTS_DIR is not writable by $(id -un). Aborting."
        exit 1
    fi
}
