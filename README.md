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
