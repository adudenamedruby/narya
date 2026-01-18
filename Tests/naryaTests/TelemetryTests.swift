// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import narya

@Suite("Telemetry Tests", .serialized)
struct TelemetryTests {
    func createValidRepo() throws -> URL {
        let repoDir = try createTempGitRepo()
        let markerPath = repoDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)
        return repoDir
    }

    func setupTelemetryStructure(in repoDir: URL) throws {
        // Create the Glean directory structure
        let gleanDir = repoDir.appendingPathComponent("firefox-ios/Client/Glean")
        let probesDir = gleanDir.appendingPathComponent("probes")
        try FileManager.default.createDirectory(at: probesDir, withIntermediateDirectories: true)

        // Create glean_index.yaml
        let indexContent = """
            ---
            $schema: moz://mozilla.org/schemas/glean/metrics/2-0-0
            metrics_files:
            """
        let indexFile = gleanDir.appendingPathComponent("glean_index.yaml")
        try indexContent.write(to: indexFile, atomically: true, encoding: .utf8)

        // Create gleanProbes.xcfilelist
        let fileListPath = gleanDir.appendingPathComponent("gleanProbes.xcfilelist")
        try "".write(to: fileListPath, atomically: true, encoding: .utf8)

        // Create tags.yaml
        let tagsContent = """
            ExistingTag:
              description: An existing tag
            """
        let tagsFile = gleanDir.appendingPathComponent("tags.yaml")
        try tagsContent.write(to: tagsFile, atomically: true, encoding: .utf8)

        // Create Storage directory with metrics.yaml
        let storageDir = repoDir.appendingPathComponent("firefox-ios/Storage")
        try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        let storageMetrics = storageDir.appendingPathComponent("metrics.yaml")
        try "# Storage metrics".write(to: storageMetrics, atomically: true, encoding: .utf8)
    }

    // MARK: - Command Configuration Tests

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Telemetry.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Telemetry.configuration.discussion
        #expect(!discussion.isEmpty)
    }

    // MARK: - Flag Validation Tests

    @Test("run without flags does not throw")
    func runWithoutFlagsShowsHelp() throws {
        var command = try Telemetry.parse([])
        // Should print help and return without error
        try command.run()
    }

    @Test("run with both update and add throws ValidationError")
    func runWithBothFlagsThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Telemetry.parse(["--refresh", "--add", "someFeature"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    @Test("add with snake_case name throws ValidationError")
    func addWithSnakeCaseThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Telemetry.parse(["--add", "some_feature"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    @Test("add with kebab-case name throws ValidationError")
    func addWithKebabCaseThrows() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Telemetry.parse(["--add", "some-feature"])

        #expect(throws: ValidationError.self) {
            try command.run()
        }
    }

    // MARK: - Update Command Tests

    @Test("update command updates glean_index.yaml")
    func updateCommandUpdatesIndex() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupTelemetryStructure(in: repoDir)

        // Add a probe file
        let probesDir = repoDir.appendingPathComponent("firefox-ios/Client/Glean/probes")
        let probeFile = probesDir.appendingPathComponent("test_feature.yaml")
        try "# Test probe".write(to: probeFile, atomically: true, encoding: .utf8)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Telemetry.parse(["--refresh"])
        try command.run()

        // Verify the index was updated
        let indexFile = repoDir.appendingPathComponent("firefox-ios/Client/Glean/glean_index.yaml")
        let content = try String(contentsOf: indexFile, encoding: .utf8)
        #expect(content.contains("test_feature.yaml"))
    }

    // MARK: - Add Command Tests

    @Test("add command creates new metrics file")
    func addCommandCreatesFile() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupTelemetryStructure(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Telemetry.parse(["--add", "newFeature"])
        try command.run()

        // Verify file was created with snake_case name
        let newFile = repoDir.appendingPathComponent("firefox-ios/Client/Glean/probes/new_feature.yaml")
        #expect(FileManager.default.fileExists(atPath: newFile.path))
    }

    @Test("add command creates file with correct template")
    func addCommandCreatesTemplate() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupTelemetryStructure(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Telemetry.parse(["--add", "testFeature"])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/Client/Glean/probes/test_feature.yaml")
        let content = try String(contentsOf: newFile, encoding: .utf8)

        #expect(content.contains("$schema: moz://mozilla.org/schemas/glean/metrics/2-0-0"))
        #expect(content.contains("$tags:"))
        #expect(content.contains("TestFeature"))
    }

    @Test("add command updates tags.yaml")
    func addCommandUpdatesTags() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupTelemetryStructure(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Telemetry.parse(["--add", "newFeature"])
        try command.run()

        let tagsFile = repoDir.appendingPathComponent("firefox-ios/Client/Glean/tags.yaml")
        let content = try String(contentsOf: tagsFile, encoding: .utf8)
        #expect(content.contains("NewFeature:"))
    }

    @Test("add command with description sets tag description")
    func addCommandWithDescription() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupTelemetryStructure(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Telemetry.parse(["--add", "customFeature", "--description", "My custom description"])
        try command.run()

        let tagsFile = repoDir.appendingPathComponent("firefox-ios/Client/Glean/tags.yaml")
        let content = try String(contentsOf: tagsFile, encoding: .utf8)
        #expect(content.contains("My custom description"))
    }

    // MARK: - camelCase to snake_case Conversion Tests

    @Test("camelCase is converted to snake_case in filename")
    func camelCaseToSnakeCaseFilename() throws {
        let repoDir = try createValidRepo()
        defer { cleanup(repoDir) }
        try setupTelemetryStructure(in: repoDir)

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Telemetry.parse(["--add", "myNewAwesomeFeature"])
        try command.run()

        let newFile = repoDir.appendingPathComponent("firefox-ios/Client/Glean/probes/my_new_awesome_feature.yaml")
        #expect(FileManager.default.fileExists(atPath: newFile.path))
    }
}
