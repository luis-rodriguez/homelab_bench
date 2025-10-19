#!/usr/bin/env bash

# Simple audit updater:
# - runs shellcheck on scripts
# - collects short summary and writes SECURITY_AUDIT*.md files header with timestamp and shellcheck output

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TIMESTAMP="$(date -u '+%Y-%m-%d %H:%M:%SZ')"
RELEASE_TAG="v1.1"
GIT_SHORT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

# Run shellcheck and capture output
shopt -s globstar || true
SC_OUT=$(shellcheck --format=gcc bin/**/*.sh bin/*.sh scripts/**/*.sh scripts/*.sh 2>&1 || true)
# Keep a short trimmed summary (first 60 lines)
SC_SUMMARY="$(echo "$SC_OUT" | head -n 60)"

# Update SECURITY_AUDIT.md (write header, then append the shellcheck summary safely)
cat > SECURITY_AUDIT.md <<EOF
# Security Audit - homelab_benchmark.sh

Release: $RELEASE_TAG
Commit: $GIT_SHORT
Last automated update: $TIMESTAMP (UTC)

This audit was generated/updated by CI. Below is the trimmed shellcheck output.

## ShellCheck summary (trimmed)

EOF

# append the (expanded) shellcheck summary safely
printf '%s
' "$SC_SUMMARY" >> SECURITY_AUDIT.md

# Update SECURITY_AUDIT_LOCAL.md (write header, then append the shellcheck summary safely)
cat > SECURITY_AUDIT_LOCAL.md <<EOF
# Security Audit - local_benchmark.sh

Release: $RELEASE_TAG
Commit: $GIT_SHORT
Last automated update: $TIMESTAMP (UTC)

This audit was generated/updated by CI. Below is the trimmed shellcheck output.

## ShellCheck summary (trimmed)

EOF

# append the (expanded) shellcheck summary safely
printf '%s
' "$SC_SUMMARY" >> SECURITY_AUDIT_LOCAL.md

# Exit 0 (the workflow will commit changes if any)
exit 0
