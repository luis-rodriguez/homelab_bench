# CI/CD and Testing Documentation

## Overview

This repository uses GitHub Actions for continuous integration and testing. The workflows are designed to validate code quality, syntax, and functionality without requiring actual hardware or SSH access.

## Workflow Architecture

The CI/CD system is organized into three main workflows:

### 1. Test Suite (`.github/workflows/test.yml`)

The comprehensive testing workflow that runs on all pull requests and pushes to `main`/`master` branches.

**Phases:**
1. **Code Quality & Static Analysis**
   - ShellCheck (Ubuntu + macOS matrix)
   - Bash syntax validation (Ubuntu + macOS matrix)

2. **Functional Tests**
   - Smoke tests with dry-run mode (Ubuntu + macOS matrix)
   - Results directory validation

3. **Workflow Validation**
   - Deprecated action detection
   - YAML syntax validation

4. **Integration Tests** (optional, push/manual only)
   - Full benchmark run with real tools
   - End-to-end pipeline validation

5. **Test Summary**
   - Aggregates all test results
   - Provides clear pass/fail status

### 2. Documentation Site (`.github/workflows/docs.yml`)

Builds and deploys the Jekyll documentation site to GitHub Pages.

**Features:**
- Link validation with html-proofer
- Gem caching for faster builds
- Automated deployment on docs changes

### 3. Security Audits (`.github/workflows/update-audits.yml`)

Automated security scanning and audit generation.

**Features:**
- Runs ShellCheck on all scripts
- Generates security audit reports
- Auto-commits updates (on push/schedule)
- Weekly scheduled runs

## Environment Variables

### RESULTS_BASE_DIR

The benchmark scripts support the `RESULTS_BASE_DIR` environment variable to override the default results directory.

**Default behavior:**
- Local usage: `$HOME/homelab_bench_results`
- CI environment: `$GITHUB_WORKSPACE/test_results`

**Usage examples:**

```bash
# Use default location
bin/local_benchmark.sh

# Custom location
RESULTS_BASE_DIR=/tmp/my_results bin/local_benchmark.sh

# CI usage (automatically set in workflows)
RESULTS_BASE_DIR="${GITHUB_WORKSPACE}/test_results" bin/local_benchmark.sh --dry-run
```

### CI-Specific Variables

The test workflow sets these environment variables:
- `RESULTS_BASE_DIR`: Test results location
- `DEBIAN_FRONTEND=noninteractive`: Prevent interactive prompts
- `TERM=dumb`: Disable terminal features in CI

## Reusable Components

### Composite Action: setup-shell-environment

Located at `.github/actions/setup-shell-environment/action.yml`

**Purpose:** Standardizes shell environment setup across all workflows

**Features:**
- Installs shellcheck (with caching on supported platforms)
- Makes scripts executable
- Cross-platform compatible (Ubuntu + macOS)

**Usage:**
```yaml
- name: Setup shell environment
  uses: ./.github/actions/setup-shell-environment
  with:
    install-shellcheck: 'true'
    make-executable: 'true'
```

## Running Tests Locally

### Prerequisites

#### Install ShellCheck

```bash
# Ubuntu/Debian
sudo apt-get install shellcheck

# macOS
brew install shellcheck

# Other platforms
# See: https://github.com/koalaman/shellcheck#installing
```

### Run Individual Test Phases

#### 1. Code Quality

```bash
# ShellCheck (static analysis)
shopt -s globstar
shellcheck -x --severity=warning \
  bin/**/*.sh bin/*.sh \
  scripts/**/*.sh scripts/*.sh \
  tests/**/*.sh tests/*.sh

# Bash syntax check
find . -type f -name '*.sh' -not -path './.git/*' -print0 | \
  xargs -0 -n1 bash -n
```

#### 2. Functional Tests

```bash
# Smoke tests (dry-run mode)
RESULTS_BASE_DIR=/tmp/test_results bin/homelab_benchmark.sh --dry-run localhost
RESULTS_BASE_DIR=/tmp/test_results bin/local_benchmark.sh --dry-run
```

#### 3. Workflow Validation

```bash
# Check for deprecated actions
scripts/check-workflows.sh

# Validate YAML syntax (requires Python with PyYAML)
python3 -c "import yaml; [yaml.safe_load(open(f)) for f in \
  __import__('glob').glob('.github/workflows/*.yml')]"
```

### Using the Test Scripts

The repository includes convenience test scripts in the `tests/` directory:

```bash
# Run smoke tests
./tests/smoke_dryrun.sh

# Run shellcheck
./tests/shellcheck.sh
```

## Matrix Testing

The test workflow runs on multiple platforms:
- **ubuntu-latest**: Primary Linux testing environment
- **macos-latest**: macOS compatibility validation

This ensures scripts work across different operating systems and shell implementations.

## Artifact Uploads

Test workflows upload artifacts for debugging:
- **shellcheck-results-{os}**: ShellCheck output files
- **smoke-test-logs-{os}**: Dry-run test logs
- **integration-test-results**: Full benchmark results (when enabled)

Artifacts are retained for 7 days and can be downloaded from the Actions tab.

## Workflow Files

### Active Workflows

#### test.yml (Main Test Suite)
**Triggers:** Pull requests, pushes to main/master, manual dispatch

**Jobs:**
- shellcheck: Static analysis (Ubuntu + macOS)
- bash-syntax: Syntax validation (Ubuntu + macOS)
- smoke-tests: Dry-run functional tests (Ubuntu + macOS)
- workflow-validation: Checks for deprecated actions and YAML validity
- integration-test: Optional full benchmark run (push/manual only)
- test-summary: Aggregates results and determines pass/fail

**Features:**
- Matrix builds for cross-platform testing
- Fail-fast disabled for comprehensive results
- Artifact uploads for debugging
- Concurrency control to cancel outdated runs

#### docs.yml (Documentation Site)
**Triggers:** Pushes to main/master/release branches, changes to docs/, manual dispatch

**Jobs:**
- link-check: Validates documentation links with html-proofer
- build-deploy: Builds Jekyll site and deploys to GitHub Pages

**Features:**
- Ruby gem caching for faster builds
- Automated link validation
- GitHub Pages deployment with proper permissions

#### update-audits.yml (Security Audits)
**Triggers:** Pushes to main/master/release, manual dispatch, weekly schedule

**Jobs:**
- update-audits: Runs shellcheck and generates audit reports

**Features:**
- Auto-commits audit updates with [skip ci]
- Scheduled weekly runs
- Comprehensive shellcheck analysis

### Concurrency Control

Workflows use concurrency groups to prevent redundant runs:
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

This automatically cancels outdated workflow runs when new commits are pushed.

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

Ensure the workflow sets `RESULTS_BASE_DIR` to a writable location. The new test.yml workflow handles this automatically.

### Workflow not triggering

Check the trigger conditions in the workflow file:
- **test.yml**: Runs on PRs and pushes to main/master
- **docs.yml**: Only runs on changes to docs/ or workflow files
- **update-audits.yml**: Runs on push, manual trigger, or weekly schedule

### macOS tests timing out

macOS runners are sometimes slower. The workflows include appropriate timeouts and the shellcheck step includes caching to improve performance.

## Performance Optimizations

The refactored workflows include several optimizations:

1. **Caching:**
   - ShellCheck binaries (on supported platforms)
   - Ruby gems for Jekyll builds
   - Reduces installation time on subsequent runs

2. **Parallel Execution:**
   - Matrix builds run concurrently
   - Independent test phases execute in parallel
   - Significant reduction in total pipeline time

3. **Conditional Steps:**
   - Integration tests only run on push/manual trigger
   - Link checking only on documentation changes
   - Reduces unnecessary work on PRs

4. **Concurrency Control:**
   - Cancels outdated workflow runs
   - Prevents resource waste on superseded commits

## Best Practices

### For Contributors

When modifying shell scripts:

1. **Before committing:**
   ```bash
   # Make scripts executable
   chmod +x path/to/script.sh
   
   # Run shellcheck locally
   shellcheck -x path/to/script.sh
   
   # Test in dry-run mode
   RESULTS_BASE_DIR=/tmp/test bin/local_benchmark.sh --dry-run
   ```

2. **Testing changes:**
   - Always run tests locally before pushing
   - Check the Actions tab after pushing to verify CI passes
   - Review shellcheck artifacts if tests fail

3. **Updating workflows:**
   - Validate YAML syntax before committing
   - Test changes with workflow_dispatch before merging
   - Update this documentation if adding new features

### For Maintainers

1. **Monitoring:**
   - Check weekly security audit updates
   - Review shellcheck results for new warnings
   - Monitor workflow performance metrics

2. **Maintenance:**
   - Update action versions when security advisories are released
   - Review and address shellcheck warnings periodically
   - Keep Ruby gems and dependencies updated

3. **Troubleshooting:**
   - Download and review test artifacts for failures
   - Use workflow_dispatch to manually trigger specific tests
   - Check concurrency settings if workflows aren't canceling properly

## Contributing

When modifying workflows or scripts, follow these guidelines:

1. **Make minimal changes** - Only modify what's necessary
2. **Test locally first** - Run shellcheck and syntax checks
3. **Use the composite action** - Reuse setup-shell-environment when possible
4. **Update documentation** - Keep CI_TESTING.md in sync with workflow changes
5. **Review artifacts** - Check uploaded logs for unexpected issues

## Future Improvements

Potential enhancements for the CI/CD system:

### Short-term
- [ ] Add shellcheck configuration file (.shellcheckrc) for project-wide rules
- [ ] Create badge/shield images for README showing test status
- [ ] Add code coverage tracking for shell scripts (shcov/kcov)
- [ ] Implement automated dependency updates (Dependabot)

### Medium-term
- [ ] Container-based testing with Docker
- [ ] Self-hosted runners for faster execution
- [ ] Automated performance regression testing
- [ ] Integration with external security scanning tools

### Long-term
- [ ] Multi-arch testing (ARM, x86_64)
- [ ] Automated release management
- [ ] Benchmark result comparison across commits
- [ ] Historical performance tracking and visualization

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [ShellCheck](https://www.shellcheck.net/)
- [Bash Best Practices](https://mywiki.wooledge.org/BashGuide/Practices)
- [Jekyll Documentation](https://jekyllrb.com/docs/)
- [GitHub Pages Actions](https://github.com/actions/deploy-pages)
