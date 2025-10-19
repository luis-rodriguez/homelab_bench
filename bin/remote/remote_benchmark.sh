#!/usr/bin/env bash
# remote_benchmark.sh - Remote benchmark helper (full)
# This script runs on the remote host and writes results into $RESULTS_DIR

set -euo pipefail

# Defaults: callers can override by exporting RESULTS_DIR or passing --outdir
RESULTS_DIR="/tmp/homelab_remote_results"
SUDO_NOPASS=true
DISK_DEVICE_HINT=""
DRY_RUN=false

while [[ ${1:-} != "" ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --outdir) RESULTS_DIR="$2"; shift 2 ;;
        --host) HOSTNAME_OVERRIDE="$2"; shift 2 ;;
        *) break ;;
    esac
done

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
warn() { echo "[WARN] $*" >&2; }
success() { echo "[SUCCESS] $*"; }

safe_echo() { if [[ "${DRY_RUN:-false}" == "true" ]]; then echo "DRY-RUN: $*"; else echo "$*"; fi }

# Cleanup trap
TMPFILES=()
cleanup() { for f in "${TMPFILES[@]:-}"; do [[ -n "$f" && -e "$f" ]] && rm -f -- "$f" 2>/dev/null || true; done }
trap cleanup EXIT INT TERM

preflight() {
    mkdir -p "$RESULTS_DIR" || true
    if [[ ! -w "$RESULTS_DIR" ]]; then
        warn "Results dir $RESULTS_DIR not writable; attempt to proceed anyway"
    fi
    cd "$RESULTS_DIR" || exit 1
}

collect_sysinfo() {
    log "Collecting system information..."
    {
        echo "=== HOSTNAME ==="
        hostnamectl 2>/dev/null || hostname
        echo -e "\n=== KERNEL ==="
        uname -a
        echo -e "\n=== CPU ==="
        if command -v lscpu &>/dev/null; then lscpu; fi
        echo -e "\n=== MEMORY ==="
        free -h
        echo -e "\n=== STORAGE ==="
        lsblk -O 2>/dev/null || lsblk
        echo -e "\n=== FILESYSTEM ==="
        df -hT
        echo -e "\n=== NETWORK ==="
        ip -br a || true
        echo -e "\n=== HARDWARE INFO ==="
        if command -v inxi &>/dev/null; then inxi -Fxz 2>/dev/null || true; fi
        if command -v lshw &>/dev/null; then
            if [[ "$SUDO_NOPASS" == "true" ]]; then sudo lshw -short 2>/dev/null || lshw -short 2>/dev/null || true; else lshw -short 2>/dev/null || true; fi
        fi
        echo -e "\n=== TEMPERATURES ==="
        if command -v sensors &>/dev/null; then sensors 2>/dev/null || true; fi
    } > sysinfo.txt
    success "System information collected"
}

benchmark_cpu() {
    log "Running CPU benchmark..."
    if ! command -v sysbench &>/dev/null; then
        echo "sysbench not available" > cpu_bench.txt
        warn "sysbench not found, skipping CPU benchmark"
        return
    fi
    sysbench cpu --cpu-max-prime=20000 run > cpu_bench.txt 2>&1 || echo "CPU benchmark failed" > cpu_bench.txt
    success "CPU benchmark completed"
}

benchmark_memory() {
    log "Running memory benchmark..."
    if ! command -v sysbench &>/dev/null; then
        echo "sysbench not available" > memory_bench.txt
        warn "sysbench not found, skipping memory benchmark"
        return
    fi
    sysbench memory --memory-block-size=1M --memory-total-size=2G run > memory_bench.txt 2>&1 || echo "Memory benchmark failed" > memory_bench.txt
    success "Memory benchmark completed"
}

benchmark_disk() {
    log "Running disk benchmark..."
    local device=""
    if [[ -n "$DISK_DEVICE_HINT" ]]; then
        device="$DISK_DEVICE_HINT"
    else
        device=$(lsblk -dno NAME,SIZE,TYPE | grep disk | sort -k2 -hr | head -n1 | awk '{print "/dev/"$1}')
    fi
    log "Testing disk device: $device"
    {
        echo "=== DEVICE: $device ==="
        if command -v hdparm &>/dev/null && [[ -b "$device" ]]; then
            if [[ "$SUDO_NOPASS" == "true" ]]; then
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

benchmark_network() {
    log "Running network benchmark (loopback test)..."
    if ! command -v iperf3 &>/dev/null; then
        echo "iperf3 not available" > network_bench.txt
        warn "iperf3 not found, skipping network benchmark"
        return
    fi
    {
        echo "=== NETWORK LOOPBACK TEST ==="
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            safe_echo "[DRY-RUN] iperf3 -s -D -1"
            safe_echo "[DRY-RUN] iperf3 -c localhost -P 4 -t 15"
            safe_echo "[DRY-RUN] pkill iperf3"
        else
            iperf3 -s -D -1 2>/dev/null || echo "Failed to start iperf3 server"
            sleep 2
            iperf3 -c localhost -P 4 -t 15 2>/dev/null || echo "iperf3 loopback test failed"
            pkill iperf3 2>/dev/null || true
        fi
    } > network_bench.txt
    success "Network benchmark completed"
}

monitor_power() {
    log "Collecting power and temperature information..."
    {
        if command -v powertop &>/dev/null && [[ "$SUDO_NOPASS" == "true" ]]; then
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

update_reports() {
    # For remote runs we simply leave raw files in place; combining and
    # comparing is handled by the controller (local update_reports)
    log "Remote run complete; results are available in $RESULTS_DIR"
}

main() {
    log "Remote benchmark starting (results -> $RESULTS_DIR)"
    preflight

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log "DRY-RUN: creating placeholders"
        hostname > sysinfo.txt || true
        echo "cpu_bench: DRY-RUN" > cpu_bench.txt
        echo "memory_bench: DRY-RUN" > memory_bench.txt
        echo "disk_bench: DRY-RUN" > disk_bench.txt
        echo "network_bench: DRY-RUN" > network_bench.txt
    else
        collect_sysinfo
        benchmark_cpu
        benchmark_memory
        benchmark_disk
        benchmark_network
        monitor_power
    fi

    update_reports
    success "Remote benchmark completed"
}

main "$@"
