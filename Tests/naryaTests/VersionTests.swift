// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import narya

@Suite("Version Tests", .serialized)
struct VersionTests {
    func createVersionTestGitRepo() throws -> URL {
        let tempDir = try createTempDirectory()
        try ShellRunner.run("git", arguments: ["init"], workingDirectory: tempDir)
        // Create an initial commit so git rev-parse works
        try ShellRunner.run("git", arguments: ["commit", "--allow-empty", "-m", "Initial"], workingDirectory: tempDir)
        return tempDir
    }

    func createValidRepo() throws -> URL {
        let repoDir = try createVersionTestGitRepo()
        let markerPath = repoDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)
        return repoDir
    }

    // MARK: - Command Configuration Tests

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Version.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has subcommands configured")
    func commandHasSubcommands() {
        let subcommands = Version.configuration.subcommands
        #expect(subcommands.count == 4)
    }

    // MARK: - Show Tests

    @Test("show prints version and git sha")
    func showPrintsVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        // Create version.txt
        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Show.parse([])
        // Should not throw - just prints version
        try command.run()
    }

    @Test("show throws when version.txt missing")
    func showThrowsWhenVersionFileMissing() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Show.parse([])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    // MARK: - Bump Version Tests

    @Test("bump --major increments major version and resets minor")
    func bumpMajorIncrementsVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Bump.parse(["--major"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "146.0")
    }

    @Test("bump --minor increments minor version")
    func bumpMinorIncrementsVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Bump.parse(["--minor"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "145.7")
    }

    @Test("bump --major on X.0 version increments correctly")
    func bumpMajorOnZeroMinor() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "146.0".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Bump.parse(["--major"])
        try command.run()

        let newVersion = try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(newVersion == "147.0")
    }

    @Test("bump throws when version.txt missing")
    func bumpThrowsWhenVersionFileMissing() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Bump.parse(["--major"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    @Test("bump without flags throws ValidationError")
    func bumpWithoutFlagsThrows() throws {
        #expect(throws: (any Error).self) {
            _ = try Version.Bump.parse([])
        }
    }

    @Test("bump with both flags throws ValidationError")
    func bumpWithBothFlagsThrows() throws {
        #expect(throws: (any Error).self) {
            _ = try Version.Bump.parse(["--major", "--minor"])
        }
    }

    // MARK: - Set Version Tests

    @Test("set updates version.txt")
    func setUpdatesVersion() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let versionFile = repoDir.appendingPathComponent("version.txt")
        try "145.6".write(to: versionFile, atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.SetVersion.parse(["150.0"])
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

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.SetVersion.parse(["145.6"])
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

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.SetVersion.parse(["invalid"])

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

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.SetVersion.parse(["1.2.3"])

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
        try FileManager.default.createDirectory(at: clientDir, withIntermediateDirectories: true)
        let plistContent = """
            <plist>
            <dict>
                <key>CFBundleShortVersionString</key>
                <string>145.6</string>
            </dict>
            </plist>
            """
        try plistContent.write(to: clientDir.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Verify.parse([])
        // Should not throw when consistent
        try command.run()
    }

    @Test("verify throws when version.txt missing")
    func verifyThrowsWhenVersionFileMissing() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Verify.parse([])

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

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Bump.parse(["--major"])

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

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Version.Bump.parse(["--minor"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }
}
