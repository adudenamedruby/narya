// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Version {
    struct SetVersion: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Set the version number explicitly."
        )

        @Argument(help: "The version to set (e.g., '123.4' or '123.4.1').")
        var version: String

        mutating func run() throws {
            // Validate the new version format
            _ = try Version.parseVersion(version)

            let repo = try RepoDetector.requireValidRepo()
            let currentVersion = try Version.readVersion(repoRoot: repo.root)

            if currentVersion == version {
                Herald.declare("Version is already \(version)", isNewCommand: true, asConclusion: true)
                return
            }

            Herald.declare("Setting version: \(currentVersion) -> \(version)", isNewCommand: true)
            try Version.updateVersionInFiles(from: currentVersion, to: version, repoRoot: repo.root)
            Herald.declare("Version updated to \(version)", asConclusion: true)
        }
    }
}
