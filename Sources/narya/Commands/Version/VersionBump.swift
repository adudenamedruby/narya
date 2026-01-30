// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Version {
    struct Bump: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Bump the version number."
        )

        @Flag(name: .long, help: "Bump major version (X.Y -> (X+1).0).")
        var major = false

        @Flag(name: .long, help: "Bump minor version (X.Y -> X.(Y+1)).")
        var minor = false

        @Flag(name: .long, help: "Bump hotfix version (X.Y -> X.Y.1, X.Y.Z -> X.Y.(Z+1)).")
        var hotfix = false

        mutating func validate() throws {
            let flagCount = [major, minor, hotfix].filter { $0 }.count
            if flagCount > 1 {
                throw ValidationError("Cannot specify multiple bump types. Choose one of --major, --minor, or --hotfix.")
            }
            if flagCount == 0 {
                throw ValidationError("Must specify one of --major, --minor, or --hotfix.")
            }
        }

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()
            let currentVersion = try Version.readVersion(repoRoot: repo.root)
            let parsed = try Version.parseVersion(currentVersion)

            let newVersion: String

            if major {
                newVersion = "\(parsed.major + 1).0"
            } else if minor {
                newVersion = "\(parsed.major).\(parsed.minor + 1)"
            } else {
                // hotfix
                let newPatch = (parsed.patch ?? 0) + 1
                newVersion = "\(parsed.major).\(parsed.minor).\(newPatch)"
            }

            Herald.declare("Bumping version: \(currentVersion) -> \(newVersion)", isNewCommand: true)
            try Version.updateVersionInFiles(from: currentVersion, to: newVersion, repoRoot: repo.root)
            Herald.declare("Version updated to \(newVersion)", asConclusion: true)
        }
    }
}
