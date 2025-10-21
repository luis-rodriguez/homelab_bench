# Security Audit - local_benchmark.sh

Release: v1.1
Commit: 81f8b96
Last automated update: 2025-10-21 19:08:45Z (UTC)

This audit was generated/updated by CI. Below is the trimmed shellcheck output.

## ShellCheck summary (trimmed)

bin/homelab_benchmark.sh:35:8: note: Not following: ./remote/utils.sh was not specified as input (see shellcheck -x). [SC1091]
bin/homelab_benchmark.sh:36:8: note: Not following: ./remote/setup.sh was not specified as input (see shellcheck -x). [SC1091]
bin/homelab_benchmark.sh:37:8: note: Not following: ./remote/run_remote.sh was not specified as input (see shellcheck -x). [SC1091]
bin/homelab_benchmark.sh:38:8: note: Not following: ./remote/fetch_results.sh was not specified as input (see shellcheck -x). [SC1091]
bin/homelab_benchmark.sh:41:8: note: echo may not expand escape sequences. Use printf. [SC2028]
bin/local/benchmark_cpu.sh:7:11: warning: raw_dir appears unused. Verify use (or export if used externally). [SC2034]
bin/local/benchmark_cpu.sh:8:11: warning: host appears unused. Verify use (or export if used externally). [SC2034]
bin/local/benchmark_disk.sh:7:11: warning: raw_dir appears unused. Verify use (or export if used externally). [SC2034]
bin/local/benchmark_disk.sh:8:11: warning: host appears unused. Verify use (or export if used externally). [SC2034]
bin/local/benchmark_memory.sh:7:11: warning: raw_dir appears unused. Verify use (or export if used externally). [SC2034]
bin/local/benchmark_memory.sh:8:11: warning: host appears unused. Verify use (or export if used externally). [SC2034]
bin/local/benchmark_network.sh:7:11: warning: raw_dir appears unused. Verify use (or export if used externally). [SC2034]
bin/local/benchmark_network.sh:8:11: warning: host appears unused. Verify use (or export if used externally). [SC2034]
bin/local/collect_sysinfo.sh:7:11: warning: raw_dir appears unused. Verify use (or export if used externally). [SC2034]
bin/local/collect_sysinfo.sh:8:11: warning: host appears unused. Verify use (or export if used externally). [SC2034]
bin/local/monitor_power.sh:7:11: warning: raw_dir appears unused. Verify use (or export if used externally). [SC2034]
bin/local/monitor_power.sh:8:11: warning: host appears unused. Verify use (or export if used externally). [SC2034]
bin/local_benchmark.sh:23:20: warning: DRY_RUN appears unused. Verify use (or export if used externally). [SC2034]
bin/remote/remote_benchmark.sh:17:17: warning: HOSTNAME_OVERRIDE appears unused. Verify use (or export if used externally). [SC2034]
bin/remote/remote_benchmark.sh:30:70: note: Note that A && B || C is not if-then-else. C may run when A is true. [SC2015]
bin/remote/run_remote.sh:23:35: note: Note that, unescaped, this expands on the client side. [SC2029]
bin/remote/run_remote.sh:26:26: note: Note that, unescaped, this expands on the client side. [SC2029]
bin/remote/utils.sh:11:37: note: Note that, unescaped, this expands on the client side. [SC2029]
bin/remote_benchmark.sh:15:19: warning: AUTO_YES appears unused. Verify use (or export if used externally). [SC2034]
bin/homelab_benchmark.sh:35:8: note: Not following: ./remote/utils.sh was not specified as input (see shellcheck -x). [SC1091]
bin/homelab_benchmark.sh:36:8: note: Not following: ./remote/setup.sh was not specified as input (see shellcheck -x). [SC1091]
bin/homelab_benchmark.sh:37:8: note: Not following: ./remote/run_remote.sh was not specified as input (see shellcheck -x). [SC1091]
bin/homelab_benchmark.sh:38:8: note: Not following: ./remote/fetch_results.sh was not specified as input (see shellcheck -x). [SC1091]
bin/homelab_benchmark.sh:41:8: note: echo may not expand escape sequences. Use printf. [SC2028]
bin/local_benchmark.sh:23:20: warning: DRY_RUN appears unused. Verify use (or export if used externally). [SC2034]
bin/remote_benchmark.sh:15:19: warning: AUTO_YES appears unused. Verify use (or export if used externally). [SC2034]
