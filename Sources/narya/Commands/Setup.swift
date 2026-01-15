// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Clone the firefox-ios repository."
    )

    @Flag(name: .long, help: "Use SSH URL for cloning (git@github.com:...) instead of HTTPS.")
    var ssh = false

    @Option(name: .long, help: "Directory path (absolute or relative) to clone into. Defaults to current directory.")
    var location: String?

    mutating func run() throws {
        try ToolChecker.requireGit()

        let repoURL = ssh
            ? "git@github.com:mozilla-mobile/firefox-ios.git"
            : "https://github.com/mozilla-mobile/firefox-ios.git"

        var arguments = ["clone", repoURL]
        if let location = location {
            arguments.append(location)
        }

        print("Cloning firefox-ios. This may take a while. Grab a coffee. Go pet a fox.")
        try ShellRunner.run("git", arguments: arguments)
        print("Cloning done.")
    }
}
