#!/usr/bin/env bash
set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed; skipping"
  exit 0
fi

echo "Running shellcheck on bin/ and scripts/"
shellcheck bin/*.sh scripts/*.sh || true
