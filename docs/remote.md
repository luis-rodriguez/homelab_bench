---
layout: default
title: Remote Benchmark
---

# Remote Benchmark

The remote benchmark helper is intended to be deployed to remote hosts by the orchestrator and executed there. The orchestrator copies the helper, runs it via SSH, and fetches back raw results into `results/raw/<host>/`.

Files

- `bin/remote/remote_benchmark.sh` — full remote helper that runs sysinfo, sysbench, fio/hdparm, iperf3 and power readings where available.
- `bin/remote/run_remote.sh` — used by the orchestrator to copy and run the helper.
- `bin/remote/fetch_results.sh` — copies results back into local `results/raw/<host>/`.

Security considerations

- The orchestrator uses `ssh -o BatchMode=yes` to avoid interactive password prompts. Ensure SSH keys or an agent are set up for non-interactive runs.
- The remote helper writes results into a temporary directory on the remote host (default: `/tmp/homelab_remote_results`). If your environment requires privileged operations (e.g., `hdparm` or `powertop`), grant appropriate sudo permissions or run under an account with required access.

Example orchestrator flow (what happens under the hood)

1. Orchestrator validates SSH connectivity to the host.
2. Orchestrator uses `scp` to copy `bin/remote/remote_benchmark.sh` to a remote temporary directory.
3. Orchestrator invokes the helper via `ssh` (non-interactive). Helper writes files to remote tmpdir.
4. Orchestrator uses `scp -r` to fetch results into `results/raw/<host>/` locally.
5. Orchestrator optionally cleans up the remote temporary directory.

Run example (dry-run):

```bash
bin/homelab_benchmark.sh --dry-run host1.example.com
```

Run example (real):

```bash
bin/homelab_benchmark.sh host1.example.com
```
