// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Clean: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clean",
        abstract: "Clean up various cached or generated files."
    )

    @Flag(name: [.short, .long], help: "Reset and resolve Swift packages.")
    var packages = false

    @Flag(name: [.short, .long], help: "Delete the .build directory.")
    var build = false

    @Flag(name: [.short, .long], help: "Delete ~/Library/Developer/Xcode/DerivedData.")
    var derivedData = false

    @Flag(name: [.short, .long], help: "Clean everything (packages, build, and derived data).")
    var all = false

    @Flag(name: .long, help: "Print the commands instead of running them.")
    var expose = false

    mutating func run() throws {
        // If no flags specified, show help
        guard packages || build || derivedData || all else {
            Herald.raw(Clean.helpMessage())
            return
        }

        // Validate we're in a firefox-ios repository and get repo root
        let repo = try RepoDetector.requireValidRepo()

        // Handle --expose: print commands instead of running
        if expose {
            printExposedCommands(repoRoot: repo.root)
            return
        }

        if build || all {
            try cleanBuild(repoRoot: repo.root)
        }

        if derivedData || all {
            try cleanDerivedData()
        }

        if packages || all {
            try cleanPackages(repoRoot: repo.root)
        }
    }

    private func cleanBuild(repoRoot: URL) throws {
        let buildDir = repoRoot.appendingPathComponent(".build")
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: buildDir.path) else {
            Herald.declare("No .build directory found, nothing to clean.", isNewCommand: true)
            return
        }

        Herald.declare("Removing .build directory...", isNewCommand: true)
        try fileManager.removeItem(at: buildDir)
        Herald.declare("Build directory cleaned!")
    }

    private func cleanDerivedData() throws {
        let fileManager = FileManager.default
        let derivedDataDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        guard fileManager.fileExists(atPath: derivedDataDir.path) else {
            Herald.declare("No DerivedData directory found, nothing to clean.", isNewCommand: true)
            return
        }

        Herald.declare("Removing DerivedData directory...", isNewCommand: true)
        try fileManager.removeItem(at: derivedDataDir)
        Herald.declare("DerivedData cleaned!")
    }

    private func cleanPackages(repoRoot: URL) throws {
        Herald.declare("Resetting Swift packages...", isNewCommand: true)
        try ShellRunner.run("swift", arguments: ["package", "reset"], workingDirectory: repoRoot)

        Herald.declare("Resolving Swift packages...")
        try ShellRunner.run("swift", arguments: ["package", "resolve"], workingDirectory: repoRoot)

        Herald.declare("Swift packages cleaned!", asConclusion: true)
    }

    // MARK: - Expose Command

    private func printExposedCommands(repoRoot: URL) {
        let fileManager = FileManager.default

        if build || all {
            let buildDir = repoRoot.appendingPathComponent(".build")
            Herald.raw("# Remove .build directory")
            Herald.raw(CommandHelpers.formatCommand("rm", arguments: ["-rf", buildDir.path]))
            Herald.raw("")
        }

        if derivedData || all {
            let derivedDataDir = fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Developer/Xcode/DerivedData")
            Herald.raw("# Remove DerivedData directory")
            Herald.raw(CommandHelpers.formatCommand("rm", arguments: ["-rf", derivedDataDir.path]))
            Herald.raw("")
        }

        if packages || all {
            Herald.raw("# Reset Swift packages")
            Herald.raw(CommandHelpers.formatCommand("swift", arguments: ["package", "reset"]))
            Herald.raw("")
            Herald.raw("# Resolve Swift packages")
            Herald.raw(CommandHelpers.formatCommand("swift", arguments: ["package", "resolve"]))
        }
    }
}
