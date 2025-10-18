# Security: how to report vulnerabilities

This repository accepts responsible disclosure of security vulnerabilities. GitHub recognizes `SECURITY.md` in the repository root and will present the contact instructions in the Security tab.

If you believe you have found a security issue, please report it privately — do not open a public issue.

Preferred reporting methods

- GitHub Security Advisories (recommended):
  1. Open the repository on GitHub.
  2. Click the "Security" tab → "Advisories" → "New draft security advisory".
  3. Create a private advisory and provide details there.

- If you cannot use GitHub Advisories, please email a report to: SECURITY_CONTACT
  (replace `SECURITY_CONTACT` with a working email for your project maintainers).

What to include

- Affected file(s) and commit SHA or tag
- Clear description of the vulnerability and impact
- Reproduction steps, proof-of-concept, or exploit (privately attached)
- Environment and versions where you tested
- Suggested mitigation or patch if available

Encryption

If you want to encrypt vulnerability details, use our PGP key (if provided). If you don't have a PGP key, please contact us and we will provide one.

PGP: NO_PGP_KEY_PROVIDED

Response timeline

- Acknowledgement: within 3 business days
- Triage and verification: within 7 business days where possible
- Fix and advisory: timeline depends on severity; we typically aim to coordinate disclosure and publish a fix within 90 days

Public disclosure

We will work with you to coordinate disclosure. We will not publicly disclose a vulnerability without coordination and a reasonable remediation plan.

Related documentation

- Operational security guidance and runtime safety is documented in `SECURITY_POLICY.md` (host validation, sudo rules, temp files, install policy).
- Audit notes are recorded in `SECURITY_AUDIT.md` and `SECURITY_AUDIT_LOCAL.md`.

Replacing the contact

Please edit `SECURITY.md` and replace `SECURITY_CONTACT` and `NO_PGP_KEY_PROVIDED` with an appropriate contact email and PGP fingerprint for your project.

---

Thank you for helping keep this project secure.
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

# Security: how to report vulnerabilities

This repository accepts responsible disclosure of security vulnerabilities. GitHub recognizes `SECURITY.md` in the repository root and will present the contact instructions in the Security tab.

If you believe you have found a security issue, please report it privately — do not open a public issue.

Preferred reporting methods

- GitHub Security Advisories (recommended):
  1. Open the repository on GitHub.
  2. Click the "Security" tab → "Advisories" → "New draft security advisory".
  3. Create a private advisory and provide details there.

- If you cannot use GitHub Advisories, please email a report to: SECURITY_CONTACT
  (replace `SECURITY_CONTACT` with a working email for your project maintainers).

What to include

- Affected file(s) and commit SHA or tag
- Clear description of the vulnerability and impact
- Reproduction steps, proof-of-concept, or exploit (privately attached)
- Environment and versions where you tested
- Suggested mitigation or patch if available

Encryption

If you want to encrypt vulnerability details, use our PGP key (if provided). If you don't have a PGP key, please contact us and we will provide one.

PGP: NO_PGP_KEY_PROVIDED

Response timeline

- Acknowledgement: within 3 business days
- Triage and verification: within 7 business days where possible
- Fix and advisory: timeline depends on severity; we typically aim to coordinate disclosure and publish a fix within 90 days

Public disclosure

We will work with you to coordinate disclosure. We will not publicly disclose a vulnerability without coordination and a reasonable remediation plan.

Related documentation

- Operational security guidance and runtime safety is documented in `SECURITY_POLICY.md` (host validation, sudo rules, temp files, install policy).
- Audit notes are recorded in `SECURITY_AUDIT.md` and `SECURITY_AUDIT_LOCAL.md`.

Replacing the contact

Please edit `SECURITY.md` and replace `SECURITY_CONTACT` and `NO_PGP_KEY_PROVIDED` with an appropriate contact email and PGP fingerprint for your project.

---

Thank you for helping keep this project secure.
