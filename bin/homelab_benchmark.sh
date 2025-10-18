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
