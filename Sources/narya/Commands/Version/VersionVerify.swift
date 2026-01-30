// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Version {
    struct Verify: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Verify version consistency across all config files."
        )

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()
            let expectedVersion = try Version.readVersion(repoRoot: repo.root)
            Herald.declare("Verifying version consistency (expected: \(expectedVersion))...", isNewCommand: true)

            var mismatches: [(file: String, found: String?)] = []

            // Check standard files
            for relativePath in Version.filesToUpdate {
                let filePath = repo.root.appendingPathComponent(relativePath)
                if let mismatch = checkVersionInFile(at: filePath, expected: expectedVersion) {
                    mismatches.append((relativePath, mismatch))
                }
            }

            // Check extension Info.plist files
            let extensionsPath = repo.root.appendingPathComponent(Version.extensionsDir)
            if FileManager.default.fileExists(atPath: extensionsPath.path) {
                let extensionMismatches = try checkExtensionInfoPlists(
                    in: extensionsPath,
                    expected: expectedVersion,
                    repoRoot: repo.root
                )
                mismatches.append(contentsOf: extensionMismatches)
            }

            if mismatches.isEmpty {
                Herald.declare("All files have consistent version \(expectedVersion)", asConclusion: true)
            } else {
                Herald.declare("Version mismatches found:", asError: true, asConclusion: true)
                for mismatch in mismatches {
                    if let found = mismatch.found {
                        Herald.declare("  - \(mismatch.file): found '\(found)'")
                    } else {
                        Herald.declare("  - \(mismatch.file): version not found")
                    }
                }
                throw ExitCode.failure
            }
        }

        private func checkVersionInFile(at url: URL, expected: String) -> String? {
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil // File doesn't exist, skip
            }

            guard let content = try? String(contentsOf: url, encoding: .utf8) else {
                return "unable to read"
            }

            // For plist files, look for CFBundleShortVersionString pattern
            if url.pathExtension == "plist" {
                // Simple check: does the file contain the expected version?
                if content.contains(expected) {
                    return nil // OK
                }
                // Try to extract the actual version
                if let range = content.range(of: "<key>CFBundleShortVersionString</key>") {
                    let afterKey = content[range.upperBound...]
                    if let stringStart = afterKey.range(of: "<string>"),
                       let stringEnd = afterKey.range(of: "</string>") {
                        let versionRange = stringStart.upperBound..<stringEnd.lowerBound
                        return String(afterKey[versionRange])
                    }
                }
                return "version not found in plist"
            }

            // For other files (like bitrise.yml), just check if version is present
            if content.contains(expected) {
                return nil // OK
            }

            return "expected version not found"
        }

        private func checkExtensionInfoPlists(
            in extensionsDir: URL,
            expected: String,
            repoRoot: URL
        ) throws -> [(file: String, found: String?)] {
            var mismatches: [(String, String?)] = []
            let fileManager = FileManager.default

            let extensionDirs = try fileManager.contentsOfDirectory(
                at: extensionsDir,
                includingPropertiesForKeys: [.isDirectoryKey]
            )

            for extDir in extensionDirs {
                let resourceValues = try extDir.resourceValues(forKeys: [.isDirectoryKey])
                guard resourceValues.isDirectory == true else { continue }

                let extContents = try fileManager.contentsOfDirectory(at: extDir, includingPropertiesForKeys: nil)
                for file in extContents where file.lastPathComponent.hasSuffix("Info.plist") {
                    if let mismatch = checkVersionInFile(at: file, expected: expected) {
                        let relativePath = file.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                        mismatches.append((relativePath, mismatch))
                    }
                }
            }

            return mismatches
        }
    }
}
