#!/usr/bin/env bash
# update_reports: gather raw results and update reports/metrics.json using embedded Python

set -euo pipefail

update_reports() {
    local results_dir="$1"
    log "Adding local results to comparison reports..."

    python3 - << 'PY'
import json
import re
from pathlib import Path

results_dir = Path('/media/luis/sec-hdd/homelab_bench_results')
raw_dir = results_dir / 'raw'
reports_dir = results_dir / 'reports'
reports_dir.mkdir(parents=True, exist_ok=True)

metrics_file = reports_dir / 'metrics.json'
if metrics_file.exists():
    with open(metrics_file, 'r') as f:
        metrics = json.load(f)
else:
    metrics = {}

def parse_sysbench_cpu(content):
    m = re.search(r'events per second:\s*([0-9.]+)', content)
    return {'events_per_sec': float(m.group(1)) if m else 0}

def parse_sysbench_memory(content):
    m = re.search(r'(\d+\.?\d*)\s*MiB/sec', content)
    return {'throughput_mb_per_s': float(m.group(1)) if m else 0}

def parse_hdparm(content):
    m = re.search(r'Timing cached reads:\s*(\d+)', content)
    n = re.search(r'Timing buffered disk reads:\s*(\d+)', content)
    return {'cached_mb_per_s': int(m.group(1)) if m else 0, 'buffered_mb_per_s': int(n.group(1)) if n else 0}

def parse_fio(content):
    m = re.search(r'READ:.*bw=([0-9.]+)([KMG]?)iB/s', content)
    if m:
        bw = float(m.group(1))
        unit = m.group(2)
        if unit == 'K': bw = bw/1024
        elif unit == 'G': bw = bw*1024
        return {'seq_read_mb_per_s': bw}
    return {'seq_read_mb_per_s': 0}

def parse_iperf3(content):
    s = re.search(r'sender.*?([0-9.]+)\s*([KMG])bits/sec', content)
    r = re.search(r'receiver.*?([0-9.]+)\s*([KMG])bits/sec', content)
    def conv(v,u):
        if u=='K': return v/1000000
        if u=='M': return v/1000
        return v
    return {'to_server_gbps': conv(float(s.group(1)), s.group(2)) if s else 0, 'from_server_gbps': conv(float(r.group(1)), r.group(2)) if r else 0}

localhost_dir = raw_dir / 'localhost'
if localhost_dir.exists():
    host_metrics = {'cpu':{}, 'memory':{}, 'disk':{}, 'network':{}, 'temps':{}, 'system':{}}
    for f in localhost_dir.glob('*.txt'):
        try:
            content = f.read_text()
        except Exception:
            continue
        if f.name == 'sysinfo.txt':
            # minimal parsing
            cpu_m = re.search(r'Model name:\s*(.+)', content)
            if cpu_m: host_metrics['system']['cpu_model'] = cpu_m.group(1).strip()
        elif f.name == 'cpu_bench.txt':
            host_metrics['cpu'].update(parse_sysbench_cpu(content))
        elif f.name == 'memory_bench.txt':
            host_metrics['memory'].update(parse_sysbench_memory(content))
        elif f.name == 'disk_bench.txt':
            host_metrics['disk'].update(parse_hdparm(content))
            host_metrics['disk'].update(parse_fio(content))
        elif f.name == 'network_bench.txt':
            host_metrics['network'].update(parse_iperf3(content))
    metrics['localhost'] = host_metrics

with open(metrics_file, 'w') as f:
    json.dump(metrics, f, indent=2)

print('Reports updated with localhost results!')
PY

    success "Reports updated with local results"
}
