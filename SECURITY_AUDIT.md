# Security Audit - homelab_benchmark.sh

Date: 2025-10-18

This document summarizes the security audit performed on `homelab_benchmark.sh` and the changes applied to harden the script.

## Overview
`homelab_benchmark.sh` orchestrates non-destructive performance benchmarks across multiple Linux hosts using SSH/SCP. The script generates a remote script (`remote_benchmark.sh`), copies it to target hosts, executes it, and retrieves results. It also coordinates `iperf3` network tests and generates reports locally.

## Major findings (summary)
- The script previously disabled SSH host key checking (`StrictHostKeyChecking=no`) which weakens SSH authenticity guarantees (MITM risk).
- Remote commands and SSH options were built using plain strings allowing potential shell injection or word-splitting issues.
- Use of fixed filenames in `/tmp` for test files (e.g., `/tmp/fio_test.bin`) enabled TOCTOU and symlink attacks.
- `sensors-detect` was auto-answered (`yes | sensors-detect`) — dangerous because it can propose kernel module changes.
- Environment variables and values were injected into remote command strings without robust quoting; this can break quoting and allow injection.
- Several commands suppressed stderr (`2>/dev/null`) and used `|| true`, hiding failure causes.

## Changes applied
1. Replaced `StrictHostKeyChecking=no` with `StrictHostKeyChecking=accept-new` and moved SSH/scp options into arrays to avoid unsafe word splitting.
2. Implemented basic validations for `ip` and `user` in `test_ssh`, `remote_exec`, and `remote_copy`.
3. Rewrote `remote_exec` and `remote_copy` to build options with arrays and pass remote commands after `--` to avoid option/argument confusion.
4. Replaced fixed `/tmp/fio_test.bin` use with `mktemp` to create secure temporary files and removed insecure tmp usage.
5. Removed automatic `yes | sensors-detect` auto-answer; the script now logs that `sensors-detect` is available and advises manual execution.

## Recommended follow-ups (not yet implemented)
- Pre-populate and use a controlled `known_hosts` file or use `ssh-keyscan` to manage host keys; do not rely on `accept-new` in unattended environments.
- Sanitize and validate all fields in `HOSTS` (name, ip, key path, username) more strictly (regex checks for allowed characters, absolute path checks for keys).
- Avoid remote package installation by default; provide an explicit `--install-tools` flag and require user consent for package installs.
- Replace `scp` with `rsync --checksum` for better transfer verification or verify checksums after transfer.
- Add explicit log capture for remote stderr/stdout rather than silencing (reduce `2>/dev/null` use).
- Consider using `shellcheck` and/or `bash -n` in CI to detect common issues.

## How to review the patches
- See `homelab_benchmark.sh` for the applied changes to the ssh helper functions and remote fio tempfile handling.

## Severity summary
- Critical: command injection via untrusted HOSTS entries (ensure HOSTS cannot be tampered with)
- High: disabled host key checking, unsafe remote command assembly, temp file race conditions
- Medium: auto package installs, hidden errors, sensors auto-answer
- Low: use of pkill, hard-coded directories without permission checks

---

For more details and a step-by-step migration to a safer operation mode, see the original audit report produced during the review (ask to generate a fully expanded report if needed).
