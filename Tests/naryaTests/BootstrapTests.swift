// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import narya

@Suite("Bootstrap Tests", .serialized)
struct BootstrapTests {
    // MARK: - Command Configuration Tests

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Bootstrap.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Bootstrap.configuration.discussion
        #expect(!discussion.isEmpty)
        #expect(discussion.contains("Firefox"))
        #expect(discussion.contains("Focus"))
    }

    // MARK: - Product Enum Tests

    @Test("Product enum has firefox case")
    func productHasFirefox() {
        let product = Bootstrap.Product(rawValue: "firefox")
        #expect(product == .firefox)
    }

    @Test("Product enum has focus case")
    func productHasFocus() {
        let product = Bootstrap.Product(rawValue: "focus")
        #expect(product == .focus)
    }

    @Test("Product enum raw values are correct")
    func productRawValues() {
        #expect(Bootstrap.Product.firefox.rawValue == "firefox")
        #expect(Bootstrap.Product.focus.rawValue == "focus")
    }

    @Test("Product enum has exactly two cases")
    func productCaseCount() {
        #expect(Bootstrap.Product.allCases.count == 2)
    }

    // MARK: - Repository Validation Tests

    @Test("run throws when not in firefox-ios repo")
    func runThrowsWhenNotInRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Bootstrap.parse(["--all"])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    @Test("run throws when marker file missing")
    func runThrowsWhenMarkerMissing() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Bootstrap.parse(["--all"])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }

    // MARK: - Default Bootstrap Config Tests

    @Test("Config with default_bootstrap firefox is parsed correctly")
    func configWithFirefoxDefault() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        let yaml = """
            project: firefox-ios
            default_bootstrap: firefox
            """
        try yaml.write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.defaultBootstrap == "firefox")
    }

    @Test("Config with default_bootstrap focus is parsed correctly")
    func configWithFocusDefault() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        let yaml = """
            project: firefox-ios
            default_bootstrap: focus
            """
        try yaml.write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.defaultBootstrap == "focus")
    }

    @Test("Config without default_bootstrap has nil value")
    func configWithoutDefaultBootstrap() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.defaultBootstrap == nil)
    }
}
