---
layout: default
title: Orchestrator
---

# Orchestrator

`bin/homelab_benchmark.sh` is the multi-host orchestrator. It is intentionally small and delegates work to `bin/remote/*` helpers.

Usage

```bash
bin/homelab_benchmark.sh --dry-run host1 host2
```

Behavior

- Validates SSH connectivity with `ssh -o BatchMode=yes -o ConnectTimeout=5`.
- Copies `bin/remote/remote_benchmark.sh` to a per-host remote temp dir (via `scp`).
- Runs the remote helper via `ssh` and waits for completion.
- Fetches remote results back to `results/raw/<host>/`.
- Cleans up the remote temporary directory.

Failure modes and recovery

- If `ssh` fails (connectivity/keys), the orchestrator skips the host and logs a warning.
- If `scp` or remote execution fails, the orchestrator continues with other hosts and logs warnings. You can re-run the orchestrator for the failed hosts.

Parallelism and scaling

The current orchestrator runs hosts sequentially. For larger fleets consider adding simple concurrency. Example using background jobs with a semaphore:

```bash
MAX_JOBS=8
sem() { while (( $(jobs -rp | wc -l) >= MAX_JOBS )); do sleep 0.2; done }

for host in "${HOSTS[@]}"; do
  sem
  ( run_host_workflow "$host" ) &
done
wait
```

Alternatively use `xargs -P` or GNU `parallel` for more advanced scheduling and retries.

Fetch optimization (tar-stream)

If you encounter permission or performance issues with `scp`, replace the fetch with a remote tar stream (see `docs/remote.md`):

```bash
ssh "$host" "tar -C '$remote_tmp' -cf - ." | tar -C "$results_dir/raw/$host" -xpf -
```
---
