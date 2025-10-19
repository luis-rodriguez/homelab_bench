# Release v1.0.0
```markdown
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

## Release v1.1

Planned items for v1.1

- Bump automated audit updater to v1.1, include git short SHA in audit headers.
- Regenerate audit files and prepare `release/v1.1` branch.
- Ensure CI workflow will auto-commit audit updates on push.


## Release v1.4

This release standardizes the GitHub Pages deployment to the official upload+deploy flow and removes duplicate workflow files.

What's included

- Remove duplicate Pages workflow `.github/workflows/pages.yml` and keep `jekyll-gh-pages.yml` as the canonical workflow.
- Use `actions/upload-pages-artifact@v2` + `actions/deploy-pages@v1` for official GitHub Pages deployment.
- Ensure Jekyll build uses the `docs/` directory as the site source and uploads `./_site` explicitly.

Notes

- This is a non-functional change (CI/workflow cleanup). It standardizes action versions to avoid transitive deprecated-action failures in CI and makes the Pages workflow easier to maintain.
- After merging, a Pages workflow run should be triggered on the default branch to validate the deploy step.

Changelog

- Deleted duplicate workflow and canonicalized `jekyll-gh-pages.yml` to the official Pages actions.

``` 

