// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Update the version number across the firefox-ios repository.",
        discussion: """
            Updates version numbers in Info.plist files, bitrise.yml, and version.txt.
            Versions are in X.Y format where X is major and Y is minor.
            """
    )

    @Flag(name: .long, help: "Increment the major version (X.Y -> (X+1).0).")
    var major = false

    @Flag(name: .long, help: "Increment the minor version (X.Y -> X.(Y+1)).")
    var minor = false

    mutating func run() throws {
        // If neither flag is specified, show help
        guard major || minor else {
            print(Version.helpMessage())
            return
        }

        // Can't specify both
        guard !(major && minor) else {
            throw ValidationError("💥💍 Cannot specify both --major and --minor. Choose one.")
        }

        // Validate we're in a firefox-ios repository and get repo root
        let repo = try RepoDetector.requireValidRepo()

        // Read current version from version.txt
        let versionFile = repo.root.appendingPathComponent("version.txt")
        guard FileManager.default.fileExists(atPath: versionFile.path) else {
            throw ValidationError("💥💍 version.txt not found at \(versionFile.path)")
        }

        let versionString = try String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        let (majorVersion, minorVersion) = try parseVersion(versionString)

        // Calculate new version
        let newMajor: Int
        let newMinor: Int

        if major {
            newMajor = majorVersion + 1
            newMinor = 0
        } else {
            newMajor = majorVersion
            newMinor = minorVersion + 1
        }

        let currentVersion = "\(majorVersion).\(minorVersion)"
        let newVersion = "\(newMajor).\(newMinor)"

        print("💍 Updating version: \(currentVersion) -> \(newVersion)")

        // Update all the files
        try updateVersionInFiles(from: currentVersion, to: newVersion, repoRoot: repo.root)

        print("💍 Version updated to \(newVersion)")
    }

    private func parseVersion(_ version: String) throws -> (major: Int, minor: Int) {
        let components = version.split(separator: ".")
        guard components.count == 2,
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            throw ValidationError("💥💍 Invalid version format '\(version)'. Expected X.Y where X and Y are numbers.")
        }
        return (major, minor)
    }

    private func updateVersionInFiles(from currentVersion: String, to newVersion: String, repoRoot: URL) throws {
        let filesToUpdate = [
            "firefox-ios/Client/Info.plist",
            "firefox-ios/CredentialProvider/Info.plist",
            "firefox-ios/WidgetKit/Info.plist",
            "bitrise.yml"
        ]

        // Update specific files
        for relativePath in filesToUpdate {
            let filePath = repoRoot.appendingPathComponent(relativePath)
            try updateVersionInFile(at: filePath, from: currentVersion, to: newVersion)
        }

        // Update extension Info.plist files (firefox-ios/Extensions/*/*Info.plist)
        let extensionsDir = repoRoot.appendingPathComponent("firefox-ios/Extensions")
        if FileManager.default.fileExists(atPath: extensionsDir.path) {
            try updateExtensionInfoPlists(in: extensionsDir, from: currentVersion, to: newVersion)
        }

        // Write new version to version.txt
        let versionFile = repoRoot.appendingPathComponent("version.txt")
        try (newVersion + "\n").write(to: versionFile, atomically: true, encoding: .utf8)
    }

    private func updateVersionInFile(at url: URL, from currentVersion: String, to newVersion: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("💥💍 Warning: File not found, skipping: \(url.path)")
            return
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        let updatedContent = content.replacingOccurrences(of: currentVersion, with: newVersion)
        try updatedContent.write(to: url, atomically: true, encoding: .utf8)
    }

    private func updateExtensionInfoPlists(in extensionsDir: URL, from currentVersion: String, to newVersion: String) throws {
        let fileManager = FileManager.default
        let extensionDirs = try fileManager.contentsOfDirectory(at: extensionsDir, includingPropertiesForKeys: [.isDirectoryKey])

        for extDir in extensionDirs {
            let resourceValues = try extDir.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues.isDirectory == true else { continue }

            // Look for *Info.plist files in each extension directory
            let extContents = try fileManager.contentsOfDirectory(at: extDir, includingPropertiesForKeys: nil)
            for file in extContents where file.lastPathComponent.hasSuffix("Info.plist") {
                try updateVersionInFile(at: file, from: currentVersion, to: newVersion)
            }
        }
    }
}
