// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

@Suite("RepoDetector Tests", .serialized)
struct RepoDetectorTests {
    @Test("findGitRoot returns repo root from subdirectory")
    func findGitRootFromSubdir() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        let subDir = repoDir.appendingPathComponent("some/nested/path")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        // Save and change directory
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(subDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        let found = RepoDetector.findGitRoot()
        #expect(found != nil)
        #expect(found?.standardizedFileURL == repoDir.standardizedFileURL)
    }

    @Test("findGitRoot returns nil outside git repo")
    func findGitRootOutsideRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        // Save and change directory
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        let found = RepoDetector.findGitRoot()
        #expect(found == nil)
    }

    @Test("Loads valid config from marker file")
    func loadsValidConfig() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.project == "firefox-ios")
    }

    @Test("Loads config with default_bootstrap field")
    func loadsConfigWithDefaultBootstrap() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        let yaml = """
            project: firefox-ios
            default_bootstrap: focus
            """
        try yaml.write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.project == "firefox-ios")
        #expect(config.defaultBootstrap == "focus")
    }

    @Test("Config without default_bootstrap has nil value")
    func configWithoutDefaultBootstrapIsNil() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)

        let config = try RepoDetector.loadConfig(from: markerPath)
        #expect(config.defaultBootstrap == nil)
    }

    @Test("Throws error for invalid YAML")
    func throwsForInvalidYaml() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        let markerPath = tempDir.appendingPathComponent(Configuration.markerFileName)
        try "not: valid: yaml: here".write(to: markerPath, atomically: true, encoding: .utf8)

        #expect(throws: RepoDetectorError.self) {
            _ = try RepoDetector.loadConfig(from: markerPath)
        }
    }

    @Test("requireValidRepo succeeds with correct project")
    func requireValidRepoSucceeds() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        let markerPath = repoDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)

        // Save and change directory
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        let repoInfo = try RepoDetector.requireValidRepo()
        #expect(repoInfo.config.project == "firefox-ios")
        #expect(repoInfo.root.standardizedFileURL == repoDir.standardizedFileURL)
    }

    @Test("requireValidRepo works from subdirectory")
    func requireValidRepoFromSubdir() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        let markerPath = repoDir.appendingPathComponent(Configuration.markerFileName)
        try "project: firefox-ios".write(to: markerPath, atomically: true, encoding: .utf8)

        let subDir = repoDir.appendingPathComponent("deeply/nested/folder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        // Save and change directory to subdirectory
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(subDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        let repoInfo = try RepoDetector.requireValidRepo()
        #expect(repoInfo.config.project == "firefox-ios")
        #expect(repoInfo.root.standardizedFileURL == repoDir.standardizedFileURL)
    }

    @Test("requireValidRepo throws for wrong project")
    func requireValidRepoThrowsForWrongProject() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        let markerPath = repoDir.appendingPathComponent(Configuration.markerFileName)
        try "project: some-other-project".write(to: markerPath, atomically: true, encoding: .utf8)

        // Save and change directory
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        #expect(throws: RepoDetectorError.self) {
            _ = try RepoDetector.requireValidRepo()
        }
    }

    @Test("requireValidRepo throws when marker not found")
    func requireValidRepoThrowsWhenMarkerNotFound() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        // Save and change directory (no marker file created)
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(repoDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        #expect(throws: RepoDetectorError.self) {
            _ = try RepoDetector.requireValidRepo()
        }
    }

    @Test("requireValidRepo throws when not in git repo")
    func requireValidRepoThrowsWhenNotInGitRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        // Save and change directory
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        #expect(throws: RepoDetectorError.self) {
            _ = try RepoDetector.requireValidRepo()
        }
    }

    @Test("RepoDetectorError.notInGitRepo has correct description")
    func notInGitRepoDescription() {
        let error = RepoDetectorError.notInGitRepo
        #expect(error.description.contains("git repository"))
    }

    @Test("RepoDetectorError.markerNotFound has correct description")
    func markerNotFoundDescription() {
        let error = RepoDetectorError.markerNotFound
        #expect(error.description.contains(Configuration.markerFileName))
    }

    @Test("RepoDetectorError.noValidRemote has correct description")
    func noValidRemoteDescription() {
        let error = RepoDetectorError.noValidRemote
        #expect(error.description.contains("mozilla-mobile/firefox-ios"))
        #expect(error.description.contains("git remote add upstream"))
    }

    // MARK: - Remote Validation Tests

    @Test("hasValidRemote returns false when no remotes exist")
    func hasValidRemoteReturnsFalseWithNoRemotes() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        let result = RepoDetector.hasValidRemote(repoRoot: repoDir)
        #expect(result == false)
    }

    @Test("hasValidRemote returns true when origin points to mozilla-mobile (SSH)")
    func hasValidRemoteReturnsTrueForMozillaOriginSSH() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        try ShellRunner.run(
            "git",
            arguments: ["remote", "add", "origin", "git@github.com:mozilla-mobile/firefox-ios.git"],
            workingDirectory: repoDir
        )

        let result = RepoDetector.hasValidRemote(repoRoot: repoDir)
        #expect(result == true)
    }

    @Test("hasValidRemote returns true when origin points to mozilla-mobile (HTTPS)")
    func hasValidRemoteReturnsTrueForMozillaOriginHTTPS() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        try ShellRunner.run(
            "git",
            arguments: ["remote", "add", "origin", "https://github.com/mozilla-mobile/firefox-ios.git"],
            workingDirectory: repoDir
        )

        let result = RepoDetector.hasValidRemote(repoRoot: repoDir)
        #expect(result == true)
    }

    @Test("hasValidRemote returns true when upstream points to mozilla-mobile (fork scenario)")
    func hasValidRemoteReturnsTrueForUpstreamRemote() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        // Simulate a fork: origin is user's fork, upstream is mozilla-mobile
        try ShellRunner.run(
            "git",
            arguments: ["remote", "add", "origin", "git@github.com:someuser/firefox-ios.git"],
            workingDirectory: repoDir
        )
        try ShellRunner.run(
            "git",
            arguments: ["remote", "add", "upstream", "git@github.com:mozilla-mobile/firefox-ios.git"],
            workingDirectory: repoDir
        )

        let result = RepoDetector.hasValidRemote(repoRoot: repoDir)
        #expect(result == true)
    }

    @Test("hasValidRemote returns false when no remote matches mozilla-mobile")
    func hasValidRemoteReturnsFalseForUnrelatedRemote() throws {
        let repoDir = try createTempGitRepo()
        defer { cleanup(repoDir) }

        try ShellRunner.run(
            "git",
            arguments: ["remote", "add", "origin", "git@github.com:someuser/some-other-repo.git"],
            workingDirectory: repoDir
        )

        let result = RepoDetector.hasValidRemote(repoRoot: repoDir)
        #expect(result == false)
    }
}

@Suite("MergedConfig Tests")
struct MergedConfigTests {
    @Test("MergedConfig uses project config values when provided")
    func usesProjectConfigValues() {
        let projectConfig = NaryaConfig(
            project: "firefox-ios",
            defaultBootstrap: "focus",
            defaultBuildProduct: "focus"
        )
        let merged = MergedConfig(projectConfig: projectConfig)

        #expect(merged.project == "firefox-ios")
        #expect(merged.defaultBootstrap == "focus")
        #expect(merged.defaultBuildProduct == "focus")
    }

    @Test("MergedConfig uses defaults when project config values are nil")
    func usesDefaultsWhenNil() {
        let projectConfig = NaryaConfig(
            project: "firefox-ios",
            defaultBootstrap: nil,
            defaultBuildProduct: nil
        )
        let merged = MergedConfig(projectConfig: projectConfig)

        #expect(merged.project == "firefox-ios")
        #expect(merged.defaultBootstrap == DefaultConfig.defaultBootstrap)
        #expect(merged.defaultBuildProduct == DefaultConfig.defaultBuildProduct)
    }

    @Test("MergedConfig handles partial override - bootstrap only")
    func partialOverrideBootstrapOnly() {
        let projectConfig = NaryaConfig(
            project: "firefox-ios",
            defaultBootstrap: "focus",
            defaultBuildProduct: nil
        )
        let merged = MergedConfig(projectConfig: projectConfig)

        #expect(merged.defaultBootstrap == "focus")
        #expect(merged.defaultBuildProduct == DefaultConfig.defaultBuildProduct)
    }

    @Test("MergedConfig handles partial override - build product only")
    func partialOverrideBuildProductOnly() {
        let projectConfig = NaryaConfig(
            project: "firefox-ios",
            defaultBootstrap: nil,
            defaultBuildProduct: "focus"
        )
        let merged = MergedConfig(projectConfig: projectConfig)

        #expect(merged.defaultBootstrap == DefaultConfig.defaultBootstrap)
        #expect(merged.defaultBuildProduct == "focus")
    }
}
