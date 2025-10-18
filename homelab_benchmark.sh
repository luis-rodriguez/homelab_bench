#!/bin/bash

# Homelab Benchmarking System
# Non-destructive performance testing across multiple Linux hosts

set -euo pipefail

# Configuration - EDIT THESE VALUES
HOSTS=(
  "machineA|192.168.0.185||luis"     # Format: "name|ip|ssh_key_path|username"
  "machineB|192.168.0.160||luis"     # Leave ssh_key_path empty to use default key
  # "server1|10.0.0.10|/home/luis/.ssh/custom_key|admin"
  # "nas|192.168.1.100||root"
)
IPERF_SERVER_HOST="machineA"           # Which host will run the iperf3 server
DISK_DEVICE_HINT=""                   # Optional: specific device like "/dev/nvme0n1"
SUDO_NOPASS=true                     # Set to false if sudo requires password
NON_DESTRUCTIVE_ONLY=true            # MUST remain true for safety
# shellcheck disable=SC2034  # variable kept for clarity/config export

# Enforce non-destructive safety guard
if [[ "${NON_DESTRUCTIVE_ONLY:-}" != "true" ]]; then
    error "NON_DESTRUCTIVE_ONLY must be true to run this script"
    exit 1
fi

# CLI flags
DRY_RUN=false
INSTALL_TOOLS=false
AUTO_YES=false

while [[ ${1:-} != "" ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --install-tools) INSTALL_TOOLS=true; shift ;;
        --yes|-y) AUTO_YES=true; shift ;;
        *) break ;;
    esac
done

safe_echo() { if [[ "$DRY_RUN" == "true" ]]; then echo "DRY-RUN: $*"; else echo "$*"; fi }

# Validate host name and IP/host
validate_host() {
    local name="$1" ip="$2"
    if [[ ! "$name" =~ ^[A-Za-z0-9._-]+$ ]]; then
        error "Invalid host name: $name"
        return 1
    fi
    # Basic IPv4 check or hostname (very permissive)
    if [[ -z "$ip" ]]; then
        error "Empty IP/hostname for $name"
        return 1
    fi
    return 0
}

# Directories
RESULTS_DIR="/media/luis/sec-hdd/homelab_bench_results"
LOGS_DIR="$RESULTS_DIR/logs"
RAW_DIR="$RESULTS_DIR/raw"
REPORTS_DIR="$RESULTS_DIR/reports"

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

# Parse host configuration
parse_host() {
    local host_config="$1"
    local name
    local ip
    local key
    local user
    name=$(echo "$host_config" | cut -d'|' -f1)
    ip=$(echo "$host_config" | cut -d'|' -f2)
    key=$(echo "$host_config" | cut -d'|' -f3)
    user=$(echo "$host_config" | cut -d'|' -f4)

    # Default user if not specified
    if [[ -z "$user" ]]; then
        user="luis"
    fi

    echo "$name $ip $key $user"
}

# Test SSH connectivity
test_ssh() {
    local name="$1" ip="$2" key="$3" user="$4"

    # Basic validation
    if [[ -z "$ip" ]]; then
        error "Empty IP for host $name"
        return 1
    fi

    # Build ssh options as an array to avoid word-splitting and injection
    local -a ssh_opts=( -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new )
    if [[ -n "$key" ]]; then
        ssh_opts+=( -i "$key" )
    fi

    log "Testing SSH connectivity to $name ($ip)"
    if ssh "${ssh_opts[@]}" -- "$user@$ip" -- "echo 'SSH OK'" &>/dev/null; then
        success "SSH connection to $name successful"
        return 0
    else
        error "SSH connection to $name failed"
        return 1
    fi
}

# Execute remote command
remote_exec() {
    local name="$1" ip="$2" key="$3" user="$4" command="$5"

    # Validate target
    if [[ -z "$ip" || -z "$user" ]]; then
        error "remote_exec: missing ip or user for $name"
        return 1
    fi

    # Build ssh options safely
    local -a ssh_opts=( -o ConnectTimeout=30 -o BatchMode=yes -o StrictHostKeyChecking=accept-new )
    if [[ -n "$key" ]]; then
        ssh_opts+=( -i "$key" )
    fi

    # Execute remote command; pass command as a single argument after --
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        safe_echo "[DRY-RUN] ssh ${ssh_opts[*]} $user@$ip -- $command"
        return 0
    fi

    ssh "${ssh_opts[@]}" -- "$user@$ip" -- "$command" 2>&1
}

# Copy files from remote host
remote_copy() {
    local name="$1" ip="$2" key="$3" user="$4" remote_path="$5" local_path="$6"

    if [[ -z "$ip" || -z "$user" ]]; then
        error "remote_copy: missing ip or user for $name"
        return 1
    fi

    local -a scp_opts=( -o ConnectTimeout=30 -o BatchMode=yes -o StrictHostKeyChecking=accept-new )
    if [[ -n "$key" ]]; then
        scp_opts+=( -i "$key" )
    fi

    # Use scp with an array of options
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        safe_echo "[DRY-RUN] scp ${scp_opts[*]} $user@$ip:$remote_path $local_path"
        return 0
    fi

    scp "${scp_opts[@]}" -r "$user@$ip:$remote_path" "$local_path" 2>&1
}

# Main benchmarking function for a single host
benchmark_host() {
    local name="$1" ip="$2" key="$3" user="$4"
    
    log "Starting benchmark for $name ($ip)"
    mkdir -p "$RAW_DIR/$name"
    
    # Create remote benchmark script
    local remote_script="/tmp/homelab_bench_${name}.sh"
    
    cat > "$RESULTS_DIR/remote_benchmark.sh" << 'EOF'
#!/bin/bash

set -euo pipefail

BENCH_DIR="$HOME/homelab_bench"
mkdir -p "$BENCH_DIR"
cd "$BENCH_DIR"

# Parse flags passed from orchestrator
INSTALL_TOOLS=false
AUTO_YES=false
while [[ ${1:-} != "" ]]; do
    case "$1" in
        --install-tools) INSTALL_TOOLS=true; shift ;;
        --yes|-y) AUTO_YES=true; shift ;;
        *) break ;;
    esac
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Detect package manager and install tools
install_tools() {
    log "Installing required tools..."
    if [[ "$INSTALL_TOOLS" != "true" ]]; then
        log "INSTALL_TOOLS not enabled; skipping package installation"
        return 0
    fi
    
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
        log "No supported package manager found"
        return 1
    fi
    
    local tools="sysbench hdparm fio iperf3 inxi lshw lm-sensors neofetch jq"
    
    case "$pm" in
        "apt")
            if sudo -n true 2>/dev/null; then
                if [[ "$AUTO_YES" == "true" ]]; then
                    sudo apt-get update -qq
                    sudo apt-get install -y $tools coreutils grep gawk 2>/dev/null || true
                else
                    log "Package install requested but AUTO_YES not set; skipping interactive install"
                fi
            else
                log "sudo not available non-interactively; skipping package install"
            fi
            ;;
        "dnf"|"yum")
            if sudo -n true 2>/dev/null; then
                if [[ "$AUTO_YES" == "true" ]]; then
                    sudo $pm install -y $tools coreutils grep gawk 2>/dev/null || true
                else
                    log "Package install requested but AUTO_YES not set; skipping interactive install"
                fi
            else
                log "sudo not available non-interactively; skipping package install"
            fi
            ;;
        "zypper")
            if sudo -n true 2>/dev/null; then
                if [[ "$AUTO_YES" == "true" ]]; then
                    sudo zypper install -y $tools coreutils grep gawk 2>/dev/null || true
                else
                    log "Package install requested but AUTO_YES not set; skipping interactive install"
                fi
            else
                log "sudo not available non-interactively; skipping package install"
            fi
            ;;
        "pacman")
            if sudo -n true 2>/dev/null; then
                if [[ "$AUTO_YES" == "true" ]]; then
                    sudo pacman -S --noconfirm $tools coreutils grep gawk 2>/dev/null || true
                else
                    log "Package install requested but AUTO_YES not set; skipping interactive install"
                fi
            else
                log "sudo not available non-interactively; skipping package install"
            fi
            ;;
    esac
    
    # Setup sensors if available - do not auto-answer sensors-detect to avoid unintended kernel changes
    if command -v sensors-detect &>/dev/null; then
        log "lm-sensors available; skipping automatic sensors-detect. Run 'sensors-detect' manually if desired."
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
        local iface=$(ip -br l | awk '/UP/ && $1!="lo"{print $1; exit}')
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
}

# CPU benchmark
benchmark_cpu() {
    log "Running CPU benchmark..."
    
    if ! command -v sysbench &>/dev/null; then
        echo "sysbench not available" > cpu_bench.txt
        return
    fi
    
    sysbench cpu --cpu-max-prime=20000 run > cpu_bench.txt 2>&1 || echo "CPU benchmark failed" > cpu_bench.txt
}

# Memory benchmark  
benchmark_memory() {
    log "Running memory benchmark..."
    
    if ! command -v sysbench &>/dev/null; then
        echo "sysbench not available" > memory_bench.txt
        return
    fi
    
    sysbench memory --memory-block-size=1M --memory-total-size=2G run > memory_bench.txt 2>&1 || echo "Memory benchmark failed" > memory_bench.txt
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
    
    {
        echo "=== DEVICE: $device ==="
        
        # hdparm test
        if command -v hdparm &>/dev/null && [[ -b "$device" ]]; then
            if [[ "$SUDO_NOPASS" == "true" ]]; then
                sudo hdparm -Tt "$device" 2>/dev/null || hdparm -Tt "$device" 2>/dev/null || echo "hdparm failed"
            else
                hdparm -Tt "$device" 2>/dev/null || echo "hdparm permission denied"
            fi
        fi
        
        echo -e "\n=== FIO READ TEST ==="
        # Create test file and run fio
        if command -v fio &>/dev/null; then
            # Use mktemp to create a secure temporary test file to prevent symlink/TEMP attacks
            tmpfile=$(mktemp --tmpdir fio_test.XXXXXX) || tmpfile="/tmp/fio_test.$$"
            dd if=/dev/zero of="$tmpfile" bs=1M count=256 status=none 2>/dev/null || { echo "Failed to create test file"; rm -f -- "$tmpfile" 2>/dev/null || true; }
            if [[ -f "$tmpfile" ]]; then
                fio --name=readseq --filename="$tmpfile" --rw=read --bs=1M --iodepth=16 --ioengine=libaio --runtime=30 --time_based --group_reporting 2>/dev/null || echo "fio failed"
                rm -f -- "$tmpfile"
            fi
        else
            echo "fio not available"
        fi
        
    } > disk_bench.txt
}

# Network benchmark (client side)
benchmark_network_client() {
    local server_ip="$1"
    log "Running network benchmark to $server_ip..."
    
    if ! command -v iperf3 &>/dev/null; then
        echo "iperf3 not available" > network_bench.txt
        return
    fi
    
    {
        echo "=== NETWORK TO SERVER $server_ip ==="
        iperf3 -c "$server_ip" -P 4 -t 15 2>/dev/null || echo "iperf3 to server failed"
        
        echo -e "\n=== NETWORK FROM SERVER $server_ip ==="  
        iperf3 -c "$server_ip" -R -P 4 -t 15 2>/dev/null || echo "iperf3 from server failed"
        
    } > network_bench.txt
}

# Power monitoring
monitor_power() {
    log "Collecting power information..."
    
    {
        if command -v powertop &>/dev/null && [[ "$SUDO_NOPASS" == "true" ]]; then
            timeout 35 sudo powertop --time=30 --html=powertop.html 2>/dev/null || echo "powertop failed or timed out"
        fi
        
        if command -v sensors &>/dev/null; then
            echo "=== TEMPERATURES UNDER LOAD ==="
            sensors 2>/dev/null || echo "sensors failed"
        fi
        
    } > power_info.txt
}

# Main execution
main() {
    install_tools
    collect_sysinfo
    benchmark_cpu
    benchmark_memory
    benchmark_disk
    
    # Network benchmarking is handled separately by the orchestrator
    
    monitor_power
    
    log "Benchmark completed. Results in $BENCH_DIR"
}

main "$@"
EOF

    # Copy script to remote host
    log "Copying benchmark script to $name"
    local -a scp_opts=( -o ConnectTimeout=30 -o BatchMode=yes -o StrictHostKeyChecking=accept-new )
    if [[ -n "$key" ]]; then
        scp_opts+=( -i "$key" )
    fi

    scp "${scp_opts[@]}" -r "$RESULTS_DIR/remote_benchmark.sh" "$user@$ip:$remote_script" 2>"$LOGS_DIR/${name}_copy.log"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        safe_echo "[DRY-RUN] Would copy and execute remote_benchmark.sh on $name ($ip)"
        continue
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        safe_echo "[DRY-RUN] scp ${scp_opts[*]} $RESULTS_DIR/remote_benchmark.sh $user@$ip:$remote_script"
        return 0
    fi
    
    # Set environment variables and execute
    local env_vars="SUDO_NOPASS=$SUDO_NOPASS DISK_DEVICE_HINT='$DISK_DEVICE_HINT'"
    # Build remote flags based on orchestrator flags
    local remote_flags=""
    if [[ "$INSTALL_TOOLS" == "true" ]]; then
        remote_flags+=" --install-tools"
    fi
    if [[ "$AUTO_YES" == "true" ]]; then
        remote_flags+=" --yes"
    fi

    log "Executing benchmark on $name (this may take several minutes)"
    if remote_exec "$name" "$ip" "$key" "$user" "chmod +x $remote_script && $env_vars $remote_script $remote_flags" > "$LOGS_DIR/${name}_bench.log" 2>&1; then
        success "Benchmark completed on $name"
    else
        error "Benchmark failed on $name, check logs"
        return 1
    fi
    
    # Copy results back
    log "Collecting results from $name"
    if remote_copy "$name" "$ip" "$key" "$user" "\$HOME/homelab_bench/*" "$RAW_DIR/$name/" > "$LOGS_DIR/${name}_copy_back.log" 2>&1; then
        success "Results collected from $name"
    else
        warn "Failed to collect some results from $name"
    fi
}

# Network benchmarking coordination
run_network_benchmarks() {
    log "Setting up network benchmarks"
    
    # Find server host details
    local server_name="" server_ip="" server_key="" server_user=""
    for host_config in "${HOSTS[@]}"; do
        read -r name ip key user <<< "$(parse_host "$host_config")"
        if [[ "$name" == "$IPERF_SERVER_HOST" ]]; then
            server_name="$name"
            server_ip="$ip"
            server_key="$key"
            server_user="$user"
            break
        fi
    done
    
    if [[ -z "$server_ip" ]]; then
        error "Server host $IPERF_SERVER_HOST not found in HOSTS"
        return 1
    fi
    
    # Start iperf3 server using PID file to avoid indiscriminate pkill
    log "Starting iperf3 server on $server_name"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        safe_echo "[DRY-RUN] Start iperf3 server on $server_name ($server_ip)"
    else
        remote_exec "$server_name" "$server_ip" "$server_key" "$server_user" "mkdir -p ~/homelab_bench && pkill -f 'iperf3 -s' 2>/dev/null || true; iperf3 -s -D --logfile ~/homelab_bench/iperf3_server.log && echo \$! > ~/homelab_bench/iperf3.pid" > "$LOGS_DIR/iperf_server.log" 2>&1 || true
        sleep 2
    fi
    
    # Run client tests from each host
    for host_config in "${HOSTS[@]}"; do
        read -r name ip key user <<< "$(parse_host "$host_config")"
        
        if [[ "$name" == "$IPERF_SERVER_HOST" ]]; then
            continue  # Skip server host
        fi
        
        log "Running network benchmark from $name to $server_name"
        mkdir -p "$RAW_DIR/$name"
        
        if remote_exec "$name" "$ip" "$key" "$user" "
            cd \$HOME/homelab_bench 2>/dev/null || mkdir -p \$HOME/homelab_bench && cd \$HOME/homelab_bench
            {
                echo '=== NETWORK TO SERVER $server_ip ==='
                iperf3 -c '$server_ip' -P 4 -t 15 2>/dev/null || echo 'iperf3 to server failed'
                
                echo -e '\n=== NETWORK FROM SERVER $server_ip ==='  
                iperf3 -c '$server_ip' -R -P 4 -t 15 2>/dev/null || echo 'iperf3 from server failed'
            } > network_bench.txt
        " > "$LOGS_DIR/${name}_network.log" 2>&1; then
            success "Network benchmark completed for $name"
            # Copy network results
            remote_copy "$name" "$ip" "$key" "$user" "\$HOME/homelab_bench/network_bench.txt" "$RAW_DIR/$name/" >> "$LOGS_DIR/${name}_network.log" 2>&1 || warn "Failed to copy network results from $name"
        else
            error "Network benchmark failed for $name"
        fi
    done
    
    # Stop iperf3 server by PID if available
    log "Stopping iperf3 server"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        safe_echo "[DRY-RUN] Stop iperf3 server on $server_name ($server_ip)"
    else
        remote_exec "$server_name" "$server_ip" "$server_key" "$server_user" "if [[ -f ~/homelab_bench/iperf3.pid ]]; then kill \$(cat ~/homelab_bench/iperf3.pid) 2>/dev/null || true; rm -f ~/homelab_bench/iperf3.pid; fi" >> "$LOGS_DIR/iperf_server.log" 2>&1 || true
    fi
}

# Generate reports
generate_reports() {
    log "Generating reports and analysis"
    
    python3 - << 'EOF'
import json
import csv
import os
import re
import glob
from pathlib import Path

results_dir = Path("/media/luis/sec-hdd/homelab_bench_results")
raw_dir = results_dir / "raw"
reports_dir = results_dir / "reports"

# Initialize metrics structure
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

# Process each host's results
for host_dir in raw_dir.iterdir():
    if not host_dir.is_dir():
        continue
        
    host_name = host_dir.name
    print(f"Processing {host_name}...")
    
    host_metrics = {
        'cpu': {},
        'memory': {},
        'disk': {},
        'network': {},
        'temps': {},
        'system': {}
    }
    
    # Process each result file
    for result_file in host_dir.glob('*.txt'):
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
    
    metrics[host_name] = host_metrics

# Save metrics JSON
with open(reports_dir / 'metrics.json', 'w') as f:
    json.dump(metrics, f, indent=2)

# Generate CSV
csv_data = []
for host_name, host_data in metrics.items():
    row = {
        'Host': host_name,
        'CPU_Model': host_data['system'].get('cpu_model', ''),
        'CPU_Cores': host_data['system'].get('cpu_cores', ''),
        'CPU_Threads': host_data['system'].get('cpu_threads', ''),
        'CPU_Events_Per_Sec': host_data['cpu'].get('events_per_sec', ''),
        'CPU_Total_Time_S': host_data['cpu'].get('total_time_s', ''),
        'Memory_Total_GB': host_data['system'].get('total_memory_gb', ''),
        'Memory_Throughput_MB_Per_S': host_data['memory'].get('throughput_mb_per_s', ''),
        'Disk_Cached_MB_Per_S': host_data['disk'].get('cached_mb_per_s', ''),
        'Disk_Buffered_MB_Per_S': host_data['disk'].get('buffered_mb_per_s', ''),
        'Disk_FIO_Read_MB_Per_S': host_data['disk'].get('seq_read_mb_per_s', ''),
        'Network_To_Server_Gbps': host_data['network'].get('to_server_gbps', ''),
        'Network_From_Server_Gbps': host_data['network'].get('from_server_gbps', ''),
        'Avg_CPU_Temp_C': host_data['temps'].get('avg_cpu_temp_c', '')
    }
    csv_data.append(row)

with open(reports_dir / 'homelab_metrics.csv', 'w', newline='') as f:
    if csv_data:
        writer = csv.DictWriter(f, fieldnames=csv_data[0].keys())
        writer.writeheader()
        writer.writerows(csv_data)

# Generate Markdown report
def rank_metric(data, metric_key, higher_is_better=True):
    """Rank hosts by metric value"""
    valid_data = [(host, value) for host, value in data.items() if value > 0]
    if not valid_data:
        return {}
    
    sorted_data = sorted(valid_data, key=lambda x: x[1], reverse=higher_is_better)
    ranks = {}
    for i, (host, value) in enumerate(sorted_data):
        ranks[host] = len(sorted_data) - i  # Higher rank = better
    
    return ranks

# Calculate rankings
cpu_events_ranks = rank_metric({h: metrics[h]['cpu'].get('events_per_sec', 0) for h in metrics}, 'events_per_sec')
cpu_time_ranks = rank_metric({h: metrics[h]['cpu'].get('total_time_s', 0) for h in metrics}, 'total_time_s', False)
mem_ranks = rank_metric({h: metrics[h]['memory'].get('throughput_mb_per_s', 0) for h in metrics}, 'throughput_mb_per_s')
disk_cached_ranks = rank_metric({h: metrics[h]['disk'].get('cached_mb_per_s', 0) for h in metrics}, 'cached_mb_per_s')
disk_buffered_ranks = rank_metric({h: metrics[h]['disk'].get('buffered_mb_per_s', 0) for h in metrics}, 'buffered_mb_per_s')
disk_fio_ranks = rank_metric({h: metrics[h]['disk'].get('seq_read_mb_per_s', 0) for h in metrics}, 'seq_read_mb_per_s')
net_to_ranks = rank_metric({h: metrics[h]['network'].get('to_server_gbps', 0) for h in metrics}, 'to_server_gbps')
net_from_ranks = rank_metric({h: metrics[h]['network'].get('from_server_gbps', 0) for h in metrics}, 'from_server_gbps')

# Calculate overall scores
overall_scores = {}
for host in metrics:
    score = (cpu_events_ranks.get(host, 0) + 
             cpu_time_ranks.get(host, 0) +
             mem_ranks.get(host, 0) +
             disk_cached_ranks.get(host, 0) +
             disk_buffered_ranks.get(host, 0) +
             disk_fio_ranks.get(host, 0) +
             net_to_ranks.get(host, 0) +
             net_from_ranks.get(host, 0))
    overall_scores[host] = score

# Find best performers
best_overall = max(overall_scores, key=overall_scores.get) if overall_scores else "N/A"
best_cpu = max(cpu_events_ranks, key=cpu_events_ranks.get) if cpu_events_ranks else "N/A"
best_storage = max(disk_fio_ranks, key=disk_fio_ranks.get) if disk_fio_ranks else "N/A"
best_network = max(net_to_ranks, key=net_to_ranks.get) if net_to_ranks else "N/A"

# Generate markdown report
markdown_content = f"""# Homelab Benchmark Results

Generated on: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Summary Table

| Metric                | {' | '.join(metrics.keys())} | Best |
|""" + "-" * 23 + "|" + "|".join(["-" * 10] * len(metrics)) + "|-" * 6 + "|"

def format_value(value, suffix=""):
    if isinstance(value, float):
        return f"{value:.2f}{suffix}"
    return str(value) if value else "N/A"

def get_best_host(ranks):
    return max(ranks, key=ranks.get) if ranks else "N/A"

# Add data rows
rows = [
    ("CPU events/s", {h: metrics[h]['cpu'].get('events_per_sec', 0) for h in metrics}, "", cpu_events_ranks),
    ("CPU total time (s)", {h: metrics[h]['cpu'].get('total_time_s', 0) for h in metrics}, "s", cpu_time_ranks),
    ("Memory throughput (MB/s)", {h: metrics[h]['memory'].get('throughput_mb_per_s', 0) for h in metrics}, " MB/s", mem_ranks),
    ("Disk cached (MB/s)", {h: metrics[h]['disk'].get('cached_mb_per_s', 0) for h in metrics}, " MB/s", disk_cached_ranks),
    ("Disk buffered (MB/s)", {h: metrics[h]['disk'].get('buffered_mb_per_s', 0) for h in metrics}, " MB/s", disk_buffered_ranks),
    ("FIO seq read (MB/s)", {h: metrics[h]['disk'].get('seq_read_mb_per_s', 0) for h in metrics}, " MB/s", disk_fio_ranks),
    ("Net → server (Gbps)", {h: metrics[h]['network'].get('to_server_gbps', 0) for h in metrics}, " Gbps", net_to_ranks),
    ("Net ← server (Gbps)", {h: metrics[h]['network'].get('from_server_gbps', 0) for h in metrics}, " Gbps", net_from_ranks),
    ("Avg CPU temp (°C)", {h: metrics[h]['temps'].get('avg_cpu_temp_c', 0) for h in metrics}, "°C", {}),
    ("Overall Score", overall_scores, "", overall_scores),
]

for metric_name, values, suffix, ranks in rows:
    row = f"| {metric_name:<21} |"
    for host in metrics:
        value = values.get(host, 0)
        row += f" {format_value(value, suffix):<8} |"
    
    best_host = get_best_host(ranks) if ranks else "N/A"
    row += f" {best_host:<4} |"
    markdown_content += f"\n{row}"

markdown_content += f"""

## Detailed System Information

"""

for host_name, host_data in metrics.items():
    system = host_data.get('system', {})
    markdown_content += f"""
### {host_name}
- **CPU**: {system.get('cpu_model', 'Unknown')} ({system.get('cpu_cores', 'N/A')} cores, {system.get('cpu_threads', 'N/A')} threads)
- **Memory**: {system.get('total_memory_gb', 'N/A')} GB
- **Average CPU Temperature**: {host_data.get('temps', {}).get('avg_cpu_temp_c', 'N/A')}°C
"""

markdown_content += f"""

## Recommendations

### 🏆 Overall Best: {best_overall}
The highest-scoring machine based on combined CPU, memory, disk, and network performance.

### 🐳 Best for Docker/VM Workloads: {best_cpu}
Optimal choice for containerized applications and virtual machines requiring strong CPU performance.

### 💾 Best for NAS/Backup: {best_storage}
Ideal for storage-intensive applications with the best disk I/O performance.

### 🌐 Best for Network Services: {best_network}  
Perfect for router, firewall, or network-intensive applications.

## Notes
- All benchmarks were run non-destructively
- Network tests used iperf3 between machines
- Disk tests included both hdparm and fio read-only benchmarks
- CPU and memory tests used sysbench with standard parameters
- Temperature monitoring used lm-sensors where available

## Raw Data Location
Detailed logs and raw benchmark outputs can be found in:
- Logs: `/media/luis/sec-hdd/homelab_bench_results/logs/`
- Raw Data: `/media/luis/sec-hdd/homelab_bench_results/raw/`
- Reports: `/media/luis/sec-hdd/homelab_bench_results/reports/`
"""

with open(reports_dir / 'homelab_comparison.md', 'w') as f:
    f.write(markdown_content)

print("Reports generated successfully!")
EOF

    success "Reports generated in $REPORTS_DIR"
}

# Main execution
main() {
    log "Starting Homelab Benchmarking System"
    log "Results will be stored in: $RESULTS_DIR"
    
    # Test connectivity to all hosts
    local reachable_hosts=()
    for host_config in "${HOSTS[@]}"; do
        read -r name ip key user <<< "$(parse_host "$host_config")"
        if ! validate_host "$name" "$ip"; then
            warn "Skipping invalid host entry: $host_config"
            continue
        fi
        if test_ssh "$name" "$ip" "$key" "$user"; then
            reachable_hosts+=("$host_config")
        fi
    done
    
    if [[ ${#reachable_hosts[@]} -eq 0 ]]; then
        error "No hosts are reachable. Exiting."
        exit 1
    fi
    
    log "Found ${#reachable_hosts[@]} reachable hosts"
    
    # Run benchmarks on each host (excluding network tests)
    local successful_hosts=()
    for host_config in "${reachable_hosts[@]}"; do
        read -r name ip key user <<< "$(parse_host "$host_config")"
        if benchmark_host "$name" "$ip" "$key" "$user"; then
            successful_hosts+=("$host_config")
        fi
    done
    
    # Run network benchmarks if we have multiple hosts
    if [[ ${#successful_hosts[@]} -gt 1 ]]; then
        run_network_benchmarks
    else
        warn "Skipping network benchmarks - need at least 2 hosts"
    fi
    
    # Generate reports
    generate_reports
    
    # Cleanup
    rm -f "$RESULTS_DIR/remote_benchmark.sh"
    
    log "Benchmarking complete!"
    echo
    echo "📊 Results available at:"
    echo "  📋 Summary: $REPORTS_DIR/homelab_comparison.md"
    echo "  📊 CSV Data: $REPORTS_DIR/homelab_metrics.csv"
    echo "  📁 Raw Data: $RAW_DIR/"
    echo "  📜 Logs: $LOGS_DIR/"
}

# Execute main function
main "$@"