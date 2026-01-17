# 💍 narya

A CLI tool for managing tasks in the [firefox-ios](https://github.com/mozilla-mobile/firefox-ios) repository.

Named after Narya, the Ring of Fire, and one of the three Rings of the Elves, forged by Celebrimbor of the Gwaith-i-Mírdain, and later borne by Gandalf.

## Goals

The goals of this tool are simple:

1. Provide easily reproducible commands for all developers & CI
2. Provide a central place for important utilities used to manage the firefox-ios repo
3. Provide a thoroughly documented, understandable experience that will reduce tribal knowledge
4. Provide a simple, indirect way for new developers to discover tooling used in Swift development

Bonus/most important goal: be dope by being ridiculouly helpful

If a command doesn't materially achieve one of these goals & the bonus goal, it likely shouldn't be part of `narya`

## Requirements

- macOS 14+
- Swift 6.0+

To test on firefox-ios, you will also need the dependencies from that repo.

## Installation

narya is available through brew.

```bash
brew tap adudenamedruby/narya
brew install narya
```

**NOTE:** installing `narya` will also install several dependencies through `brew`, that are used for functionality:

- (swiftlint)[https://github.com/realm/SwiftLint]
- (danger)[https://github.com/danger/swift]

## Configuration

narya uses a `.narya.yaml` file in the repository root for configuration and validation that it's in the correct repository

```yaml
# Required: identifies this as a narya-compatible repository
project: firefox-ios

# Optional: default product for bootstrap command (firefox or focus)
default_bootstrap: firefox

# Optional: default product for build/run commands (firefox, focus, or klar)
default_build_product: firefox
```

## Architecture

```
Sources/narya/
├── narya.swift               # Entry point (@main)
├── Core/                     # Where tools and utilities should be placed
│   ├── Configuration.swift   # App constants (name, version, etc.)
│   ├── Herald.swift          # Formatted output handling
│   ├── RepoDetector.swift    # Validates firefox-ios repository, loads .narya.yaml
│   ├── ShellRunner.swift     # Shell command execution
│   ├── SimulatorManager.swift # iOS Simulator detection and management
│   └── ToolChecker.swift     # Tool availability checks (git, node, npm, xcodebuild)
└── Commands/
    ├── Bootstrap.swift       # Bootstrap Firefox/Focus for development
    ├── Build.swift           # Build Firefox/Focus/Klar with xcodebuild
    ├── Clean.swift           # Clean build artifacts and caches
    ├── Lint.swift            # Run SwiftLint on the codebase
    ├── Nimbus.swift          # Manage Nimbus feature config files
    ├── Run.swift             # Build and launch in iOS Simulator
    ├── Setup.swift           # Clone + bootstrap command
    ├── Telemetry.swift       # Update Glean telemetry config files
    ├── Test.swift            # Run tests with xcodebuild
    └── Version.swift         # Display or update version numbers
```

## Development & Contribution

Contributing to `narya` is easy: please fork the repo, make your changes, and submit a PR.

For a discussion of the design thoughts behind `narya`, and what to add, please first read the (GUIDELINES)[https://github.com/adudenamedruby/narya/blob/main/GUIDELINES.md] document.

### Dev Notes

```bash
# Build
swift build

# Run locally
swift run narya
```

### Testing Notes

Tests use Swift Testing framework (`@Test`, `@Suite`, `#expect`).

```bash
# Run all tests (must use --no-parallel)
swift test --no-parallel
```

**Important:** Tests must be run with `--no-parallel` to avoid concurrency issues. Many tests change the current working directory, which is global process state. Running tests in parallel can cause cross-contamination between test suites.

Any new feature or command must include corresponding tests. Tests should cover:

- Command configuration (abstract, discussion text)
- Flag/option validation
- Expected behavior with valid inputs
- Error handling for invalid inputs
- Edge cases

See existing test files in `Tests/naryaTests/` for examples.

### Outputting Status from `narya`

All narya output is handled by the `Herald`. The maintain clarity between `narya`'s output and the output of tools/commands it wraps, we have a standard way of presenting output. The beginning of every action block from `narya` is preceeded by a 💍 and intedent afterwards. To maintain this format, always `reset()` the `Herald` before beginning a new action.

| Function  | Meaning                           |
| --------- | --------------------------------- |
| reset()   | Begin a new block to output.      |
| declare() | Used to output a regular block    |
| warn()    | Used to output errors or warnings |

## Currently Supported Commands

| Command           | Description                                               |
| ----------------- | --------------------------------------------------------- |
| `narya bootstrap` | Bootstrap the repository for Firefox or Focus development |
| `narya build`     | Build Firefox, Focus, or Klar for development             |
| `narya clean`     | Clean up cached or generated files                        |
| `narya lint`      | Run SwiftLint on the codebase                             |
| `narya nimbus`    | Manage Nimbus feature configuration files                 |
| `narya run`       | Build and launch in the iOS Simulator                     |
| `narya setup`     | Clone and bootstrap the firefox-ios repository            |
| `narya telemetry` | Update telemetry configuration files                      |
| `narya test`      | Run tests for Firefox, Focus, or Klar                     |
| `narya version`   | Display or update version numbers across the repository   |

### build

Builds Firefox, Focus, or Klar for development using xcodebuild. By default, builds the product specified in `.narya.yaml` (`default_build_product`), or Firefox if not configured.

The simulator is auto-detected to use the latest iOS version with a standard iPhone model (non-Pro, non-Max).

```bash
narya build                         # Build Firefox for simulator
narya build -p focus                # Build Focus for simulator
narya build -p klar                 # Build Klar for simulator
narya build --for-testing           # Build for testing (generates xctestrun)
narya build --device                # Build for connected device
narya build --simulator "iPhone 16 Pro"  # Use specific simulator
narya build --configuration Fennec_Testing
narya build --clean                 # Clean before building
narya build --skip-resolve          # Skip SPM package resolution
narya build -q                      # Quiet mode (minimal output)
narya build --list-simulators       # Show available simulators
narya build --expose                # Print xcodebuild command without running
```

### run

Builds and launches Firefox, Focus, or Klar in the iOS Simulator. This is equivalent to running `narya build` followed by installing and launching the app.

```bash
narya run                           # Build and run Firefox
narya run -p focus                  # Build and run Focus
narya run --simulator "iPhone 16 Pro"
narya run --clean                   # Clean before building
narya run -q                        # Quiet mode
narya run --expose                  # Print commands without running
```

### test

Runs tests for Firefox, Focus, or Klar using xcodebuild. By default, runs unit tests for the product specified in `.narya.yaml` (`default_build_product`), or Firefox if not configured.

Test plans available:

- `unit` - Unit tests (default)
- `smoke` - Smoke/UI tests
- `accessibility` - Accessibility tests (Firefox only)
- `performance` - Performance tests (Firefox only)
- `full` - Full functional tests (Focus/Klar only)

```bash
narya test                          # Run unit tests for Firefox
narya test -p focus                 # Run unit tests for Focus
narya test --plan smoke             # Run smoke tests
narya test --build-first            # Build for testing, then run tests
narya test --filter "TabTests"      # Run tests matching filter
narya test --retries 2              # Retry failed tests up to 2 times
narya test --simulator "iPhone 16 Pro"
narya test -q                       # Quiet mode
narya test --expose                 # Print xcodebuild command without running
```

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

### nimbus

Manages Nimbus feature configuration files. Updates the `include` block in `nimbus.fml.yaml` with feature files from the `nimbus-features/` directory.

```bash
narya nimbus --refresh             # Refresh nimbus.fml.yaml include block
narya nimbus --add newFeature      # Add new feature YAML (appends "Feature" if needed)
```

### telemetry

Updates Glean telemetry configuration files.

```bash
narya telemetry --refresh                     # Refresh index files
narya telemetry --add newFeature              # Add new metrics YAML
narya telemetry --add newFeature --description "Description"
```

### version

Displays or updates version numbers across the repository. Without options, shows the current version and git SHA.

```bash
narya version                     # Show current version and git SHA
narya version --bump major        # 145.6 -> 146.0
narya version --bump minor        # 145.6 -> 145.7
narya version --set 123.4         # Explicitly set version
narya version --verify            # Check version consistency across files
```

### lint

Runs SwiftLint on the codebase. By default, lints only files changed compared to the main branch.

```bash
narya lint                        # Lint changed files in firefox-ios
narya lint -p focus               # Lint changed files in focus-ios
narya lint --all                  # Lint entire project
narya lint --changed              # Lint only changed files (default)
narya lint --strict               # Treat warnings as errors
narya lint -q                     # Quiet mode (show only counts)
narya lint --fix                  # Auto-correct fixable violations
narya lint --fix --changed        # Fix only changed files
narya lint info                   # Show SwiftLint version and rules
```

## License

Mozilla Public License 2.0
