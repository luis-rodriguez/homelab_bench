---
layout: default
title: Contributing
---

# Contributing

If you want to improve the benchmarking scripts or documentation:

1. Fork the repository and create a feature branch.
2. Add tests (the repo uses simple shell smoke tests in `tests/`).
3. Open a Pull Request describing your changes and include rationale and testing notes.

Style

- Prefer small, single-purpose shell files under `bin/local/` and `bin/remote/`.
- Keep destructive operations optional and gated behind `--dry-run` or explicit flags.
