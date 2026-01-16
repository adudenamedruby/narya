// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import narya

@Suite("Nimbus Tests", .serialized)
struct NimbusTests {
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

    func setupNimbusStructure(in repoDir: URL) throws {
        // Create the firefox-ios directory structure
        let firefoxDir = repoDir.appendingPathComponent("firefox-ios")
        let nimbusDir = firefoxDir.appendingPathComponent("nimbus-features")
        try fileManager.createDirectory(at: nimbusDir, withIntermediateDirectories: true)

        // Create nimbus.fml.yaml
        let fmlContent = """
            ---
            about:
              description: Firefox for iOS
            include:
            """
        let fmlFile = firefoxDir.appendingPathComponent("nimbus.fml.yaml")
        try fmlContent.write(to: fmlFile, atomically: true, encoding: .utf8)
    }

    func cleanup(_ url: URL) {
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Command Configuration Tests

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Nimbus.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Nimbus.configuration.discussion
        #expect(!discussion.isEmpty)
    }

    // MARK: - Flag Validation Tests

    @Test("run without flags does not throw")
    func runWithoutFlagsShowsHelp() throws {
        var command = try Nimbus.parse([])
        // Should print help and return without error
        try command.run()
    }

    @Test("run throws when not in firefox-ios repo")
    func runThrowsWhenNotInRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(tempDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--update"])

        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    // MARK: - Update Command Tests

    @Test("update command updates nimbus.fml.yaml include block")
    func updateCommandUpdatesInclude() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        // Add a feature file
        let featuresDir = repoDir.appendingPathComponent("firefox-ios/nimbus-features")
        let featureFile = featuresDir.appendingPathComponent("testFeature.yaml")
        try "# Test feature".write(to: featureFile, atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--update"])
        try command.run()

        // Verify the FML was updated
        let fmlFile = repoDir.appendingPathComponent("firefox-ios/nimbus.fml.yaml")
        let content = try String(contentsOf: fmlFile, encoding: .utf8)
        #expect(content.contains("nimbus-features/testFeature.yaml"))
    }

    @Test("update command includes multiple feature files alphabetically")
    func updateCommandSortsFiles() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        // Add multiple feature files
        let featuresDir = repoDir.appendingPathComponent("firefox-ios/nimbus-features")
        try "# Feature C".write(to: featuresDir.appendingPathComponent("cFeature.yaml"), atomically: true, encoding: .utf8)
        try "# Feature A".write(to: featuresDir.appendingPathComponent("aFeature.yaml"), atomically: true, encoding: .utf8)
        try "# Feature B".write(to: featuresDir.appendingPathComponent("bFeature.yaml"), atomically: true, encoding: .utf8)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--update"])
        try command.run()

        let fmlFile = repoDir.appendingPathComponent("firefox-ios/nimbus.fml.yaml")
        let content = try String(contentsOf: fmlFile, encoding: .utf8)

        // All files should be present
        #expect(content.contains("aFeature.yaml"))
        #expect(content.contains("bFeature.yaml"))
        #expect(content.contains("cFeature.yaml"))
    }

    // MARK: - Add Command Tests

    @Test("add command creates new feature file")
    func addCommandCreatesFile() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--add", "myTest"])
        try command.run()

        // Verify file was created with "Feature" suffix appended
        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myTestFeature.yaml")
        #expect(fileManager.fileExists(atPath: newFile.path))
    }

    @Test("add command appends Feature if not present")
    func addCommandAppendsFeatureSuffix() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--add", "myTest"])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myTestFeature.yaml")
        #expect(fileManager.fileExists(atPath: newFile.path))
    }

    @Test("add command does not double-append Feature")
    func addCommandDoesNotDoubleAppendFeature() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--add", "myTestFeature"])
        try command.run()

        // Should be myTestFeature.yaml, not myTestFeatureFeature.yaml
        let correctFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myTestFeature.yaml")
        let wrongFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myTestFeatureFeature.yaml")
        #expect(fileManager.fileExists(atPath: correctFile.path))
        #expect(!fileManager.fileExists(atPath: wrongFile.path))
    }

    @Test("add command creates file with correct template")
    func addCommandCreatesTemplate() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--add", "test"])
        try command.run()

        // "test" gets "Feature" appended, so filename is "testFeature.yaml"
        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/testFeature.yaml")
        let content = try String(contentsOf: newFile, encoding: .utf8)

        #expect(content.contains("features:"))
        #expect(content.contains("description:"))
        #expect(content.contains("variables:"))
        #expect(content.contains("defaults:"))
        #expect(content.contains("objects:"))
        #expect(content.contains("enums:"))
    }

    @Test("add command uses kebab-case for feature identifier")
    func addCommandUsesKebabCase() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--add", "myAwesomeTest"])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/nimbus-features/myAwesomeTestFeature.yaml")
        let content = try String(contentsOf: newFile, encoding: .utf8)

        // The feature identifier should be kebab-case
        #expect(content.contains("my-awesome-test-feature:"))
    }

    @Test("add command updates nimbus.fml.yaml after adding")
    func addCommandUpdatesFml() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupNimbusStructure(in: repoDir)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--add", "new"])
        try command.run()

        let fmlFile = repoDir.appendingPathComponent("firefox-ios/nimbus.fml.yaml")
        let content = try String(contentsOf: fmlFile, encoding: .utf8)
        // "new" gets "Feature" appended, so filename is "newFeature.yaml"
        #expect(content.contains("nimbus-features/newFeature.yaml"))
    }

    // MARK: - FML Not Found Tests

    @Test("update throws when nimbus.fml.yaml not found")
    func updateThrowsWhenFmlMissing() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        // Create nimbus-features dir but not the FML file
        let nimbusDir = repoDir.appendingPathComponent("firefox-ios/nimbus-features")
        try fileManager.createDirectory(at: nimbusDir, withIntermediateDirectories: true)

        let originalDir = fileManager.currentDirectoryPath
        fileManager.changeCurrentDirectoryPath(repoDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = try Nimbus.parse(["--update"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }
}
