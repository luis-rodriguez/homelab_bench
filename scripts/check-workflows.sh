#!/usr/bin/env bash
set -euo pipefail

root=".github/workflows"
bad=0
echo "Scanning $root for deprecated action usage..."
while IFS= read -r -d '' f; do
  if grep -nH "actions/upload-artifact@v3" "$f" >/dev/null 2>&1; then
    echo "Deprecated upload-artifact@v3 found in $f"
    bad=1
  fi
done < <(find "$root" -name '*.yml' -print0)

if [[ $bad -ne 0 ]]; then
  echo "Deprecated action usage detected. Please update to supported versions (upload-artifact@v4)."
  exit 1
fi
echo "No deprecated action usage found."
