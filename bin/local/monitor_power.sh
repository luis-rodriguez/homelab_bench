#!/usr/bin/env bash
# monitor_power: collect power and temperature information

set -euo pipefail

monitor_power() {
    local raw_dir="$1"
    local host="$2"
    log "Collecting power and temperature information..."

    {
        if command -v powertop &>/dev/null && [[ "${SUDO_NOPASS:-true}" == "true" ]]; then
            log "Running powertop analysis (30 seconds)..."
            timeout 35 sudo powertop --time=30 --html=powertop.html 2>/dev/null || echo "powertop failed or timed out"
        fi

        if command -v sensors &>/dev/null; then
            echo "=== TEMPERATURES UNDER LOAD ==="
            sensors 2>/dev/null || echo "sensors failed"
        fi

    } > power_info.txt

    success "Power monitoring completed"
}
