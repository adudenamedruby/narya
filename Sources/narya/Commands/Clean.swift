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

    mutating func run() throws {
        // If no flags specified, show help
        guard packages || build || derivedData || all else {
            print(Clean.helpMessage())
            return
        }

        Herald.reset()

        // Validate we're in a firefox-ios repository and get repo root
        let repo = try RepoDetector.requireValidRepo()

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
            Herald.declare("No .build directory found, nothing to clean.")
            return
        }

        Herald.declare("Removing .build directory...")
        try fileManager.removeItem(at: buildDir)
        Herald.declare("Build directory cleaned!")
    }

    private func cleanDerivedData() throws {
        let fileManager = FileManager.default
        let derivedDataDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        guard fileManager.fileExists(atPath: derivedDataDir.path) else {
            Herald.declare("No DerivedData directory found, nothing to clean.")
            return
        }

        Herald.declare("Removing DerivedData directory...")
        try fileManager.removeItem(at: derivedDataDir)
        Herald.declare("DerivedData cleaned!")
    }

    private func cleanPackages(repoRoot: URL) throws {
        Herald.declare("Resetting Swift packages...")
        try ShellRunner.run("swift", arguments: ["package", "reset"], workingDirectory: repoRoot)

        Herald.declare("Resolving Swift packages...")
        try ShellRunner.run("swift", arguments: ["package", "resolve"], workingDirectory: repoRoot)

        Herald.declare("Swift packages cleaned!")
    }
}
