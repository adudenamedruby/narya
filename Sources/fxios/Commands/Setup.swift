// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Clone and bootstrap the firefox-ios repository."
    )

    enum CloneProtocol: EnumerableFlag {
        case https
        case ssh

        static func name(for value: CloneProtocol) -> NameSpecification {
            .long
        }
    }

    @Flag(help: "Protocol to use for git URLs.")
    var cloneProtocol: CloneProtocol

    @Option(name: .long, help: "Full URL of your fork. Clones the fork as 'origin' and adds mozilla-mobile as 'upstream'.")
    var withFork: String?

    @Option(name: .long, help: "Directory path (absolute or relative) to clone into. Defaults to current directory.")
    var location: String?

    mutating func run() throws {
        // Check if we're already in a firefox-ios repository
        if RepoDetector.isInFirefoxIOSRepo() {
            Herald.declare("You are already inside a firefox-ios repository.", isNewCommand: true)
            Herald.declare("If you want to re-run the setup steps, use: fxios bootstrap --all")
            return
        }

        try ToolChecker.requireGit()
        try ToolChecker.requireNode()
        try ToolChecker.requireNpm()

        let mozillaURL = cloneProtocol == .https
            ? "https://github.com/mozilla-mobile/firefox-ios.git"
            : "git@github.com:mozilla-mobile/firefox-ios.git"

        // Determine the clone URL and destination
        let cloneURL = withFork ?? mozillaURL
        let cloneDir: String
        if let location = location {
            cloneDir = location
        } else {
            cloneDir = "firefox-ios"
        }

        var arguments = ["clone", cloneURL]
        if let location = location {
            arguments.append(location)
        }

        Herald.declare("Cloning firefox-ios. This may take a while. Grab a coffee. Go pet a fox.", isNewCommand: true)
        try ShellRunner.run("git", arguments: arguments)
        Herald.declare("Cloning done.")

        // Change into the cloned repository
        let clonePath = URL(fileURLWithPath: cloneDir).standardizedFileURL
        guard FileManager.default.changeCurrentDirectoryPath(clonePath.path) else {
            throw SetupError.failedToChangeDirectory(clonePath.path)
        }

        // If using a fork, add the mozilla-mobile repo as upstream
        if withFork != nil {
            Herald.declare("Adding mozilla-mobile as upstream remote...")
            do {
                try ShellRunner.run("git", arguments: ["remote", "add", "upstream", mozillaURL])
            } catch {
                throw SetupError.failedToAddUpstreamRemote
            }
        }

        Herald.declare("Running bootstrap in \(clonePath.path)...")

        // Run bootstrap
        var bootstrap = Bootstrap()
        bootstrap.all = true
        bootstrap.force = false
        try bootstrap.run()
    }
}

enum SetupError: Error, CustomStringConvertible {
    case failedToChangeDirectory(String)
    case failedToAddUpstreamRemote

    var description: String {
        switch self {
        case .failedToChangeDirectory(let path):
            return "Failed to change directory to \(path)."
        case .failedToAddUpstreamRemote:
            return "Failed to add upstream remote for mozilla-mobile/firefox-ios."
        }
    }
}
