# GitHub Actions Workflows Quick Reference

## Active Workflows

### test.yml - Shell Test Suite ✅
**When it runs:**
- Every pull request
- Every push to main/master
- Manual trigger via Actions tab

**What it does:**
- Runs ShellCheck on all scripts (Ubuntu + macOS)
- Validates bash syntax (Ubuntu + macOS)
- Smoke tests in dry-run mode (Ubuntu + macOS)
- Validates workflow files
- Optional integration tests (push/manual only)

**Estimated time:** 3-5 minutes

**Key outputs:**
- shellcheck-results-{os}: ShellCheck analysis files
- smoke-test-logs-{os}: Test execution logs
- integration-test-results: Full benchmark results (when enabled)

---

### docs.yml - Documentation Site 📚
**When it runs:**
- Push to main/master/release branches
- Changes to docs/ directory
- Manual trigger via Actions tab

**What it does:**
- Validates documentation links
- Builds Jekyll site
- Deploys to GitHub Pages

**Estimated time:** 2-4 minutes

**Key outputs:**
- Live documentation site at GitHub Pages URL

---

### update-audits.yml - Security Audits 🔒
**When it runs:**
- Push to main/master/release branches
- Weekly on Sundays at 00:00 UTC
- Manual trigger via Actions tab

**What it does:**
- Runs shellcheck on all scripts
- Generates security audit reports
- Auto-commits audit updates

**Estimated time:** 1-2 minutes

**Key outputs:**
- SECURITY_AUDIT.md (updated)
- SECURITY_AUDIT_LOCAL.md (updated)

---

## Manual Workflow Triggers

You can manually trigger any workflow:

1. Go to the **Actions** tab
2. Select the workflow from the left sidebar
3. Click **Run workflow**
4. Select branch and click **Run workflow**

---

## Workflow Dependencies

```
Pull Request / Push
    │
    ├─→ test.yml (runs always)
    │   ├─→ shellcheck (parallel on Ubuntu + macOS)
    │   ├─→ bash-syntax (parallel on Ubuntu + macOS)
    │   ├─→ smoke-tests (depends on bash-syntax)
    │   ├─→ workflow-validation
    │   ├─→ integration-test (optional, on push)
    │   └─→ test-summary (aggregates all)
    │
    ├─→ docs.yml (only on docs/ changes)
    │   ├─→ link-check
    │   └─→ build-deploy (depends on link-check)
    │
    └─→ update-audits.yml (only on push to protected branches)
        └─→ update-audits (auto-commits)
```

---

## Troubleshooting

### ❌ Test failed - what do I check?

1. **Click on the failed job** in the Actions tab
2. **Expand the failed step** to see error details
3. **Download artifacts** if available (shellcheck results, logs)
4. **Run tests locally** following CI_TESTING.md

### ❌ ShellCheck warnings

```bash
# Fix locally before pushing
shellcheck -x bin/your-script.sh

# Or run on all scripts
shopt -s globstar
shellcheck -x bin/**/*.sh scripts/**/*.sh
```

### ❌ Smoke test failures

```bash
# Test locally with dry-run
RESULTS_BASE_DIR=/tmp/test bin/local_benchmark.sh --dry-run
RESULTS_BASE_DIR=/tmp/test bin/homelab_benchmark.sh --dry-run localhost
```

### ❌ Workflow won't trigger

Check these:
- Is your branch name correct? (main vs master)
- Did you modify the right files? (docs.yml only triggers on docs/ changes)
- Are there any YAML syntax errors? (validate locally)

### ❌ Pages deployment failed

1. Check that GitHub Pages is enabled in repo settings
2. Verify you have write permissions for Pages
3. Check Ruby/Jekyll version compatibility
4. Review the build logs for specific errors

---

## Status Badges

Add these to your README.md:

### Test Status
```markdown
![Tests](https://github.com/luis-rodriguez/homelab_bench/actions/workflows/test.yml/badge.svg)
```

### Docs Status
```markdown
![Docs](https://github.com/luis-rodriguez/homelab_bench/actions/workflows/docs.yml/badge.svg)
```

### Security Audit Status
```markdown
![Security](https://github.com/luis-rodriguez/homelab_bench/actions/workflows/update-audits.yml/badge.svg)
```

---

## Performance Tips

### Faster CI runs
- ShellCheck is cached after first run
- Ruby gems are cached for docs builds
- Use concurrency control (already enabled)
- Matrix jobs run in parallel

### Skip CI
Add `[skip ci]` to commit message to skip workflows:
```bash
git commit -m "docs: fix typo [skip ci]"
```

**Note:** Only skip CI for documentation-only changes that don't affect code!

---

## Advanced Usage

### Run specific test phase locally

```bash
# ShellCheck only
shopt -s globstar
shellcheck -x --severity=warning bin/**/*.sh scripts/**/*.sh

# Syntax check only
find . -name '*.sh' -not -path './.git/*' -exec bash -n {} \;

# Smoke tests only
RESULTS_BASE_DIR=/tmp/test bin/local_benchmark.sh --dry-run

# Workflow validation only
scripts/check-workflows.sh
```

### Debug workflow issues

1. **Enable debug logging:**
   - Add secret: `ACTIONS_STEP_DEBUG` = `true`
   - Re-run workflow

2. **Use act for local testing:**
   ```bash
   # Install act (https://github.com/nektos/act)
   act -j shellcheck  # Run specific job
   ```

3. **SSH into runner (not recommended):**
   - Add step with `action-tmate` for interactive debugging

---

## Maintenance Schedule

- **Weekly:** Security audits (automated)
- **Monthly:** Review shellcheck warnings
- **Quarterly:** Update action versions
- **As needed:** Update Ruby/Jekyll versions

---

## Resources

- [Workflow files](.github/workflows/)
- [Composite action](.github/actions/setup-shell-environment/)
- [Full documentation](CI_TESTING.md)
- [Refactoring summary](WORKFLOW_REFACTORING_SUMMARY.md)
- [GitHub Actions docs](https://docs.github.com/en/actions)
