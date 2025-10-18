# Security Policy for Homelab Benchmarking Suite

Version: 1.0
Date: 2025-10-18

This document establishes security rules and operational constraints for running the homelab benchmarking scripts and for modifications to this repository.

## Purpose
Provide clear, auditable rules so the benchmarking tooling runs safely across production and lab hosts.

## Scope
Applies to `homelab_benchmark.sh`, `local_benchmark.sh`, their remote components, and any automation that uses these scripts.

## Policy
1. Host Validation
   - All hosts added to `HOSTS` must be authorized and verified. Host entries must follow this format: `name|ip|ssh_key_path|username`.
   - `name` must match `^[A-Za-z0-9._-]+$`.
   - `ssh_key_path` must be an absolute path beginning with `/` and readable by the invoking user.
   - IP/hostnames must be validated by `getent hosts` or a successful `ssh -G` check before executing benchmarks.

2. SSH and Host Keys
   - `StrictHostKeyChecking=no` is forbidden. Use `StrictHostKeyChecking=accept-new` only for test-only environments.
   - For production or persistent use, maintain a `known_hosts` file under the repo and use `ssh-keyscan` to populate it; pass `-o UserKnownHostsFile=`.

3. Privilege Escalation
   - Do not run scripts as root. Use `sudo` only for specific commands requiring elevated privileges.
   - Do not assume passwordless sudo. Scripts must detect whether `sudo` is non-interactive with `sudo -n true` and either skip privileged steps or exit with an informative message.
   - Avoid automatic kernel-module loading or interactive system changes without operator consent (e.g., `sensors-detect`).

4. Temporary Files
   - Always use `mktemp` for temporary files and remove them on exit via `trap`.
   - Avoid predictable filenames under `/tmp`.

5. Package Installation
   - Automatic package installation on remote hosts is disallowed by default. Use `--install-tools` to request installation and require operator confirmation (interactive or via `--yes`).
   - Log all package installation operations and record the package manager used.

6. Network Transfers & Integrity
   - Prefer `rsync --checksum -e "ssh ..."` for large transfers and verify file sizes/checksums after transfer.
   - Do not disable host key verification for SCP/SSH.

7. Logging and Error Handling
   - Capture stdout and stderr of remote commands into per-host log files in `logs/`.
   - Do not globally suppress stderr; surface errors to logs and, when critical, stop execution.

8. Change Control
   - Any changes to benchmarking scripts must be code-reviewed and signed-off before running in production.

## Incident Handling
- On any unexpected system modification or security alert, stop benchmarking and collect logs from `logs/` and `raw/` for triage.

## Enforcement
- The repository contains a `SECURITY_AUDIT.md` and `SECURITY_AUDIT_LOCAL.md` recording prior audits; follow the actions described there.


*** End of Policy ***
