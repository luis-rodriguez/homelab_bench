#!/usr/bin/env bash
# benchmark_disk: non-destructive disk checks (hdparm, fio temporary file)

set -euo pipefail

benchmark_disk() {
    local raw_dir="$1"
    local host="$2"
    log "Running disk benchmark..."

    local device=""
    if [[ -n "${DISK_DEVICE_HINT:-}" ]]; then
        device="$DISK_DEVICE_HINT"
    else
        device=$(lsblk -dno NAME,SIZE,TYPE | grep disk | sort -k2 -hr | head -n1 | awk '{print "/dev/"$1}')
    fi

    log "Testing disk device: $device"

    {
        echo "=== DEVICE: $device ==="

        if command -v hdparm &>/dev/null && [[ -b "$device" ]]; then
            if [[ "${SUDO_NOPASS:-true}" == "true" ]]; then
                sudo hdparm -Tt "$device" 2>/dev/null || hdparm -Tt "$device" 2>/dev/null || echo "hdparm failed"
            else
                hdparm -Tt "$device" 2>/dev/null || echo "hdparm permission denied"
            fi
        else
            echo "hdparm not available or device not found"
        fi

        echo -e "\n=== FIO READ TEST ==="
        if command -v fio &>/dev/null; then
            log "Creating secure temporary file for fio..."
            tmpfile=$(mktemp --tmpdir fio_test.XXXXXX) || tmpfile="/tmp/fio_test.$$"
            TMPFILES+=("$tmpfile")
            if ! dd if=/dev/zero of="$tmpfile" bs=1M count=256 status=none 2>/dev/null; then
                echo "Failed to create test file" >&2
            else
                log "Running fio sequential read test..."
                fio --name=readseq --filename="$tmpfile" --rw=read --bs=1M --iodepth=16 --ioengine=libaio --runtime=30 --time_based --group_reporting > fio_run.log 2>&1 || echo "fio failed (see fio_run.log)" >&2
            fi
            log "FIO test completed; temporary file will be removed"
        else
            echo "fio not available"
        fi

    } > disk_bench.txt

    success "Disk benchmark completed"
}
