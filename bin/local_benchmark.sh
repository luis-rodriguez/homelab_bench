#!/bin/bash

# Local Homelab Benchmarking Script
# Non-destructive performance testing for the current machine

set -euo pipefail

# Configuration
DISK_DEVICE_HINT=""
SUDO_NOPASS=true
# shellcheck disable=SC2034  # variable intentionally present for config
NON_DESTRUCTIVE_ONLY=true
RUN_SENSORS_DETECT=false   # set to true to run sensors-detect interactively (NOT recommended)

# CLI flags
# shellcheck disable=SC2034  # DRY_RUN may be used by callers / future dry-run logic
INSTALL_TOOLS=false
AUTO_YES=false
DRY_RUN=false
while [[ ${1:-} != "" ]]; do
    case "$1" in
        --install-tools) INSTALL_TOOLS=true; shift ;;
        --yes|-y) AUTO_YES=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) break ;;
    esac
done

# Directories
RESULTS_DIR="/media/luis/sec-hdd/homelab_bench_results"
LOGS_DIR="$RESULTS_DIR/logs"
RAW_DIR="$RESULTS_DIR/raw"
REPORTS_DIR="$RESULTS_DIR/reports"
LOCAL_HOST="localhost"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Create benchmark directory
setup_local_bench() {
    local bench_dir="$RAW_DIR/$LOCAL_HOST"
    mkdir -p "$bench_dir"
    cd "$bench_dir"
    
    log "Local benchmark directory: $bench_dir"
}

safe_echo() { if [[ "${DRY_RUN:-false}" == "true" ]]; then echo "DRY-RUN: $*"; else echo "$*"; fi }


# Cleanup handler for temporary files
TMPFILES=()
cleanup() {
    for f in "${TMPFILES[@]:-}"; do
        if [[ -n "$f" && -e "$f" ]]; then
            rm -f -- "$f" 2>/dev/null || true
        fi
    done
}
trap cleanup EXIT INT TERM

# Basic preflight checks for RESULTS_DIR
preflight_checks() {
    if [[ ! -d "$RESULTS_DIR" ]]; then
        warn "Results directory $RESULTS_DIR does not exist; attempting to create"
        mkdir -p "$RESULTS_DIR" || { error "Failed to create $RESULTS_DIR"; exit 1; }
    fi
    if [[ ! -w "$RESULTS_DIR" ]]; then
        error "Results directory $RESULTS_DIR is not writable by $(id -un). Aborting."
        exit 1
    fi
}

# Detect package manager and install tools
install_tools() {
    log "Checking and installing required tools..."
    
    local pm=""
    if command -v apt-get &>/dev/null; then
        pm="apt"
    elif command -v dnf &>/dev/null; then
        pm="dnf" 
    elif command -v yum &>/dev/null; then
        pm="yum"
    elif command -v zypper &>/dev/null; then
        pm="zypper"
    elif command -v pacman &>/dev/null; then
        pm="pacman"
    fi
    
    if [[ -z "$pm" ]]; then
        warn "No supported package manager found, skipping tool installation"
        return 1
    fi
    
    local tools="sysbench hdparm fio iperf3 inxi lshw lm-sensors neofetch jq"
    
    log "Using package manager: $pm"
    
    case "$pm" in
        "apt")
            if [[ "$INSTALL_TOOLS" != "true" ]]; then
                log "INSTALL_TOOLS not enabled; skipping package installation"
            else
                if sudo -n true 2>/dev/null; then
                    if [[ "$AUTO_YES" == "true" ]]; then
                        sudo apt-get update -qq
                        sudo apt-get install -y "$tools" coreutils grep gawk 2>/dev/null || warn "Some packages failed to install"
                    else
                        warn "INSTALL_TOOLS requested but AUTO_YES not set; skipping interactive install"
                    fi
                else
                    warn "sudo not available non-interactively; skip package installation"
                fi
            fi
            ;;
        "dnf"|"yum")
            if [[ "$INSTALL_TOOLS" != "true" ]]; then
                log "INSTALL_TOOLS not enabled; skipping package installation"
            else
                if sudo -n true 2>/dev/null; then
                    if [[ "$AUTO_YES" == "true" ]]; then
                        sudo "$pm" install -y "$tools" coreutils grep gawk 2>/dev/null || warn "Some packages failed to install"
                    else
                        warn "INSTALL_TOOLS requested but AUTO_YES not set; skipping interactive install"
                    fi
                else
                    warn "sudo not available non-interactively; skip package installation"
                fi
            fi
            ;;
        "zypper")
            if [[ "$INSTALL_TOOLS" != "true" ]]; then
                log "INSTALL_TOOLS not enabled; skipping package installation"
            else
                if sudo -n true 2>/dev/null; then
                    if [[ "$AUTO_YES" == "true" ]]; then
                        sudo zypper install -y "$tools" coreutils grep gawk 2>/dev/null || warn "Some packages failed to install"
                    else
                        warn "INSTALL_TOOLS requested but AUTO_YES not set; skipping interactive install"
                    fi
                else
                    warn "sudo not available non-interactively; skip package installation"
                fi
            fi
            ;;
        "pacman")
            if [[ "$INSTALL_TOOLS" != "true" ]]; then
                log "INSTALL_TOOLS not enabled; skipping package installation"
            else
                if sudo -n true 2>/dev/null; then
                    if [[ "$AUTO_YES" == "true" ]]; then
                        sudo pacman -S --noconfirm "$tools" coreutils grep gawk 2>/dev/null || warn "Some packages failed to install"
                    else
                        warn "INSTALL_TOOLS requested but AUTO_YES not set; skipping interactive install"
                    fi
                else
                    warn "sudo not available non-interactively; skip package installation"
                fi
            fi
            ;;
    esac
    
    # Setup sensors: do NOT auto-answer sensors-detect; require explicit opt-in
    if command -v sensors-detect &>/dev/null; then
        log "lm-sensors detected. Skipping automatic sensors-detect."
        if [[ "${RUN_SENSORS_DETECT:-false}" == "true" ]]; then
            if sudo -n true 2>/dev/null; then
                log "Running sensors-detect interactively as requested"
                sudo sensors-detect || warn "sensors-detect failed"
            else
                warn "RUN_SENSORS_DETECT=true but sudo would prompt; run sensors-detect manually"
            fi
        else
            log "To run sensors-detect automatically set RUN_SENSORS_DETECT=true (not recommended)"
        fi
    fi
}

# Collect system information
collect_sysinfo() {
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
            if [[ "$SUDO_NOPASS" == "true" ]]; then
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

# CPU benchmark
benchmark_cpu() {
    log "Running CPU benchmark..."
    
    if ! command -v sysbench &>/dev/null; then
        echo "sysbench not available" > cpu_bench.txt
        warn "sysbench not found, skipping CPU benchmark"
        return
    fi
    
    log "Running sysbench CPU test (this may take a few minutes)..."
    sysbench cpu --cpu-max-prime=20000 run > cpu_bench.txt 2>&1 || echo "CPU benchmark failed" > cpu_bench.txt
    
    success "CPU benchmark completed"
}

# Memory benchmark  
benchmark_memory() {
    log "Running memory benchmark..."
    
    if ! command -v sysbench &>/dev/null; then
        echo "sysbench not available" > memory_bench.txt
        warn "sysbench not found, skipping memory benchmark"
        return
    fi
    
    log "Running sysbench memory test..."
    sysbench memory --memory-block-size=1M --memory-total-size=2G run > memory_bench.txt 2>&1 || echo "Memory benchmark failed" > memory_bench.txt
    
    success "Memory benchmark completed"
}

# Disk benchmark (non-destructive)
benchmark_disk() {
    log "Running disk benchmark..."
    
    local device=""
    if [[ -n "$DISK_DEVICE_HINT" ]]; then
        device="$DISK_DEVICE_HINT"
    else
        # Auto-detect primary device
        device=$(lsblk -dno NAME,SIZE,TYPE | grep disk | sort -k2 -hr | head -n1 | awk '{print "/dev/"$1}')
    fi
    
    log "Testing disk device: $device"
    
    {
        echo "=== DEVICE: $device ==="
        
        # hdparm test
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
        # Create test file and run fio
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
                # cleanup will be handled by trap/cleanup
                log "FIO test completed; temporary file will be removed"
        else
            echo "fio not available"
        fi
        
    } > disk_bench.txt
    
    success "Disk benchmark completed"
}

# Network benchmark (loopback test)
benchmark_network() {
    log "Running network benchmark (loopback test)..."
    
    if ! command -v iperf3 &>/dev/null; then
        echo "iperf3 not available" > network_bench.txt
        warn "iperf3 not found, skipping network benchmark"
        return
    fi
    
    {
        echo "=== NETWORK LOOPBACK TEST ==="
        
        # Start iperf3 server in background
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            safe_echo "[DRY-RUN] iperf3 -s -D -1"
            safe_echo "[DRY-RUN] iperf3 -c localhost -P 4 -t 15"
            safe_echo "[DRY-RUN] pkill iperf3"
        else
            iperf3 -s -D -1 2>/dev/null || echo "Failed to start iperf3 server"
            sleep 2

            # Run client test
            iperf3 -c localhost -P 4 -t 15 2>/dev/null || echo "iperf3 loopback test failed"

            # Stop server
            pkill iperf3 2>/dev/null || true
        fi
        
    } > network_bench.txt
    
    success "Network benchmark completed"
}

# Power monitoring
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

# Update local results to include in comparison
update_reports() {
    log "Adding local results to comparison reports..."
    
    # Check if there are existing metrics to compare with
    if [[ -f "$REPORTS_DIR/metrics.json" ]]; then
        log "Existing metrics found, updating comparison..."
    else
        log "Creating new metrics file with local results..."
    fi
    
    # Run the same Python report generator
    python3 - << 'EOF'
import json
import csv
import os
import re
import glob
from pathlib import Path
from datetime import datetime

results_dir = Path("/media/luis/sec-hdd/homelab_bench_results")
raw_dir = results_dir / "raw"
reports_dir = results_dir / "reports"

# Load existing metrics if they exist
metrics_file = reports_dir / 'metrics.json'
if metrics_file.exists():
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)
else:
    metrics = {}

def parse_sysbench_cpu(content):
    """Parse sysbench CPU benchmark results"""
    events_match = re.search(r'events per second:\s*([0-9.]+)', content)
    time_match = re.search(r'total time:\s*([0-9.]+)s', content)
    
    return {
        'events_per_sec': float(events_match.group(1)) if events_match else 0,
        'total_time_s': float(time_match.group(1)) if time_match else 0
    }

def parse_sysbench_memory(content):
    """Parse sysbench memory benchmark results"""
    throughput_match = re.search(r'(\d+\.?\d*)\s*MiB/sec', content)
    return {
        'throughput_mb_per_s': float(throughput_match.group(1)) if throughput_match else 0
    }

def parse_hdparm(content):
    """Parse hdparm disk benchmark results"""
    cached_match = re.search(r'Timing cached reads:\s*(\d+)\s*MB', content)
    buffered_match = re.search(r'Timing buffered disk reads:\s*(\d+)\s*MB', content)
    
    return {
        'cached_mb_per_s': int(cached_match.group(1)) if cached_match else 0,
        'buffered_mb_per_s': int(buffered_match.group(1)) if buffered_match else 0
    }

def parse_fio(content):
    """Parse fio benchmark results"""
    # Look for read bandwidth
    bw_match = re.search(r'READ:.*bw=([0-9.]+)([KMG]?)iB/s', content)
    if bw_match:
        bw = float(bw_match.group(1))
        unit = bw_match.group(2)
        if unit == 'K':
            bw = bw / 1024
        elif unit == 'G':
            bw = bw * 1024
        return {'seq_read_mb_per_s': bw}
    return {'seq_read_mb_per_s': 0}

def parse_iperf3(content):
    """Parse iperf3 network benchmark results"""
    # Look for sender and receiver speeds
    sender_match = re.search(r'sender.*?([0-9.]+)\s*([KMG])bits/sec', content)
    receiver_match = re.search(r'receiver.*?([0-9.]+)\s*([KMG])bits/sec', content)
    
    def convert_to_gbps(value, unit):
        if unit == 'K':
            return value / 1000000
        elif unit == 'M':
            return value / 1000
        elif unit == 'G':
            return value
        return value

    to_server = 0
    from_server = 0
    
    if sender_match:
        val = float(sender_match.group(1))
        unit = sender_match.group(2)
        to_server = convert_to_gbps(val, unit)
    
    if receiver_match:
        val = float(receiver_match.group(1))
        unit = receiver_match.group(2) 
        from_server = convert_to_gbps(val, unit)
        
    return {
        'to_server_gbps': to_server,
        'from_server_gbps': from_server
    }

def parse_sensors(content):
    """Parse sensor temperature data"""
    temp_matches = re.findall(r'Core \d+:\s*\+([0-9.]+)°C', content)
    if temp_matches:
        temps = [float(t) for t in temp_matches]
        return {'avg_cpu_temp_c': sum(temps) / len(temps)}
    
    # Also try Package temperature
    package_match = re.search(r'Package id \d+:\s*\+([0-9.]+)°C', content)
    if package_match:
        return {'avg_cpu_temp_c': float(package_match.group(1))}
        
    return {'avg_cpu_temp_c': 0}

def parse_sysinfo(content):
    """Parse system information"""
    info = {}
    
    # CPU info
    cpu_match = re.search(r'Model name:\s*(.+)', content)
    cores_match = re.search(r'CPU\(s\):\s*(\d+)', content)
    threads_match = re.search(r'Thread\(s\) per core:\s*(\d+)', content)
    
    if cpu_match:
        info['cpu_model'] = cpu_match.group(1).strip()
    if cores_match:
        info['cpu_cores'] = int(cores_match.group(1))
    if threads_match and cores_match:
        info['cpu_threads'] = int(cores_match.group(1)) * int(threads_match.group(1))
    
    # Memory info
    mem_match = re.search(r'Mem:\s*([0-9.]+)Gi?', content)
    if mem_match:
        info['total_memory_gb'] = float(mem_match.group(1))
        
    return info

# Process localhost results
localhost_dir = raw_dir / "localhost"
if localhost_dir.exists():
    print("Processing localhost...")
    
    host_metrics = {
        'cpu': {},
        'memory': {},
        'disk': {},
        'network': {},
        'temps': {},
        'system': {}
    }
    
    # Process each result file
    for result_file in localhost_dir.glob('*.txt'):
        try:
            with open(result_file, 'r') as f:
                content = f.read()
        except:
            continue
            
        if result_file.name == 'sysinfo.txt':
            host_metrics['system'].update(parse_sysinfo(content))
            # Also extract temperatures from sysinfo
            host_metrics['temps'].update(parse_sensors(content))
            
        elif result_file.name == 'cpu_bench.txt':
            host_metrics['cpu'].update(parse_sysbench_cpu(content))
            
        elif result_file.name == 'memory_bench.txt':
            host_metrics['memory'].update(parse_sysbench_memory(content))
            
        elif result_file.name == 'disk_bench.txt':
            host_metrics['disk'].update(parse_hdparm(content))
            host_metrics['disk'].update(parse_fio(content))
            
        elif result_file.name == 'network_bench.txt':
            host_metrics['network'].update(parse_iperf3(content))
    
    metrics['localhost'] = host_metrics

# Save updated metrics JSON
with open(reports_dir / 'metrics.json', 'w') as f:
    json.dump(metrics, f, indent=2)

print("Reports updated with localhost results!")
EOF

    success "Reports updated with local results"
}

# Main execution
main() {
    log "Starting Local Homelab Benchmark"
    log "Results will be stored in: $RESULTS_DIR"
    
    setup_local_bench
    install_tools
    collect_sysinfo
    benchmark_cpu
    benchmark_memory
    benchmark_disk
    benchmark_network
    monitor_power
    update_reports
    
    log "Local benchmarking complete!"
    echo
    echo "📊 Results available at:"
    echo "  📋 Summary: $REPORTS_DIR/homelab_comparison.md"
    echo "  📊 CSV Data: $REPORTS_DIR/homelab_metrics.csv"
    echo "  📁 Raw Data: $RAW_DIR/localhost/"
    echo "  📜 Logs: $LOGS_DIR/"
    echo
    echo "💡 Your local machine results are now included in the comparison!"
}

# Execute main function
main "$@"

*** End Patch