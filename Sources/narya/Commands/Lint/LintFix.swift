// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Lint {
    struct Fix: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "fix",
            abstract: "Automatically correct fixable SwiftLint violations."
        )

        // MARK: - Scope

        @Flag(name: [.short, .long], help: "Fix only files changed compared to main branch.")
        var changed = false

        @Flag(name: [.short, .long], help: "Fix the entire codebase (default for fix).")
        var all = false

        @Flag(name: .long, help: "Print the commands instead of running them.")
        var expose = false

        // MARK: - Run

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()
            try LintHelpers.requireSwiftlint()

            // For fix, default is --all unless --changed is specified
            let fixAll = !changed

            if expose {
                printExposedCommands(fixAll: fixAll, repoRoot: repo.root)
                return
            }

            try runFix(fixAll: fixAll, repoRoot: repo.root)
        }

        // MARK: - Fix

        private func runFix(fixAll: Bool, repoRoot: URL) throws {
            if fixAll {
                Herald.declare("Fixing entire codebase...", isNewCommand: true)

                do {
                    try ShellRunner.run("swiftlint", arguments: ["--fix"], workingDirectory: repoRoot)
                    Herald.declare("Fix complete!", asConclusion: true)
                } catch let error as ShellRunnerError {
                    if case .commandFailed(_, let exitCode) = error {
                        Herald.declare("Fix completed with issues (exit code \(exitCode))", asError: true, asConclusion: true)
                    } else {
                        throw error
                    }
                }
            } else {
                Herald.declare("Fixing changed files...", isNewCommand: true)
                let changedFiles = try LintHelpers.getChangedSwiftFiles(repoRoot: repoRoot)

                if changedFiles.isEmpty {
                    Herald.declare("No changed Swift files found.")
                    return
                }

                Herald.declare("Found \(changedFiles.count) changed file(s)")

                let configPath = repoRoot.appendingPathComponent(".swiftlint.yaml").path

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
                    Herald.declare("Fix completed with issues", asError: true, asConclusion: true)
                } else {
                    Herald.declare("Fix complete!", asConclusion: true)
                }
            }
        }

        // MARK: - Expose Command

        private func printExposedCommands(fixAll: Bool, repoRoot: URL) {
            if fixAll {
                Herald.raw("# Fix entire codebase")
                Herald.raw("swiftlint --fix")
            } else {
                let configPath = repoRoot.appendingPathComponent(".swiftlint.yaml").path

                Herald.raw("# Get merge base")
                Herald.raw("BASE=$(git merge-base HEAD main)")
                Herald.raw("")
                Herald.raw("# Find changed Swift files")
                let gitArgs = ["diff", "--name-only", "--diff-filter=ACMR", "$BASE...HEAD"]
                Herald.raw(CommandHelpers.formatCommand("git", arguments: gitArgs))
                Herald.raw("")

                let args: [String] = ["lint", "--fix", "--config", configPath, "--path", "<file>"]

                Herald.raw("# Fix each changed file")
                Herald.raw(CommandHelpers.formatCommand("swiftlint", arguments: args))
            }
        }
    }
}
