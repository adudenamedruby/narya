// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Version {
    struct ListFiles: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list-files",
            abstract: "List all files affected by version commands."
        )

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()
            Herald.declare("Files affected by version commands:", isNewCommand: true)

            var fileCount = 0

            // Source of truth
            Herald.declare("  \(Version.versionFileName) (source of truth)")
            fileCount += 1

            // Static files
            for relativePath in Version.filesToUpdate {
                Herald.declare("  \(relativePath)")
                fileCount += 1
            }

            // Discover extension Info.plists
            let extensionsPath = repo.root.appendingPathComponent(Version.extensionsDir)
            if FileManager.default.fileExists(atPath: extensionsPath.path) {
                let extensionPlists = try discoverExtensionPlists(in: extensionsPath, repoRoot: repo.root)
                for plist in extensionPlists {
                    Herald.declare("  \(plist)")
                    fileCount += 1
                }
            }

            Herald.declare("Listed \(fileCount) files", asConclusion: true)
        }

        private func discoverExtensionPlists(in extensionsDir: URL, repoRoot: URL) throws -> [String] {
            var plists: [String] = []
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
                    let relativePath = file.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
                    plists.append(relativePath)
                }
            }

            return plists.sorted()
        }
    }
}
