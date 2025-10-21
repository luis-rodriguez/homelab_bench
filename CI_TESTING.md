# CI/CD and Testing Documentation

## Overview

This repository uses GitHub Actions for continuous integration and testing. The workflows are designed to validate code quality, syntax, and functionality without requiring actual hardware or SSH access.

## Main CI Workflow

The primary CI workflow is defined in `.github/workflows/ci.yml` and runs on all pull requests and pushes to `main`/`master` branches.

### Jobs

1. **ShellCheck** - Static analysis of shell scripts
2. **Bash Syntax Check** - Validates bash syntax across all `.sh` files
3. **Smoke Tests** - Runs dry-run mode of benchmark scripts
4. **Workflow Validation** - Checks for deprecated GitHub Actions

## Environment Variables

### RESULTS_BASE_DIR

The benchmark scripts now support the `RESULTS_BASE_DIR` environment variable to override the default results directory.

**Default behavior:**
- Local usage: `$HOME/homelab_bench_results`
- CI environment: `$GITHUB_WORKSPACE/test_results`

**Usage examples:**

```bash
# Use default location
bin/local_benchmark.sh

# Custom location
RESULTS_BASE_DIR=/tmp/my_results bin/local_benchmark.sh

# CI usage
RESULTS_BASE_DIR="${GITHUB_WORKSPACE}/test_results" bin/local_benchmark.sh --dry-run
```

## Running Tests Locally

### Prerequisite: Install ShellCheck

```bash
# Ubuntu/Debian
sudo apt-get install shellcheck

# macOS
brew install shellcheck

# Other platforms
# See: https://github.com/koalaman/shellcheck#installing
```

### Run All Checks

```bash
# ShellCheck
shopt -s globstar
shellcheck -x bin/**/*.sh bin/*.sh scripts/**/*.sh scripts/*.sh

# Bash syntax check
find . -type f -name '*.sh' -not -path './.git/*' -print0 | xargs -0 -n1 bash -n

# Smoke tests (dry-run mode)
RESULTS_BASE_DIR=/tmp/test_results bin/homelab_benchmark.sh --dry-run localhost
RESULTS_BASE_DIR=/tmp/test_results bin/local_benchmark.sh --dry-run

# Workflow validation
scripts/check-workflows.sh
```

### Using the Test Scripts

The repository includes test scripts in the `tests/` directory:

```bash
# Run smoke tests
./tests/smoke_dryrun.sh

# Run shellcheck
./tests/shellcheck.sh
```

## Workflow Files

### Active Workflows

- **ci.yml** - Main CI pipeline (runs on PRs and pushes)
- **pages.yml** - Build and deploy documentation to GitHub Pages
- **docs-linkcheck.yml** - Validate documentation links
- **update-audits.yml** - Update security audit files

### Legacy Workflows (Manual Trigger Only)

These workflows are kept for backwards compatibility but have been superseded by `ci.yml`:

- **smoke.yml** - Now only runs via workflow_dispatch
- **shellcheck.yml** - Now only runs via workflow_dispatch
- **workflow-lint.yml** - Now only runs via workflow_dispatch

## Dry-Run Mode

The benchmark scripts support a `--dry-run` flag that:
- Skips actual benchmarking operations
- Validates script logic and paths
- Tests SSH connectivity (when configured)
- Doesn't require root/sudo access
- Doesn't install tools

This mode is perfect for CI environments where you want to validate the scripts work correctly without actually running performance tests.

## Troubleshooting

### Tests fail with "Permission denied" for `/media/luis/...`

This was resolved in the refactor. If you see this error, ensure you're using the latest version of the scripts which support `RESULTS_BASE_DIR`.

### ShellCheck warnings about unused variables

Some warnings are expected and safe to ignore, particularly:
- `raw_dir` and `host` parameters in modular functions (used by callers)
- `DRY_RUN` flag (used conditionally)
- Source file warnings (SC1091) for dynamically sourced modules

### Smoke tests fail in CI

Ensure the workflow sets `RESULTS_BASE_DIR` to a writable location:
```yaml
env:
  RESULTS_BASE_DIR: ${{ github.workspace }}/test_results
```

## Contributing

When modifying shell scripts:

1. Run shellcheck locally before committing
2. Test in dry-run mode
3. Ensure bash syntax is valid
4. Update this documentation if adding new environment variables or workflows

## References

- [ShellCheck](https://www.shellcheck.net/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide/Practices)
