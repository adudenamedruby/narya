// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// MARK: - Lint Errors

enum LintError: Error, CustomStringConvertible {
    case swiftlintNotFound
    case lintFailed(exitCode: Int32)
    case noChangedFiles

    var description: String {
        switch self {
        case .swiftlintNotFound:
            return "swiftlint not found. Install it with 'brew install swiftlint'."
        case .lintFailed(let exitCode):
            return "Linting failed with exit code \(exitCode)."
        case .noChangedFiles:
            return "No changed Swift files found."
        }
    }
}

// MARK: - Lint Command

struct Lint: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lint",
        abstract: "Run SwiftLint on the codebase.",
        discussion: """
            By default, lints only Swift files changed compared to the main branch. \
            Use --all to run swiftlint on the entire codebase.

            This is not meant to replace swiftlint; merely be a simplified \
            entry-point for development. Please consult swiftlint for the full \
            capabilites of that tool if you need to use it.
            """,
        subcommands: [LintInfo.self]
    )

    // MARK: - Scope

    @Flag(name: [.short, .long], help: "Lint only files changed compared to main branch (default).")
    var changed = false

    @Flag(name: [.short, .long], help: "Lint the entire codebase (runs swiftlint at repo root).")
    var all = false

    // MARK: - Options

    @Flag(name: [.short, .long], help: "Treat warnings as errors.")
    var strict = false

    @Flag(name: [.short, .long], help: "Show only violation counts.")
    var quiet = false

    @Flag(name: .long, help: "Automatically correct fixable violations.")
    var fix = false

    @Flag(name: .long, help: "Print the commands instead of running them.")
    var expose = false

    // MARK: - Run

    mutating func run() throws {
        Herald.reset()

        // Validate we're in a firefox-ios repository
        let repo = try RepoDetector.requireValidRepo()

        // Check for swiftlint
        try requireSwiftlint()

        // Determine if we should lint all or just changed files
        // Default is changed (unless --all is specified)
        let lintAll = all || (!changed && !all && fix)  // --fix implies --all unless --changed specified

        // Handle --expose: print commands instead of running
        if expose {
            printExposedCommands(lintAll: lintAll, repoRoot: repo.root)
            return
        }

        if fix {
            try runFix(lintAll: lintAll, repoRoot: repo.root)
        } else {
            try runLint(lintAll: lintAll, repoRoot: repo.root)
        }
    }

    // MARK: - Lint

    private func runLint(lintAll: Bool, repoRoot: URL) throws {
        if lintAll {
            Herald.declare("Linting entire codebase...")

            do {
                try ShellRunner.run("swiftlint", arguments: [], workingDirectory: repoRoot)
                Herald.declare("Linting complete!")
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    if strict {
                        throw LintError.lintFailed(exitCode: exitCode)
                    }
                    Herald.warn("Linting found violations (exit code \(exitCode))")
                } else {
                    throw error
                }
            }
        } else {
            Herald.declare("Linting changed files...")
            let changedFiles = try getChangedSwiftFiles(repoRoot: repoRoot)

            if changedFiles.isEmpty {
                Herald.declare("No changed Swift files found.")
                return
            }

            Herald.declare("Found \(changedFiles.count) changed file(s)")

            let configPath = repoRoot.appendingPathComponent(".swiftlint.yaml").path

            // Lint each file one by one
            var hasViolations = false
            for file in changedFiles {
                var args: [String] = ["lint", "--config", configPath, "--path", file]

                if strict {
                    args.append("--strict")
                }

                if quiet {
                    args.append("--quiet")
                }

                do {
                    try ShellRunner.run("swiftlint", arguments: args, workingDirectory: repoRoot)
                } catch let error as ShellRunnerError {
                    if case .commandFailed(_, let exitCode) = error {
                        hasViolations = true
                        if strict {
                            throw LintError.lintFailed(exitCode: exitCode)
                        }
                    } else {
                        throw error
                    }
                }
            }

            if hasViolations {
                Herald.warn("Linting found violations")
            } else {
                Herald.declare("Linting complete!")
            }
        }
    }

    // MARK: - Fix

    private func runFix(lintAll: Bool, repoRoot: URL) throws {
        if lintAll {
            Herald.declare("Fixing entire codebase...")

            do {
                try ShellRunner.run("swiftlint", arguments: ["--fix"], workingDirectory: repoRoot)
                Herald.declare("Fix complete!")
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    Herald.warn("Fix completed with issues (exit code \(exitCode))")
                } else {
                    throw error
                }
            }
        } else {
            Herald.declare("Fixing changed files...")
            let changedFiles = try getChangedSwiftFiles(repoRoot: repoRoot)

            if changedFiles.isEmpty {
                Herald.declare("No changed Swift files found.")
                return
            }

            Herald.declare("Found \(changedFiles.count) changed file(s)")

            let configPath = repoRoot.appendingPathComponent(".swiftlint.yaml").path

            // Fix each file one by one
            var hasIssues = false
            for file in changedFiles {
                let args: [String] = ["lint", "--fix", "--config", configPath, "--path", file]

                do {
                    try ShellRunner.run("swiftlint", arguments: args, workingDirectory: repoRoot)
                } catch let error as ShellRunnerError {
                    if case .commandFailed = error {
                        hasIssues = true
                    } else {
                        throw error
                    }
                }
            }

            if hasIssues {
                Herald.warn("Fix completed with issues")
            } else {
                Herald.declare("Fix complete!")
            }
        }
    }

    // MARK: - Changed Files

    private func getChangedSwiftFiles(repoRoot: URL) throws -> [String] {
        // Get the merge base between HEAD and main
        let mergeBase = try ShellRunner.runAndCapture(
            "git",
            arguments: ["merge-base", "HEAD", "main"],
            workingDirectory: repoRoot
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        // Get files changed since merge base (Added, Copied, Modified, Renamed)
        let output = try ShellRunner.runAndCapture(
            "git",
            arguments: ["diff", "--name-only", "--diff-filter=ACMR", "\(mergeBase)...HEAD"],
            workingDirectory: repoRoot
        )

        let fileManager = FileManager.default
        let files = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.hasSuffix(".swift") }
            .map { repoRoot.appendingPathComponent($0).path }
            .filter { fileManager.fileExists(atPath: $0) }  // Skip files that don't exist

        return files
    }

    // MARK: - Tool Check

    private func requireSwiftlint() throws {
        do {
            _ = try ShellRunner.runAndCapture("which", arguments: ["swiftlint"])
        } catch {
            throw LintError.swiftlintNotFound
        }
    }

    // MARK: - Expose Command

    private func printExposedCommands(lintAll: Bool, repoRoot: URL) {
        if lintAll {
            print("# Lint entire codebase")
            if fix {
                print("swiftlint --fix")
            } else {
                print("swiftlint")
            }
        } else {
            let configPath = repoRoot.appendingPathComponent(".swiftlint.yaml").path

            // Show git commands to find changed files
            print("# Get merge base")
            print("BASE=$(git merge-base HEAD main)")
            print("")
            print("# Find changed Swift files")
            print(formatCommand("git", arguments: ["diff", "--name-only", "--diff-filter=ACMR", "$BASE...HEAD"]))
            print("")

            // Show swiftlint command for each file
            var args: [String] = ["lint", "--config", configPath, "--path", "<file>"]

            if fix {
                args.insert("--fix", at: 1)
            }

            if strict {
                args.append("--strict")
            }

            if quiet {
                args.append("--quiet")
            }

            print("# Lint each changed file")
            print(formatCommand("swiftlint", arguments: args))
        }
    }

    private func formatCommand(_ command: String, arguments: [String]) -> String {
        let escapedArgs = arguments.map { arg -> String in
            if arg.contains(" ") || arg.contains("=") {
                return "'\(arg)'"
            }
            return arg
        }
        return "\(command) \(escapedArgs.joined(separator: " \\\n    "))"
    }
}

// MARK: - Lint Info Subcommand

struct LintInfo: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show SwiftLint information and rules."
    )

    mutating func run() throws {
        Herald.reset()

        // Check for swiftlint
        do {
            _ = try ShellRunner.runAndCapture("which", arguments: ["swiftlint"])
        } catch {
            throw LintError.swiftlintNotFound
        }

        // Show version
        Herald.declare("SwiftLint Version:")
        try ShellRunner.run("swiftlint", arguments: ["version"])

        print("")  // Blank line separator

        // Show rules
        Herald.declare("Available Rules:")
        try ShellRunner.run("swiftlint", arguments: ["rules"])
    }
}
