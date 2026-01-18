// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Yams

// MARK: - Configuration

/// Configuration loaded from .narya.yaml at the repository root.
struct NaryaConfig: Codable {
    let project: String
    let defaultBootstrap: String?
    let defaultBuildProduct: String?

    enum CodingKeys: String, CodingKey {
        case project
        case defaultBootstrap = "default_bootstrap"
        case defaultBuildProduct = "default_build_product"
    }
}

/// Merged configuration combining project config with bundled defaults.
/// Project config (.narya.yaml) takes precedence over DefaultConfig values.
struct MergedConfig {
    let project: String
    let defaultBootstrap: String
    let defaultBuildProduct: String

    init(projectConfig: NaryaConfig) {
        self.project = projectConfig.project
        self.defaultBootstrap = projectConfig.defaultBootstrap ?? DefaultConfig.defaultBootstrap
        self.defaultBuildProduct = projectConfig.defaultBuildProduct ?? DefaultConfig.defaultBuildProduct
    }
}

/// Result of successful repository validation.
struct RepoInfo {
    let config: MergedConfig
    let root: URL
}

// MARK: - Errors

enum RepoDetectorError: Error, CustomStringConvertible {
    case notInGitRepo
    case markerNotFound
    case invalidMarkerFile(String)
    case unexpectedProject(expected: String, found: String)
    case noValidRemote

    var description: String {
        switch self {
        case .notInGitRepo:
            return """
                Not inside a git repository.
                Run this command from within the firefox-ios directory.
                """
        case .markerNotFound:
            return """
                Not a narya-compatible repository.
                Expected \(Configuration.markerFileName) in project root.
                Are you in the firefox-ios directory?
                """
        case .invalidMarkerFile(let reason):
            return "Invalid \(Configuration.markerFileName): \(reason)"
        case .unexpectedProject(let expected, let found):
            return """
                Unexpected project in \(Configuration.markerFileName).
                Expected: \(expected), found: \(found)
                """
        case .noValidRemote:
            return """
                No git remote pointing to mozilla-mobile/firefox-ios found.
                Expected a remote with URL matching:
                  - git@github.com:mozilla-mobile/firefox-ios.git (SSH)
                  - https://github.com/mozilla-mobile/firefox-ios.git (HTTPS)
                If this is a fork, add an upstream remote:
                  git remote add upstream git@github.com:mozilla-mobile/firefox-ios.git
                """
        }
    }
}

// MARK: - RepoDetector

/// Validates that commands are run from within a valid firefox-ios repository.
///
/// Validation checks:
/// 1. Current directory is inside a git repository
/// 2. Repository root contains .narya.yaml marker file
/// 3. Marker file specifies the expected project ("firefox-ios")
/// 4. At least one git remote points to mozilla-mobile/firefox-ios (warning if missing)
enum RepoDetector {
    static let expectedProject = "firefox-ios"
    static let expectedRemoteIdentifier = "mozilla-mobile/firefox-ios"

    /// Finds the git repository root using `git rev-parse --show-toplevel`.
    /// Returns nil if not inside a git repository.
    static func findGitRoot() -> URL? {
        do {
            let output = try ShellRunner.runAndCapture("git", arguments: ["rev-parse", "--show-toplevel"])
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path)
        } catch {
            return nil
        }
    }

    /// Checks if any git remote points to mozilla-mobile/firefox-ios.
    /// This validates the repository origin, supporting both direct clones and forks
    /// (where upstream points to mozilla-mobile).
    /// - Parameter repoRoot: The root directory of the git repository
    /// - Returns: true if any remote URL contains the expected identifier
    static func hasValidRemote(repoRoot: URL) -> Bool {
        do {
            let output = try ShellRunner.runAndCapture(
                "git",
                arguments: ["remote", "-v"],
                workingDirectory: repoRoot
            )
            return output.contains(expectedRemoteIdentifier)
        } catch {
            return false
        }
    }

    static func loadConfig(from markerPath: URL) throws -> NaryaConfig {
        let contents: String
        do {
            contents = try String(contentsOf: markerPath, encoding: .utf8)
        } catch {
            throw RepoDetectorError.invalidMarkerFile("Could not read file: \(error.localizedDescription)")
        }

        do {
            let config = try YAMLDecoder().decode(NaryaConfig.self, from: contents)
            return config
        } catch {
            throw RepoDetectorError.invalidMarkerFile("Could not parse YAML: \(error.localizedDescription)")
        }
    }

    /// Validates the current directory is within a firefox-ios repository.
    /// Uses git to find the repo root, then checks for .narya.yaml marker.
    /// Returns RepoInfo containing both the config and repo root path.
    static func requireValidRepo() throws -> RepoInfo {
        guard let repoRoot = findGitRoot() else {
            throw RepoDetectorError.notInGitRepo
        }

        let markerPath = repoRoot.appendingPathComponent(Configuration.markerFileName)
        guard FileManager.default.fileExists(atPath: markerPath.path) else {
            throw RepoDetectorError.markerNotFound
        }

        let config = try loadConfig(from: markerPath)

        guard config.project == expectedProject else {
            throw RepoDetectorError.unexpectedProject(
                expected: expectedProject,
                found: config.project
            )
        }

        // Check git remotes for mozilla-mobile/firefox-ios
        // TODO: Decide whether this should be a hard error or warning.
        // Currently a warning to support edge cases (enterprise mirrors, offline dev).
        // Uncomment the throw below to make it a hard error instead.
        if !hasValidRemote(repoRoot: repoRoot) {
            Herald.declare(
                "No git remote pointing to \(expectedRemoteIdentifier) found.\n" +
                "If this is a fork, consider adding an upstream remote:\n" +
                "  git remote add upstream git@github.com:mozilla-mobile/firefox-ios.git",
                asError: true,
                isNewCommand: true
            )
            // throw RepoDetectorError.noValidRemote
        }

        let mergedConfig = MergedConfig(projectConfig: config)
        return RepoInfo(config: mergedConfig, root: repoRoot)
    }
}
