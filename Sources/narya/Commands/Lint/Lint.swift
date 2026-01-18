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
        subcommands: [Run.self, Fix.self, Info.self],
        defaultSubcommand: Run.self
    )
}
