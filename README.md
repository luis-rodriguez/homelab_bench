# Homelab Benchmarking System

A comprehensive, non-destructive performance testing suite for Linux homelab environments.

## Overview

This system allows you to benchmark multiple Linux hosts across your homelab infrastructure and generate comparative reports. All tests are designed to be **completely non-destructive** and safe to run on production systems.

## Features

- ✅ **Non-destructive testing** - No data loss or system damage risk
- 🖥️ **Multi-host support** - Benchmark multiple machines via SSH
- 📊 **Comprehensive metrics** - CPU, memory, disk, network, temperatures
- 🔄 **Auto-detection** - Package managers, devices, network interfaces
- 📋 **Rich reports** - Markdown tables, CSV data, recommendations
- 🔒 **Secure** - SSH key authentication, graceful error handling

## Quick Start

### Local Machine Benchmarking
```bash
# Benchmark this computer
./local_benchmark.sh
```

### Remote Hosts Benchmarking
```bash
# 1. Configure your machines (see SETUP_GUIDE.md for details)
# 2. Edit homelab_benchmark.sh with your machine details
# 3. Run the benchmark
bin/homelab_benchmark.sh
```

📖 **For detailed multi-host setup instructions, see [SETUP_GUIDE.md](SETUP_GUIDE.md)**

## Configuration

### Host Configuration Format
```bash
HOSTS=(
  "name|ip_address|ssh_key_path|username"
  "machineA|192.168.0.185||luis"
  "machineB|192.168.0.160|/path/to/key|user"
)
```

### Settings
- `IPERF_SERVER_HOST`: Which machine runs the iperf3 server for network tests
- `DISK_DEVICE_HINT`: Specific device to test (optional, auto-detects if empty)
- `SUDO_NOPASS`: Whether sudo works without password prompts
- `NON_DESTRUCTIVE_ONLY`: Safety flag (must remain true)

## Benchmarks Performed

### System Information
- Hardware specifications (CPU, memory, storage)
- Operating system and kernel details
- Network configuration
- Temperature sensors

### Performance Tests
- **CPU**: sysbench prime number computation
- **Memory**: sysbench memory throughput test
- **Disk**: hdparm cache/buffer tests + fio sequential reads
- **Network**: iperf3 bidirectional throughput tests
- **Thermals**: lm-sensors temperature monitoring
- **Power**: powertop analysis (if available)

## Safety Features

- Read-only disk tests with automatic cleanup
- SSH key authentication (no passwords)
- Graceful handling of missing tools/permissions
- Automatic detection of supported package managers
- Non-interactive installation and setup

## Output Structure

```
homelab_bench_results/
├── homelab_benchmark.sh     # Multi-host orchestrator
├── local_benchmark.sh       # Local machine benchmark
├── logs/                    # Execution logs
├── raw/                     # Raw benchmark data per host
├── reports/                 # Generated analysis
│   ├── homelab_comparison.md    # Markdown report
│   ├── homelab_metrics.csv      # Raw metrics CSV
│   └── metrics.json             # Structured data
└── README.md               # This file
```

## Reports Generated

### Markdown Report (`homelab_comparison.md`)
- Ranked comparison table across all metrics
- Detailed system specifications
- Role-based recommendations:
  - 🏆 Overall best performer
  - 🐳 Best for Docker/VM workloads
  - 💾 Best for NAS/backup storage
  - 🌐 Best for network services

### CSV Export (`homelab_metrics.csv`)
Raw metrics for further analysis or importing into other tools.

### JSON Data (`metrics.json`)
Structured data for programmatic processing.

## Requirements

### Control Machine
- Linux with bash/zsh
- Python 3 with standard libraries
- SSH client
- Internet connection (for package installation)

### Target Hosts
Tools are automatically installed, but manual installation may be needed for:
- sysbench, hdparm, fio, iperf3
- inxi, lshw, lm-sensors
- Standard utilities (grep, awk, etc.)

## Supported Distributions

- **Debian/Ubuntu** (apt)
- **RHEL/CentOS/Fedora** (dnf/yum)
- **SUSE/openSUSE** (zypper)
- **Arch Linux** (pacman)

## Usage Examples

### Benchmark Multiple Hosts
```bash
# Configure hosts in script
bin/homelab_benchmark.sh
```

### Add Local Machine to Comparison
```bash
./local_benchmark.sh
```

### View Results
```bash
# View markdown report
cat reports/homelab_comparison.md

# Open CSV in spreadsheet
libreoffice reports/homelab_metrics.csv
```

## Troubleshooting

### SSH Issues
- Ensure SSH key authentication works: `ssh user@host "echo ok"`
- Check host connectivity and firewall rules
- Verify user has appropriate permissions

### Missing Tools
- Check logs in `logs/` directory for installation failures
- Some tools require manual installation on certain distributions
- Missing tools will be noted in reports, benchmarks continue with available tools

### Permission Errors
- Some tests require sudo (hdparm, lshw, powertop)
- Set `SUDO_NOPASS=false` if sudo requires password
- Tests gracefully degrade when permissions are insufficient

## Contributing

This system is designed to be easily extended. To add new benchmarks:

1. Add benchmark function to remote script
2. Update parsing logic in report generation
3. Add metrics to output tables
4. Test across different distributions

## License

This project is provided as-is for homelab and educational use.