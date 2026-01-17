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

To use this with the firefox-ios, repo, you will also need the dependencies from that repo.

## Installation

narya is available through brew.

```bash
brew tap adudenamedruby/narya
brew install narya
```

**NOTE:** installing `narya` will also install several dependencies through `brew`, that are used for functionality:

- [swiftlint](https://github.com/realm/SwiftLint)
- [danger](https://github.com/danger/swift)

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
├── narya.swift                 # Entry point (@main)
├── Core/                       # Where tools and utilities should be placed
│   ├── CommandHelpers.swift    # Shared utilities for command implementations
│   ├── Configuration.swift     # App constants (name, version, etc.)
│   ├── DeviceShorthand.swift   # Simulator shorthand pattern matching (e.g., 17pro, air13)
│   ├── Herald.swift            # Formatted output handling
│   ├── Products.swift          # Build product definitions (Firefox, Focus, Klar)
│   ├── RepoDetector.swift      # Validates firefox-ios repository, loads .narya.yaml
│   ├── ShellRunner.swift       # Shell command execution
│   ├── SimulatorManager.swift  # iOS Simulator detection and management
│   ├── StringUtils.swift       # String transformation utilities
│   └── ToolChecker.swift       # Tool availability checks (git, node, npm, xcodebuild)
└── Commands/
```

## Development & Contribution

Contributing to `narya` is easy: please fork the repo, make your changes, and submit a PR.

For a discussion of the design thoughts behind `narya`, and what to add, please first read the [GUIDELINES](https://github.com/adudenamedruby/narya/blob/main/GUIDELINES.md) document.

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

⚠️ **IMPORTANT:** Tests must be run with the `--no-parallel` flag to avoid concurrency issues. Many tests change the current working directory, which is global process state. Running tests in parallel _will_ cause cross-contamination between test suites.

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

#### `bootstrap`

Bootstraps the repository for development. By default, bootstraps the product specified in `.narya.yaml` (`default_bootstrap`), or Firefox if not configured.

#### `build`

Builds Firefox, Focus, or Klar for development using xcodebuild. By default, builds the product specified in `.narya.yaml` (`default_build_product`), or Firefox if not configured.

The simulator is auto-detected to use the latest iOS version with a standard iPhone model (non-Pro, non-Max).

Please read [Simulator Shorthand](#simulator-shorthand) for an explanation of the `--sim` flag.

#### `clean`

Cleans up various cached or generated files.

#### `lint`

Runs SwiftLint on the codebase. By default, lints only files changed compared to the main branch.

#### `nimbus`

Manages Nimbus feature flags across the firefox-ios codebase. Subcommands:

- `refresh` - Updates the include block in `nimbus.fml.yaml` with feature files from the `nimbus-features/` directory
- `add` - Creates a new feature with all required boilerplate (YAML file and Swift code)
- `remove` - Removes a feature from all locations

#### `run`

Builds and launches Firefox, Focus, or Klar in the iOS Simulator. This is equivalent to running `narya build` followed by installing and launching the app.

Please read [Simulator Shorthand](#simulator-shorthand) for an explanation of the `--sim` flag.

#### `telemetry`

Updates Glean telemetry configuration files.

#### `test`

Runs tests for Firefox, Focus, or Klar using xcodebuild. By default, runs unit tests for the product specified in `.narya.yaml` (`default_build_product`), or Firefox if not configured.

Test plans available:

- `unit` - Unit tests (default)
- `smoke` - Smoke/UI tests
- `accessibility` (or `a11y`) - Accessibility tests (Firefox only)
- `performance` (or `perf`) - Performance tests (Firefox only)
- `full` - Full functional tests (Focus/Klar only)

Please read [Simulator Shorthand](#simulator-shorthand) for an explanation of the `--sim` flag.

#### `version`

Displays or updates version numbers across the repository. Without options, shows the current version and git SHA.

### Simulator Shorthands

The `--sim` option in `build`, `run`, and `test` subcommands accepts either a shorthand code or the full simulator name (e.g., `--sim 17pro` or `--sim "iPhone 17 Pro"`). Use the `list-sims` subcommand to see available simulators on your current machine and their respective shorthands. The shorthands generally follow a simple pattern for devices, as outlined below:

#### Design Principles for Shorthand Patterns

1. Shorthands must be derivable - A user should be able to guess the shorthand from the device name
2. No shorthand is OK - Devices that don't fit the pattern get "-" and require the full name
3. Bidirectional consistency - parseShorthand() and shorthand(for:) use the same rules

In general, these are the shorthand rules:
Shorthand Rules

iPhone:
┌─────────┬──────────┬─────────────────────────────┐
│ Pattern │ Examples │ Matches │
├─────────┼──────────┼─────────────────────────────┤
│ <N> │ 17 │ iPhone 17 (base model only) │
├─────────┼──────────┼─────────────────────────────┤
│ <N>pro │ 17pro │ iPhone 17 Pro │
├─────────┼──────────┼─────────────────────────────┤
│ <N>max │ 17max │ iPhone 17 Pro Max │
├─────────┼──────────┼─────────────────────────────┤
│ <N>plus │ 17plus │ iPhone 17 Plus │
├─────────┼──────────┼─────────────────────────────┤
│ <N>e │ 16e │ iPhone 16e │
├─────────┼──────────┼─────────────────────────────┤
│ se │ se │ iPhone SE (any generation) │
├─────────┼──────────┼─────────────────────────────┤
│ air │ air │ iPhone Air │
└─────────┴──────────┴─────────────────────────────┘
iPad:
┌─────────────┬──────────────────────┬────────────────────────────────────────────────┐
│ Pattern │ Examples │ Matches │
├─────────────┼──────────────────────┼────────────────────────────────────────────────┤
│ air<size> │ air11, air13 │ iPad Air 11/13-inch (13 also matches 12.9) │
├─────────────┼──────────────────────┼────────────────────────────────────────────────┤
│ pro<size> │ pro11, pro13, pro129 │ iPad Pro (13 matches 12.9 too; 129 is precise) │
├─────────────┼──────────────────────┼────────────────────────────────────────────────┤
│ mini │ mini │ iPad mini (any) │
├─────────────┼──────────────────────┼────────────────────────────────────────────────┤
│ mini<N>g │ mini6g, mini7g │ iPad mini (Nth generation) │
├─────────────┼──────────────────────┼────────────────────────────────────────────────┤
│ miniA<chip> │ miniA17 │ iPad mini (A17 Pro) │
├─────────────┼──────────────────────┼────────────────────────────────────────────────┤
│ pad<N>g │ pad10g │ iPad (Nth generation) │
├─────────────┼──────────────────────┼────────────────────────────────────────────────┤
│ padA<chip> │ padA16 │ iPad (A16) │
└─────────────┴──────────────────────┴────────────────────────────────────────────────┘
Matching behavior:

- pro13 matches both "13-inch" and "12.9-inch", but prefers exact match if both exist
- pro129 matches only "12.9-inch" (precise)
- Devices that don't fit patterns get "-" → user must use full name

## License

Mozilla Public License 2.0
