// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser

struct FixPackages: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fix-packages",
        abstract: "Reset and resolve Swift packages.",
        discussion: """
            This command must be run from within a firefox-ios repository.
            It runs 'swift package reset' followed by 'swift package resolve'
            to fix common Swift package issues.
            """
    )

    mutating func run() throws {
        // Validate we're in a firefox-ios repository and get repo root
        let repo = try RepoDetector.requireValidRepo()

        print("Resetting Swift packages...")
        try ShellRunner.run("swift", arguments: ["package", "reset"], workingDirectory: repo.root)

        print("Resolving Swift packages...")
        try ShellRunner.run("swift", arguments: ["package", "resolve"], workingDirectory: repo.root)

        print("Swift packages fixed!")
    }
}
