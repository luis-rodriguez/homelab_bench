# Quick Reference Card

## Host Configuration Cheat Sheet

### Configuration Format
```bash
HOSTS=(
  "name|ip_address|ssh_key_path|username"
)
```

### Common Examples
```bash
# Default SSH key, standard user
"pi4|192.168.1.100||pi"

# Custom SSH key
"server|10.0.0.5|~/.ssh/homelab_key|admin"

# Root user
"nas|192.168.1.20||root"

# Different subnet
"dmz|10.0.1.10||user"
```

## Pre-flight Checklist

- [ ] SSH connectivity: `ssh user@ip "echo ok"`
- [ ] Passwordless sudo: `ssh user@ip "sudo -n whoami"`
- [ ] Disk space: `ssh user@ip "df -h /tmp"`
- [ ] iperf3 port: `ssh user@ip "ss -ln | grep 5201"`

## Quick Tests

### Test SSH Access
```bash
for host in "192.168.1.100 192.168.1.10"; do
  ssh user@$host "hostname && uptime"
done
```

### Test Network Between Hosts
```bash
# Start server on machine A
ssh userA@machineA "iperf3 -s -1" &

# Test from machine B  
ssh userB@machineB "iperf3 -c machineA_ip -t 5"
```

### Check Required Tools
```bash
ssh user@host "which sysbench fio iperf3 hdparm"
```

## Common Errors & Quick Fixes

| Error | Quick Fix |
|-------|-----------|
| `SSH connection failed` | `ssh-copy-id user@host` |
| `sudo: no tty present` | Set `SUDO_NOPASS=false` |
| `iperf3: command not found` | `ssh host "sudo apt install iperf3"` |
| `Permission denied` | `chmod 600 ~/.ssh/id_rsa` |
| `Connection refused` | Check firewall: `sudo ufw allow 5201` |

## File Locations

| Type | Location |
|------|----------|
| Reports | `reports/homelab_comparison.md` |
| CSV Data | `reports/homelab_metrics.csv` |
| Raw Results | `raw/<hostname>/` |
| Logs | `logs/` |
| Config | `homelab_benchmark.sh` (lines 9-18) |

## Performance Interpretation

### CPU Performance
- **> 1000 events/sec**: Excellent (modern desktop/server)
- **500-1000**: Good (mid-range, older server)
- **< 500**: Low power (Pi, embedded, old hardware)

### Memory Throughput  
- **> 20 GB/s**: Excellent (DDR4-3200+)
- **10-20 GB/s**: Good (DDR4/DDR3)
- **< 10 GB/s**: Older/slower memory

### Disk Performance (FIO Sequential Read)
- **> 3 GB/s**: NVMe SSD (PCIe 3.0+)
- **500 MB/s - 3 GB/s**: SATA SSD
- **< 200 MB/s**: Traditional HDD

### Network Performance
- **> 0.9 Gbps**: Gigabit Ethernet (good)
- **> 9 Gbps**: 10 Gigabit Ethernet  
- **< 0.1 Gbps**: WiFi or congested network

## Typical Use Case Assignments

### High CPU Score
- Docker container hosts
- Development/build servers
- VM hypervisors
- Compute workloads

### High Memory Score  
- Database servers
- Caching layers (Redis, Memcached)
- In-memory analytics
- Large VM hosts

### High Disk Score
- File servers / NAS
- Database storage
- Backup destinations
- Media streaming

### High Network Score
- Load balancers / proxies  
- Router/firewall appliances
- Network storage (iSCSI, NFS)
- CDN edge nodes

## Automation Commands

### Run and Email Results
```bash
./homelab_benchmark.sh && \
mail -s "Homelab Benchmark Results" user@email.com < reports/homelab_comparison.md
```

### Schedule Monthly Benchmarks
```bash
# Add to crontab
0 2 1 * * cd /path/to/homelab_bench_results && ./homelab_benchmark.sh
```

### Compare Before/After
```bash
# Backup previous results
cp reports/homelab_metrics.csv reports/homelab_metrics_$(date +%Y%m%d).csv

# Run new benchmark
./homelab_benchmark.sh

# Compare
diff reports/homelab_metrics_*.csv
```