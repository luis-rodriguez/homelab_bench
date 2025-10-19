# Multi-Host Benchmarking Setup Guide

This guide walks you through setting up and running benchmarks across multiple homelab machines.

## Prerequisites

### Control Machine (this computer)
- ✅ Linux with bash/zsh shell
- ✅ Python 3 with standard libraries
- ✅ SSH client installed
- ✅ Network access to target machines

### Target Machines
- ✅ Linux-based systems (any distribution)
- ✅ SSH server running
- ✅ Network connectivity from control machine
- ✅ User account with sudo privileges (recommended)

## Step-by-Step Setup

### 1. Configure SSH Access

**Test existing connectivity:**
```bash
# Replace with your actual IPs and usernames
ssh user@192.168.1.100 "echo 'Test successful'"
ssh admin@10.0.0.5 "echo 'Test successful'"
```

**Set up SSH keys (if needed):**
```bash
# Generate SSH key pair (if you don't have one)
ssh-keygen -t rsa -b 4096 -C "homelab-benchmark"

# Copy public key to each target machine
ssh-copy-id user@192.168.1.100
ssh-copy-id admin@10.0.0.5
ssh-copy-id root@192.168.1.200

# Test passwordless login
ssh user@192.168.1.100 "whoami"
```

**For custom SSH keys:**
```bash
# Generate specific key for homelab
ssh-keygen -t rsa -b 4096 -f ~/.ssh/homelab_key

# Copy to machines
ssh-copy-id -i ~/.ssh/homelab_key.pub user@machine
```

### 2. Edit Configuration

Open the benchmark script:
```bash
nano homelab_benchmark.sh
```

**Update the HOSTS array** with your machine details:
```bash
HOSTS=(
  "pi4|192.168.1.100||pi"                    # Raspberry Pi 4
  "server|192.168.1.10||admin"               # Main server  
  "nas|192.168.1.20|~/.ssh/homelab_key|root" # NAS with custom key
  "mini|10.0.0.5||user"                      # Mini PC
  "vm1|192.168.1.50||ubuntu"                 # Virtual machine
)
```

**Configuration Format**: `"name|ip_address|ssh_key_path|username"`

| Field | Description | Example |
|-------|-------------|---------|
| `name` | Friendly identifier | `pi4`, `server`, `nas` |
| `ip_address` | IP or hostname | `192.168.1.100`, `server.local` |
| `ssh_key_path` | SSH private key path (empty = default) | `~/.ssh/homelab_key` or leave empty |
| `username` | SSH username | `pi`, `admin`, `root` |

**Set the iperf3 server host:**
```bash
IPERF_SERVER_HOST="server"  # Must match a name from HOSTS array
```

**Configure other settings:**
```bash
DISK_DEVICE_HINT=""         # Optional: "/dev/nvme0n1" for specific device
SUDO_NOPASS=true           # Set to false if sudo requires password  
NON_DESTRUCTIVE_ONLY=true  # MUST remain true for safety
```

### 3. Run Pre-flight Checks

**Test SSH connectivity:**
```bash
# Test each machine individually
ssh pi@192.168.1.100 "uname -a"
ssh admin@192.168.1.10 "free -h"
ssh root@192.168.1.20 "lscpu | head -5"
```

**Check sudo permissions (if SUDO_NOPASS=true):**
```bash
ssh user@machine "sudo -n whoami"  # Should return 'root' without password prompt
```

**Test iperf3 connectivity:**
```bash
# On server machine (manually)
ssh server_user@server_ip "iperf3 -s -1"

# From client machine (in another terminal)  
ssh client_user@client_ip "iperf3 -c server_ip -t 5"
```

### 4. Run the Benchmark

Execute the multi-host benchmark:
```bash
bin/homelab_benchmark.sh
```

**Expected execution flow:**
1. 🔍 **SSH Connectivity Test** - Validates access to all machines
2. 🔧 **Tool Installation** - Installs required packages on each host
3. 📊 **System Info Collection** - Gathers hardware/OS details
4. ⚡ **Performance Benchmarks** - Runs CPU, memory, disk tests
5. 🌐 **Network Testing** - Coordinates iperf3 tests between machines
6. 📥 **Results Collection** - Downloads all data to control machine
7. 📋 **Report Generation** - Creates comparison tables and analysis

## Configuration Examples

### Example 1: Simple Homelab
```bash
HOSTS=(
  "pi4|192.168.1.100||pi"           # Raspberry Pi 4
  "nuc|192.168.1.10||admin"         # Intel NUC
  "nas|192.168.1.20||nas"           # Synology NAS
)
IPERF_SERVER_HOST="nuc"             # Most powerful machine as server
```

### Example 2: Mixed Environment  
```bash
HOSTS=(
  "docker1|10.0.1.10|~/.ssh/docker_key|ubuntu"     # Docker host
  "k8s-master|10.0.1.20||k8s"                      # Kubernetes master
  "k8s-worker1|10.0.1.21||k8s"                     # Kubernetes worker
  "storage|10.0.1.100||storage"                    # Storage server
  "router|192.168.1.1|~/.ssh/openwrt_key|root"     # OpenWrt router
)
IPERF_SERVER_HOST="storage"                        # Central storage as server
```

### Example 3: Development Environment
```bash
HOSTS=(
  "dev-main|192.168.1.50||developer"               # Main development machine
  "test-vm1|192.168.1.51||test"                    # Test environment 1  
  "test-vm2|192.168.1.52||test"                    # Test environment 2
  "build-server|192.168.1.60||jenkins"             # CI/CD build server
)
IPERF_SERVER_HOST="build-server"                   # Build server has best network
```

## Troubleshooting

### SSH Connection Issues

**Problem**: `SSH connection failed`
```bash
# Debug with verbose output
ssh -v user@machine

# Check SSH service on target
ssh user@machine "sudo systemctl status ssh"

# Verify firewall rules
ssh user@machine "sudo ufw status"
```

**Problem**: `Permission denied (publickey)`
```bash
# Check SSH agent
ssh-add -l

# Add key manually
ssh-add ~/.ssh/id_rsa
ssh-add ~/.ssh/custom_key

# Check key permissions
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

### Package Installation Issues

**Problem**: `Package manager not found`
- The script auto-detects apt, dnf, yum, zypper, pacman
- For unsupported distributions, install tools manually:
```bash
# Required tools
sudo package-manager install sysbench hdparm fio iperf3 inxi lshw lm-sensors
```

**Problem**: `sudo: no tty present`
- Set `SUDO_NOPASS=false` in configuration
- Or configure passwordless sudo on target machines:
```bash
echo "username ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/homelab-bench
```

### Network Testing Issues

**Problem**: `iperf3 connection refused`
```bash
# Check if port 5201 is open
ssh server "sudo ufw allow 5201"
ssh server "sudo firewall-cmd --add-port=5201/tcp"

# Test manually
ssh server "iperf3 -s -1" &
ssh client "iperf3 -c server_ip -t 5"
```

**Problem**: Network benchmark shows 0 Gbps
- Firewall blocking iperf3 (port 5201)
- iperf3 server failed to start
- Network routing issues between machines
- Check logs in `logs/` directory for details

### Performance Issues

**Problem**: Benchmarks take too long
- CPU test: Reduce `--cpu-max-prime` value in script
- Memory test: Reduce `--memory-total-size` for low-RAM systems  
- Disk test: Some machines may have slow storage
- Network test: Large file transfers take time

**Problem**: Disk benchmark fails
- Check available space: `df -h /tmp`
- Verify fio permissions for test file creation
- Some systems may lack libaio support

## Advanced Configuration

### Custom Disk Testing
```bash
# Test specific devices
DISK_DEVICE_HINT="/dev/nvme0n1"    # NVMe SSD
DISK_DEVICE_HINT="/dev/sda"        # Traditional HDD
```

### Custom SSH Configuration  
```bash
# Use SSH config file for complex setups
# ~/.ssh/config
Host homelab-*
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ConnectTimeout 10
    
Host homelab-pi
    HostName 192.168.1.100
    User pi
    IdentityFile ~/.ssh/pi_key
```

### Network Segmentation
```bash
# For machines on different subnets
HOSTS=(
  "dmz-server|10.0.1.10||admin"        # DMZ network
  "lan-server|192.168.1.10||admin"     # LAN network  
  "mgmt-server|172.16.1.10||admin"     # Management network
)
```

## Results Interpretation

After successful completion, you'll have:

### Files Generated
- `reports/homelab_comparison.md` - Human-readable comparison
- `reports/homelab_metrics.csv` - Spreadsheet data
- `reports/metrics.json` - Structured data  
- `raw/<hostname>/` - Raw benchmark outputs
- `logs/` - Execution logs and debug information

### Key Metrics Explained
- **CPU events/s**: Higher = better CPU performance
- **Memory MB/s**: Memory bandwidth (higher = better)
- **Disk cached/buffered MB/s**: Storage performance metrics  
- **FIO seq read MB/s**: Real-world disk read speed
- **Network Gbps**: Bi-directional network throughput
- **Overall Score**: Weighted ranking across all metrics

### Use Cases by Performance Profile
- **High CPU + Memory**: Docker/VM hosts, development
- **High Disk I/O**: NAS, database servers, storage
- **High Network**: Routers, load balancers, proxies  
- **Balanced**: General-purpose servers, workstations

## Next Steps

1. **Run initial benchmark**: `bin/homelab_benchmark.sh`
2. **Analyze results**: Review generated reports
3. **Optimize configurations**: Based on performance characteristics  
4. **Regular monitoring**: Re-run benchmarks after changes
5. **Compare over time**: Track performance trends

## Support

If you encounter issues:
1. Check the `logs/` directory for detailed error messages
2. Verify SSH connectivity manually before running benchmark
3. Ensure all target machines have adequate disk space (1GB recommended)
4. Test network connectivity between all machines for iperf3