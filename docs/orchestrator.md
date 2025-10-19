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
