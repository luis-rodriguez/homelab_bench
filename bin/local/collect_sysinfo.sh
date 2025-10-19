#!/usr/bin/env bash
# collect_sysinfo: collect system information into sysinfo.txt

set -euo pipefail

collect_sysinfo() {
    local raw_dir="$1"
    local host="$2"
    log "Collecting system information..."

    {
        echo "=== HOSTNAME ==="
        hostnamectl 2>/dev/null || hostname

        echo -e "\n=== KERNEL ==="
        uname -a

        echo -e "\n=== CPU ==="
        lscpu

        echo -e "\n=== MEMORY ==="
        free -h

        echo -e "\n=== STORAGE ==="
        lsblk -O 2>/dev/null || lsblk

        echo -e "\n=== FILESYSTEM ==="
        df -hT

        echo -e "\n=== NETWORK ==="
        ip -br a

        echo -e "\n=== NETWORK INTERFACE ==="
        local iface
        iface=$(ip -br l | awk '/UP/ && $1!="lo"{print $1; exit}')
        if [[ -n "$iface" ]]; then
            ethtool -i "$iface" 2>/dev/null || echo "ethtool not available"
        fi

        echo -e "\n=== HARDWARE INFO ==="
        if command -v inxi &>/dev/null; then
            inxi -Fxz 2>/dev/null || echo "inxi failed"
        fi

        if command -v lshw &>/dev/null; then
            if [[ "${SUDO_NOPASS:-true}" == "true" ]]; then
                sudo lshw -short 2>/dev/null || lshw -short 2>/dev/null || echo "lshw failed"
            else
                lshw -short 2>/dev/null || echo "lshw permission denied"
            fi
        fi

        echo -e "\n=== TEMPERATURES ==="
        if command -v sensors &>/dev/null; then
            sensors 2>/dev/null || echo "sensors not available"
        fi

    } > sysinfo.txt

    success "System information collected"
}
