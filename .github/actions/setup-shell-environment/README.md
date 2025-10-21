# Setup Shell Environment Action

A reusable composite action that sets up a consistent shell testing environment across workflows.

## Features

- Installs shellcheck with caching for improved performance
- Makes shell scripts executable
- Cross-platform compatible (Ubuntu, macOS)
- Configurable inputs for flexibility

## Usage

```yaml
- name: Setup shell environment
  uses: ./.github/actions/setup-shell-environment
  with:
    install-shellcheck: 'true'  # Optional, default: true
    make-executable: 'true'     # Optional, default: true
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `install-shellcheck` | Whether to install shellcheck | No | `true` |
| `make-executable` | Whether to make bin/ scripts executable | No | `true` |

## Examples

### Full setup (default)
```yaml
- name: Setup shell environment
  uses: ./.github/actions/setup-shell-environment
```

### Only install shellcheck
```yaml
- name: Setup shell environment
  uses: ./.github/actions/setup-shell-environment
  with:
    install-shellcheck: 'true'
    make-executable: 'false'
```

### Only make scripts executable
```yaml
- name: Setup shell environment
  uses: ./.github/actions/setup-shell-environment
  with:
    install-shellcheck: 'false'
    make-executable: 'true'
```

## Platform Support

- ✅ Ubuntu (apt-get)
- ✅ macOS (Homebrew)
- ⚠️ Windows (not tested)

## Caching

ShellCheck binaries are cached by OS and architecture for faster subsequent runs.

Cache key: `${{ runner.os }}-shellcheck-${{ runner.arch }}`

## License

Same as the parent repository.
