# Security Audit - local_benchmark.sh

Date: 2025-10-18

This document summarizes the security audit performed on `local_benchmark.sh` and the hardening changes applied.

Release: v1.0.0
Last automated update: 2025-10-18

NOTE: This file is (or can be) updated automatically by CI. See `.github/workflows/update-audits.yml` and `scripts/update_audits.sh`.

## Overview
`local_benchmark.sh` runs non-destructive performance benchmarks on the local machine and updates reports in the repository. The script collects system information, runs CPU/memory/disk/network tests, optionally installs tools, and collects power/temperature information.

## Major findings (summary)
- The script auto-answered `sensors-detect` with `yes | sudo sensors-detect`, which could load kernel modules or change kernel state automatically.
- A fixed temporary filename was used for fio (`/tmp/fio_test.bin`) which is susceptible to symlink and TOCTOU attacks.continue
- The script assumed `sudo` would be non-interactive (SUDO_NOPASS=true) without verifying it; operations may fail or hang if sudo prompts for password.
- Several commands silenced stderr with `2>/dev/null`, which can hide actionable errors.
- Use of `pkill iperf3` may affect unrelated processes; PID-based management is safer.
- No `trap` existed to clean temporary files on exit or signals.

## Changes applied
1. Added `RUN_SENSORS_DETECT=false` and removed automatic sensors-detect. Running sensors-detect must be explicit and interactive.
2. Replaced fixed `/tmp` fio test file with `mktemp` and registered it in a `TMPFILES` array; added `trap` cleanup on EXIT/INT/TERM.
3. Added `preflight_checks` to ensure `RESULTS_DIR` exists and is writable before proceeding.
4. Replaced unconditional package-install attempt with a `sudo -n true` check to verify non-interactive sudo before installing.
5. Redirected fio output to a log file (`fio_run.log`) and surfaced failures rather than silently discarding stderr.

## Recommended follow-ups
- Verify ownership and mount options of `RESULTS_DIR` (avoid running on untrusted or world-writable mounts).
- Replace `pkill iperf3` with PID tracking to stop only the server started by this script.
- Require explicit CLI flags for package installation (for example, `--install-tools`) instead of always attempting installs.
- Run `shellcheck` and address its warnings for safer quoting and expansions.
- Add a `--dry-run` mode and a `--yes` flag for operator confirmation of destructive or state-changing actions.

## Severity summary
- High: mktemp missing (fixed), sensors-detect auto-run (fixed), no trap/cleanup (fixed)
- Medium: assumptions about passwordless sudo (mitigated by check), silent stderr suppression (partially mitigated)
- Low: pkill usage, device autodetection heuristics

---

Files changed:
- `local_benchmark.sh` (hardening: mktemp, trap cleanup, sensors-detect opt-in, sudo checks)

If you want I can apply additional hardening (PID management for iperf3, explicit package install flags, and shellcheck-based fixes)."}