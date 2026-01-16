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
        // Create an initial commit so git rev-parse works
        try ShellRunner.run("git", arguments: ["commit", "--allow-empty", "-m", "Initial"], workingDirectory: tempDir)
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

    @Test("Discussion text is defined")
    func commandHasDiscussion() {
        // Discussion can be empty for simple commands
        _ = Version.configuration.discussion
    }

    // MARK: - Default Behavior Tests (Print Version)

    @Test("run without flags prints version and git sha")
    func runWithoutFlagsPrintsVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        // Create version.txt
        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse([])
        // Should not throw - just prints version
        try command.run()
    }

    @Test("run without flags throws when version.txt missing")
    func runThrowsWhenVersionFileMissing() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse([])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    // MARK: - Conflicting Options Tests

    @Test("run with multiple options throws ValidationError")
    func runWithMultipleOptionsThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.0".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--bump", "major", "--verify"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    // MARK: - Bump Version Tests

    @Test("bump major increments major version and resets minor")
    func bumpMajorIncrementsVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--bump", "major"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "146.0")
    }

    @Test("bump minor increments minor version")
    func bumpMinorIncrementsVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--bump", "minor"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "145.7")
    }

    @Test("bump major on X.0 version increments correctly")
    func bumpMajorOnZeroMinor() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "146.0".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--bump", "major"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "147.0")
    }

    @Test("bump throws when version.txt missing")
    func bumpThrowsWhenVersionFileMissing() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--bump", "major"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    // MARK: - Set Version Tests

    @Test("set updates version.txt")
    func setUpdatesVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--set", "150.0"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "150.0")
    }

    @Test("set with same version does not error")
    func setWithSameVersionNoError() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--set", "145.6"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "145.6")
    }

    @Test("set with invalid format throws ValidationError")
    func setWithInvalidFormatThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--set", "invalid"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    @Test("set with three component version throws ValidationError")
    func setWithThreeComponentsThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--set", "1.2.3"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    // MARK: - Verify Tests

    @Test("verify passes when files are consistent")
    func verifyPassesWhenConsistent() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        // Create version.txt
        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        // Create consistent plist
        let clientDir = repoDir.appendingPathComponent("firefox-ios/Client")
        try fileManager.createDirectory(at: clientDir, withIntermediateDirectories: true)
        let plistContent = """
            <plist>
            <dict>
                <key>CFBundleShortVersionString</key>
                <string>145.6</string>
            </dict>
            </plist>
            """
        try plistContent.write(to: clientDir.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--verify"])
        // Should not throw when consistent
        try command.run()
    }

    @Test("verify throws when version.txt missing")
    func verifyThrowsWhenVersionFileMissing() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--verify"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    // MARK: - Invalid Version Format Tests

    @Test("Invalid version format in version.txt throws error")
    func invalidVersionFormatThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "invalid".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--bump", "major"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    @Test("Version with three components in version.txt throws error")
    func threeComponentVersionThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "1.2.3".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.parse(["--bump", "minor"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }
}
