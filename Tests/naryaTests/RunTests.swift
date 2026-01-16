// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import narya

@Suite("Run Tests", .serialized)
struct RunTests {
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

    func cleanup(_ url: URL) {
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Command Configuration Tests

    @Test("Command has correct name")
    func commandName() {
        #expect(Run.configuration.commandName == "run")
    }

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Run.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Run.configuration.discussion
        #expect(!discussion.isEmpty)
        #expect(discussion.contains("simulator"))
    }

    // MARK: - Argument Parsing Tests

    @Test("Can parse product option short form")
    func parseProductShort() throws {
        let command = try Run.parse(["-p", "focus"])
        #expect(command.product == .focus)
    }

    @Test("Can parse product option long form")
    func parseProductLong() throws {
        let command = try Run.parse(["--product", "klar"])
        #expect(command.product == .klar)
    }

    @Test("Can parse simulator option")
    func parseSimulator() throws {
        let command = try Run.parse(["--simulator", "iPhone 16 Pro"])
        #expect(command.simulator == "iPhone 16 Pro")
    }

    @Test("Can parse os option")
    func parseOs() throws {
        let command = try Run.parse(["--os", "18.2"])
        #expect(command.os == "18.2")
    }

    @Test("Can parse configuration option")
    func parseConfiguration() throws {
        let command = try Run.parse(["--configuration", "Fennec"])
        #expect(command.configuration == "Fennec")
    }

    @Test("Can parse derived-data option")
    func parseDerivedData() throws {
        let command = try Run.parse(["--derived-data", "/tmp/DD"])
        #expect(command.derivedData == "/tmp/DD")
    }

    @Test("Can parse skip-resolve flag")
    func parseSkipResolve() throws {
        let command = try Run.parse(["--skip-resolve"])
        #expect(command.skipResolve == true)
    }

    @Test("Can parse clean flag")
    func parseClean() throws {
        let command = try Run.parse(["--clean"])
        #expect(command.clean == true)
    }

    @Test("Can parse quiet flag short form")
    func parseQuietShort() throws {
        let command = try Run.parse(["-q"])
        #expect(command.quiet == true)
    }

    @Test("Can parse quiet flag long form")
    func parseQuietLong() throws {
        let command = try Run.parse(["--quiet"])
        #expect(command.quiet == true)
    }

    @Test("Default values are correct")
    func defaultValues() throws {
        let command = try Run.parse([])
        #expect(command.product == nil)
        #expect(command.simulator == nil)
        #expect(command.os == nil)
        #expect(command.configuration == nil)
        #expect(command.derivedData == nil)
        #expect(command.skipResolve == false)
        #expect(command.clean == false)
        #expect(command.quiet == false)
    }

    @Test("Can combine multiple flags")
    func combineFlags() throws {
        let command = try Run.parse(["-p", "focus", "--clean", "-q"])
        #expect(command.product == .focus)
        #expect(command.clean == true)
        #expect(command.quiet == true)
    }

    // MARK: - Repository Validation Tests

    @Test("run throws when not in git repo")
    func runThrowsWhenNotInGitRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(tempDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Run.parse([])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    @Test("run throws when marker file missing")
    func runThrowsWhenMarkerMissing() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Run.parse([])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }
}
