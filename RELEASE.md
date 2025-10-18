# Release v1.0.0

This is a lightweight release marking the audited and hardened initial version of the Homelab Benchmarking Suite.

What's included

- `homelab_benchmark.sh` - Orchestrator, hardened (SSH options, host validation, DRY-RUN, safer iperf handling)
- `local_benchmark.sh` - Local runner, hardened (mktemp, trap cleanup, DRY-RUN)
- `SECURITY.md`, `SECURITY_POLICY.md`, `SECURITY_AUDIT.md`, `SECURITY_AUDIT_LOCAL.md` - Security docs and audit notes
- GitHub Actions:
  - `.github/workflows/shellcheck.yml` - run ShellCheck + bash -n
  - `.github/workflows/smoke.yml` - smoke tests that run `--dry-run` for both scripts

Notes

- This release is focused on non-destructive testing and operational safety. Before using in production, review `SECURITY_POLICY.md` and populate `SECURITY.md` contact details.

Changelog

- Hardened SSH usage and remote invocation
- Implemented DRY-RUN and safer temp file handling
- Added CI checks: shellcheck and smoke tests
- Added security policy and audit documents
