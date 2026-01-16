// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import narya

@Suite("Version Tests", .serialized)
struct VersionTests {
    let fileManager = FileManager.default

    func createTempDirectory() throws -> URL {
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func createTempGitRepo() throws -> URL {
        let tempDir = try createTempDirectory()
        try ShellRunner.run("git", arguments: ["init"], workingDirectory: tempDir)
        return tempDir
    }

    func createValidRepo() throws -> URL {
        let repoDir = try createTempGitRepo()
        let markerPath = repoDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)
        return repoDir
    }

    func cleanup(_ url: URL) {
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Command Configuration Tests

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Version.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Version.configuration.discussion
        #expect(!discussion.isEmpty)
    }

    // MARK: - Flag Validation Tests

    @Test("run without flags does not throw")
    func runWithoutFlagsShowsHelp() throws {
        // When no flags are specified, it should print help and return without error
        var command = try Version.parse([])
        // This should not throw - it prints help
        try command.run()
    }

    @Test("run with both major and minor throws ValidationError")
    func runWithBothFlagsThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        // Create version.txt
        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.0".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--major", "--minor"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    @Test("run with major flag throws when version.txt missing")
    func runThrowsWhenVersionFileMissing() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--major"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    // MARK: - Version Update Tests

    @Test("major flag increments major version and resets minor")
    func majorFlagIncrementsVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        // Create version.txt with initial version
        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--major"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "146.0")
    }

    @Test("minor flag increments minor version")
    func minorFlagIncrementsVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        // Create version.txt with initial version
        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--minor"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "145.7")
    }

    @Test("major flag on X.0 version increments correctly")
    func majorOnZeroMinor() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "146.0".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--major"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "147.0")
    }

    @Test("Invalid version format throws error")
    func invalidVersionFormatThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "invalid".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--major"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    @Test("Version with three components throws error")
    func threeComponentVersionThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "1.2.3".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--minor"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }
}
