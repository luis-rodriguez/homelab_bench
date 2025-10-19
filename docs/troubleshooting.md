---
layout: default
title: Troubleshooting
---

# Troubleshooting

Common issues

- SSH prompts or failures: ensure SSH keys are configured and `ssh -o BatchMode=yes host 'true'` succeeds.
- Missing tools (sysbench, fio, iperf3): run the local installer with `--install-tools --yes` or install packages manually.
- Permission errors when fetching results: consider using a tar-stream approach (we can update the fetcher to use `ssh host 'tar -C $tmpdir -cf - .' | tar -C dest -xpf -`).

If you encounter other issues, open an issue or submit a PR with the failing command output.
