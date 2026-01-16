# 💍narya

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

### `setup`

Clone and bootstrap the firefox-ios repository in one step. Automatically bootstraps Firefox after cloning.

```bash
narya setup                        # Clone via HTTPS + bootstrap Firefox
narya setup --ssh                  # Clone via SSH + bootstrap Firefox
narya setup --location ~/code/ff   # Clone to custom location + bootstrap Firefox
```

**Options:**

- `--ssh` — Use SSH URL for cloning instead of HTTPS
- `--location <path>` — Directory path (absolute or relative) to clone into

### `bootstrap`

Bootstrap an existing firefox-ios repository for development. Must be run from within the repository.

The `-p` flag is required to specify which product to bootstrap. Running `narya bootstrap` without `-p` will display help.

```bash
narya bootstrap                    # Show help
narya bootstrap -p firefox         # Bootstrap Firefox
narya bootstrap -p focus           # Bootstrap Focus
narya bootstrap -p firefox --force # Force re-build (deletes build directory)
```

**Options:**

- `-p, --product <firefox|focus>` — Product to bootstrap (required)
- `--force` — Force re-build by deleting the build directory (Firefox only)

**What bootstrap does:**

For Firefox:

- Removes `.venv` directories
- Downloads and runs Nimbus FML bootstrap script
- Installs git hooks from `.githooks/`
- Runs `npm install` and `npm run build`

For Focus:

- Downloads and runs Nimbus FML bootstrap script
- Clones shavar-prod-lists repository
- Builds BrowserKit

## Architecture

```
Sources/narya/
├── narya.swift              # Entry point (@main)
├── Core/
│   ├── Configuration.swift  # App constants (name, version, etc.)
│   ├── RepoDetector.swift   # Validates firefox-ios repository
│   ├── ShellRunner.swift    # Shell command execution
│   └── ToolChecker.swift    # Tool availability checks (git, node, npm)
└── Commands/
    ├── Setup.swift          # Clone + bootstrap command
    └── Bootstrap.swift      # Bootstrap command
```

## Development

To work on narya

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
