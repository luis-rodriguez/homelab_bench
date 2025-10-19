---
layout: default
title: Local Benchmark
---

# Local Benchmark

The local benchmark runs on a single host and collects system information and non-destructive performance measurements.

Files

- `bin/local_benchmark.sh` — compact orchestrator that sources the modules in `bin/local/`.
- `bin/local/utils.sh` — logging, cleanup and preflight checks.
- `bin/local/setup.sh` — prepares the raw directory and CD's into it.
- `bin/local/install_tools.sh` — optional tool installer (requires `--install-tools` and `--yes`).
- `bin/local/collect_sysinfo.sh` — collects `sysinfo.txt`.
- `bin/local/benchmark_cpu.sh` — runs sysbench CPU test (`cpu_bench.txt`).
- `bin/local/benchmark_memory.sh` — runs sysbench memory test (`memory_bench.txt`).
- `bin/local/benchmark_disk.sh` — non-destructive hdparm and fio (temporary file) (`disk_bench.txt`).
- `bin/local/benchmark_network.sh` — iperf3 loopback test (`network_bench.txt`).
- `bin/local/monitor_power.sh` — powertop and sensors data (`power_info.txt`).
- `bin/local/update_reports.sh` — consolidates raw results into `reports/metrics.json`.

How to run

Run a non-destructive dry-run locally:

```bash
bin/local_benchmark.sh --dry-run
```

To run full benchmarks (may require sudo and installed tools):

```bash
bin/local_benchmark.sh --install-tools --yes
```

Outputs

- Raw data: `raw/localhost/*`
- Aggregated metrics: `reports/metrics.json`
- Human-readable comparison: `reports/homelab_comparison.md`
