# 💍 narya

A CLI tool for managing tasks in the [firefox-ios](https://github.com/mozilla-mobile/firefox-ios) repository.

Named after Narya, the Ring of Fire — one of the Three Rings of the Elves in Tolkien's legendarium.

## Requirements

- macOS 13+
- Swift 6.0+
- git
- Node.js and npm

## Installation

narya is available through brew.

Installation instructions to follow once the tap exists

## Commands

| Command | Description |
|---------|-------------|
| `narya setup` | Clone and bootstrap the firefox-ios repository |
| `narya bootstrap` | Bootstrap the repository for Firefox or Focus development |
| `narya clean` | Clean up cached or generated files |
| `narya telemetry` | Update telemetry configuration files |
| `narya update version` | Update version numbers across the repository |

### bootstrap

Bootstraps the repository for development. By default, bootstraps the product specified in `.narya.yaml` (`default_bootstrap`), or Firefox if not configured.

```bash
narya bootstrap              # Bootstrap default product
narya bootstrap -p firefox   # Bootstrap Firefox
narya bootstrap -p focus     # Bootstrap Focus
narya bootstrap --all        # Bootstrap both
narya bootstrap --force      # Force rebuild (Firefox only)
```

### clean

Cleans up various cached or generated files.

```bash
narya clean -p              # Reset and resolve Swift packages
narya clean -b              # Delete .build directory
narya clean -d              # Delete DerivedData
narya clean --all           # Clean everything
```

### telemetry

Updates Glean telemetry configuration files.

```bash
narya telemetry --update                      # Refresh index files
narya telemetry --add newFeature              # Add new metrics YAML
narya telemetry --add newFeature --description "Description"
```

### update version

Updates version numbers across the repository.

```bash
narya update version --major   # 145.6 -> 146.0
narya update version --minor   # 145.6 -> 145.7
```

## Configuration

narya uses a `.narya.yaml` file in the repository root for configuration.

```yaml
# Required: identifies this as a narya-compatible repository
project: firefox-ios

# Optional: default product for bootstrap command (firefox or focus)
default_bootstrap: firefox
```

| Field | Required | Description |
|-------|----------|-------------|
| `project` | Yes | Must be `firefox-ios` |
| `default_bootstrap` | No | Default product for `narya bootstrap` (`firefox` or `focus`) |

## Output Format

All narya output is prefixed with emoji indicators:

| Prefix | Meaning |
|--------|---------|
| 💍 | Regular status messages |
| 💥💍 | Errors or warnings |

## Architecture

```
Sources/narya/
├── narya.swift              # Entry point (@main)
├── Core/
│   ├── Configuration.swift  # App constants (name, version, etc.)
│   ├── RepoDetector.swift   # Validates firefox-ios repository, loads .narya.yaml
│   ├── ShellRunner.swift    # Shell command execution
│   └── ToolChecker.swift    # Tool availability checks (git, node, npm)
└── Commands/
    ├── Bootstrap.swift      # Bootstrap Firefox/Focus for development
    ├── Clean.swift          # Clean build artifacts and caches
    ├── Setup.swift          # Clone + bootstrap command
    ├── Telemetry.swift      # Update Glean telemetry config files
    ├── Update.swift         # Parent command for update subcommands
    └── Version.swift        # Update version numbers
```

## Development

To work on narya:

```bash
# Clone this repository
git clone https://github.com/anthropics/narya.git
cd narya

# Build
swift build

# Run tests
swift test

# Run locally
swift run narya
```

## License

Mozilla Public License 2.0
