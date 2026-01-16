// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Clone and bootstrap the firefox-ios repository."
    )

    @Flag(name: .long, help: "Use SSH URL for cloning (git@github.com:...) instead of HTTPS.")
    var ssh = false

    @Option(name: .long, help: "Directory path (absolute or relative) to clone into. Defaults to current directory.")
    var location: String?

    mutating func run() throws {
        try ToolChecker.requireGit()
        try ToolChecker.requireNode()
        try ToolChecker.requireNpm()

        let repoURL = ssh
            ? "git@github.com:mozilla-mobile/firefox-ios.git"
            : "https://github.com/mozilla-mobile/firefox-ios.git"

        // Determine the clone destination
        let cloneDir: String
        if let location = location {
            cloneDir = location
        } else {
            cloneDir = "firefox-ios"
        }

        var arguments = ["clone", repoURL]
        if let location = location {
            arguments.append(location)
        }

        print("💍 Cloning firefox-ios. This may take a while. Grab a coffee. Go pet a fox.")
        try ShellRunner.run("git", arguments: arguments)
        print("💍 Cloning done.\n")

        // MARK: - TEMPORARY: Create .narya.yaml marker file
        // TODO: Remove this block once .narya.yaml is added to the firefox-ios repository
        let markerPath = URL(fileURLWithPath: cloneDir)
            .appendingPathComponent(Configuration.markerFileName)
        let markerContent = "project: firefox-ios\n"
        try markerContent.write(to: markerPath, atomically: true, encoding: .utf8)
        print("💍 Created \(Configuration.markerFileName) marker file (temporary).\n")
        // END TEMPORARY

        // Change into the cloned repository
        let clonePath = URL(fileURLWithPath: cloneDir).standardizedFileURL
        guard FileManager.default.changeCurrentDirectoryPath(clonePath.path) else {
            throw SetupError.failedToChangeDirectory(clonePath.path)
        }

        print("💍 Running bootstrap in \(clonePath.path)...\n")

        // Run bootstrap
        var bootstrap = Bootstrap()
        bootstrap.product = .firefox
        bootstrap.force = false
        try bootstrap.run()
    }
}

enum SetupError: Error, CustomStringConvertible {
    case failedToChangeDirectory(String)

    var description: String {
        switch self {
        case .failedToChangeDirectory(let path):
            return "💥💍 Failed to change directory to \(path)."
        }
    }
}
