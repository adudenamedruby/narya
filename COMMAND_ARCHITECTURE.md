# Command Architecture

This document describes the architecture and patterns used for implementing commands in `narya`. It's intended for contributors adding new commands or modifying existing ones.

## Overview

`narya` uses Apple's [Swift ArgumentParser](https://github.com/apple/swift-argument-parser) framework for command-line parsing. The main entry point is `Sources/narya/narya.swift`, which defines the root `Narya` command and registers all subcommands.

## Command Patterns

### Simple Commands

Simple commands have no subcommands and are implemented in a single file.

**Examples:** `Doctor`, `Bootstrap`, `Clean`, `Setup`, `Telemetry`, `Version`

```swift
struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check your development environment for required tools and configuration."
    )

    mutating func run() throws {
        // Implementation
    }
}
```

**File location:** `Sources/narya/Commands/Doctor.swift`

### Commands with Subcommands

Commands with subcommands use a parent struct that defines the subcommand hierarchy. The parent typically has no `run()` method of its own.

**Examples:** `Lint`, `L10n`, `Nimbus`

```swift
struct Lint: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Run SwiftLint on the codebase.",
        discussion: """
            By default, lints the entire codebase. ...
            """,
        subcommands: [Run.self, Fix.self, Info.self],
        defaultSubcommand: nil
    )
}
```

Subcommands are implemented as extensions or separate structs:

```swift
extension Lint {
    struct Run: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "run",
            abstract: "Run SwiftLint to check for violations (default)."
        )

        mutating func run() throws {
            // Implementation
        }
    }
}
```

**File organization:**

```
Commands/
└── Lint/
    ├── Lint.swift           # Parent command
    ├── LintRun.swift        # 'run' subcommand
    ├── LintFix.swift        # 'fix' subcommand
    ├── LintInfo.swift       # 'info' subcommand
    └── LintHelpers.swift    # Shared utilities for lint commands
```

### Shared Subcommands

Some subcommands are reused across multiple parent commands. These are defined in `CommandHelpers.swift`.

**Example:** `ListSims` is used by `Build`, `Run`, and `Test`:

```swift
struct ListSims: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-sims",
        abstract: "List available simulators and their shorthand codes."
    )

    func run() throws {
        try CommandHelpers.printSimulatorList()
    }
}
```

Parent commands include it in their subcommands array:

```swift
static let configuration = CommandConfiguration(
    commandName: "build",
    subcommands: [ListSims.self],
    // ...
)
```

## Standard Command Flow

Most commands follow this pattern in their `run()` method:

```swift
mutating func run() throws {
    // 1. Validate repository context (if needed)
    let repo = try RepoDetector.requireValidRepo()

    // 2. Check required tools
    try ToolChecker.requireXcodebuild()
    try ToolChecker.requireSimctl()

    // 3. Resolve options from flags or config defaults
    let product = CommandHelpers.resolveProduct(explicit: product, config: repo.config)
    let simulator = try CommandHelpers.resolveSimulator(shorthand: sim, osVersion: os)

    // 4. Handle --expose flag (print commands instead of running)
    if expose {
        printExposedCommands(...)
        return
    }

    // 5. Announce command start
    Herald.declare("Building \(product.scheme)...", isNewCommand: true)

    // 6. Perform the work
    try performBuild(...)

    // 7. Announce completion
    Herald.declare("Build succeeded!", asConclusion: true)
}
```

### Key Points

- **Repository validation:** Most commands that operate on firefox-ios call `RepoDetector.requireValidRepo()` first. This validates the `.narya.yaml` config file exists and returns the repo root and merged configuration.

- **Tool checking:** Use `ToolChecker.require___()` methods to validate required tools are available before attempting to use them.

- **Option resolution:** Use `CommandHelpers` to resolve options that may come from command-line flags or config defaults.

- **Herald for output:** All user-facing output goes through `Herald.declare()` for consistent formatting. Use `isNewCommand: true` at the start and `asConclusion: true` at the end.

## Common Flags and Options

### Standard Flags

| Flag             | Purpose                                      | Implementation                                           |
| ---------------- | -------------------------------------------- | -------------------------------------------------------- |
| `--expose`       | Print shell commands instead of running them | Use `Herald.raw()` with `CommandHelpers.formatCommand()` |
| `--quiet` / `-q` | Minimize output (errors and summary only)    | Check flag before `Herald.declare()` calls               |
| `--debug`        | Enable detailed logging                      | Handled globally in `narya.swift`                        |

### Product Selection

Commands that operate on Firefox/Focus/Klar typically include:

```swift
@Option(name: [.short, .long], help: "Product to build")
var product: BuildProduct?
```

Resolution uses config defaults:

```swift
let buildProduct = CommandHelpers.resolveProduct(explicit: product, config: repo.config)
```

### Simulator Selection

Commands that run on simulators include:

```swift
@Option(name: .long, help: "Simulator shorthand or name (e.g., 17pro, \"iPhone 17 Pro\").")
var sim: String?

@Option(name: .long, help: "iOS version for simulator (default: latest).")
var os: String?
```

Resolution handles shorthands and defaults:

```swift
let simulator = try CommandHelpers.resolveSimulator(shorthand: sim, osVersion: os)
```

## Error Handling

### Custom Error Types

Each command or command group defines its own error enum:

```swift
enum BuildError: Error, CustomStringConvertible {
    case projectNotFound(String)
    case buildFailed(exitCode: Int32)

    var description: String {
        switch self {
        case .projectNotFound(let path):
            return "Project not found at \(path). Run 'narya setup' first."
        case .buildFailed(let exitCode):
            return "Build failed with exit code \(exitCode)."
        }
    }
}
```

### Error Handling Patterns

1. **Wrap underlying errors:** When catching and re-throwing, include context:

   ```swift
   catch let error as ShellRunnerError {
       if case .commandFailed(_, let exitCode) = error {
           throw BuildError.buildFailed(exitCode: exitCode)
       }
       throw error
   }
   ```

2. **Never silently swallow errors:** Either report via Herald or re-throw.

3. **Use Logger for debug details:**
   ```swift
   Logger.error("Command failed", error: error)
   ```

See [ERROR_HANDLING.md](ERROR_HANDLING.md) for complete guidelines.

## Implementing the `--expose` Flag

The `--expose` flag prints the underlying shell commands instead of running them. This helps users understand what `narya` does and allows them to run commands manually.

```swift
@Flag(name: .long, help: "Print the xcodebuild command instead of running it.")
var expose = false

// In run():
if expose {
    printExposedCommands(...)
    return
}

// Implementation:
private func printExposedCommands(...) {
    Herald.raw("# Resolve Swift Package dependencies")
    Herald.raw(CommandHelpers.formatCommand("xcodebuild", arguments: resolveArgs))
    Herald.raw("")
    Herald.raw("# Build \(product.scheme)")
    Herald.raw(CommandHelpers.formatCommand("xcodebuild", arguments: buildArgs))
}
```

Use `Herald.raw()` (not `Herald.declare()`) for exposed commands to avoid prefix formatting.

## Core Utilities

### RepoDetector

Validates the current directory is within a firefox-ios repository and loads configuration:

```swift
let repo = try RepoDetector.requireValidRepo()
// repo.root - URL to repository root
// repo.config - MergedConfig with defaults applied
```

### ToolChecker

Validates required tools are available:

```swift
try ToolChecker.requireGit()
try ToolChecker.requireNode()
try ToolChecker.requireNpm()
try ToolChecker.requireXcodebuild()
try ToolChecker.requireSimctl()
try ToolChecker.requireSwiftlint()  // For optional tools, check availability instead
```

### CommandHelpers

Shared utilities for command implementations:

- `formatCommand(_:arguments:)` - Format command for `--expose` output
- `printSimulatorList()` - Display available simulators
- `resolveSimulator(shorthand:osVersion:)` - Parse simulator selection
- `resolveProduct(explicit:config:)` - Resolve product from flag or config
- `resolvePackages(projectPath:quiet:)` - Run SPM resolution
- `runXcodebuild(arguments:quiet:errorTransform:)` - Execute xcodebuild
- `buildXcodebuildArgs(...)` - Build xcodebuild argument arrays

### Herald

Formatted output handling. See the [README](README.md#outputting-status-from-narya) for complete documentation.

```swift
Herald.declare("Starting build...", isNewCommand: true)
Herald.declare("Compiling module A")
Herald.declare("Warning: something", asError: true)
Herald.declare("Build complete!", asConclusion: true)
Herald.raw("unformatted output")  // For --expose
```

### ShellRunner

Execute shell commands:

```swift
// Stream output to terminal
try ShellRunner.run("xcodebuild", arguments: args, workingDirectory: repoRoot)

// Capture output
let output = try ShellRunner.runAndCapture("git", arguments: ["status"])
```

### Logger

Debug logging (enabled via `--debug`):

```swift
Logger.debug("Processing file: \(path)")
Logger.error("Command failed", error: error)
```

## Adding a New Command

### Step 1: Create the Command File

For a simple command, create `Sources/narya/Commands/MyCommand.swift`:

```swift
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct MyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mycommand",
        abstract: "Short description of what it does.",
        discussion: """
            Longer description with usage examples and details.
            """
    )

    // Define options and flags
    @Flag(name: [.short, .long], help: "Minimize output.")
    var quiet = false

    @Flag(name: .long, help: "Print commands instead of running them.")
    var expose = false

    mutating func run() throws {
        let repo = try RepoDetector.requireValidRepo()

        if expose {
            Herald.raw("# Command that would run")
            Herald.raw("some-tool --flag")
            return
        }

        Herald.declare("Running my command...", isNewCommand: true)

        // Do work here

        Herald.declare("Complete!", asConclusion: true)
    }
}
```

### Step 2: Register the Command

Add your command to the subcommands array in `Sources/narya/narya.swift`:

```swift
subcommands: [
    Bootstrap.self,
    Build.self,
    // ...
    MyCommand.self,  // Add here (alphabetically)
    // ...
]
```

### Step 3: Add Tests

Create `Tests/naryaTests/MyCommandTests.swift`:

```swift
import Testing
@testable import narya

@Suite("MyCommand Tests")
struct MyCommandTests {
    @Test("Command has correct configuration")
    func configuration() {
        #expect(MyCommand.configuration.commandName == "mycommand")
        #expect(MyCommand.configuration.abstract.contains("Short description"))
    }

    @Test("Handles valid input")
    func validInput() throws {
        // Test implementation
    }
}
```

Run tests with `swift test --no-parallel`.

### Step 4: Document the Command

Add an entry to the "Currently Supported Commands" table in the README:

```markdown
| `narya mycommand` | Short description of what it does |
```

Add a detailed section if the command has significant options or behavior to explain.
