// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Yams

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

struct RepoInfo {
    let config: NaryaConfig
    let root: URL
}

enum RepoDetectorError: Error, CustomStringConvertible {
    case notInGitRepo
    case markerNotFound
    case invalidMarkerFile(String)
    case unexpectedProject(expected: String, found: String)

    var description: String {
        switch self {
        case .notInGitRepo:
            return """
                💥💍 Not inside a git repository.
                Run this command from within the firefox-ios directory.
                """
        case .markerNotFound:
            return """
                💥💍 Not a narya-compatible repository.
                Expected \(Configuration.markerFileName) in project root.
                Are you in the firefox-ios directory?
                """
        case .invalidMarkerFile(let reason):
            return "💥💍 Invalid \(Configuration.markerFileName): \(reason)"
        case .unexpectedProject(let expected, let found):
            return """
                💥💍 Unexpected project in \(Configuration.markerFileName).
                Expected: \(expected), found: \(found)
                """
        }
    }
}

enum RepoDetector {
    static let expectedProject = "firefox-ios"

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

        return RepoInfo(config: config, root: repoRoot)
    }
}
