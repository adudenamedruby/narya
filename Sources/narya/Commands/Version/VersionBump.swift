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

        mutating func validate() throws {
            if major && minor {
                throw ValidationError("Cannot specify both --major and --minor. Choose one.")
            }
            if !major && !minor {
                throw ValidationError("Must specify either --major or --minor.")
            }
        }

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()
            let currentVersion = try Version.readVersion(repoRoot: repo.root)
            let (majorVersion, minorVersion) = try Version.parseVersion(currentVersion)

            let newMajor: Int
            let newMinor: Int

            if major {
                newMajor = majorVersion + 1
                newMinor = 0
            } else {
                newMajor = majorVersion
                newMinor = minorVersion + 1
            }

            let newVersion = "\(newMajor).\(newMinor)"

            Herald.declare("Bumping version: \(currentVersion) -> \(newVersion)", isNewCommand: true)
            try Version.updateVersionInFiles(from: currentVersion, to: newVersion, repoRoot: repo.root)
            Herald.declare("Version updated to \(newVersion)", asConclusion: true)
        }
    }
}
