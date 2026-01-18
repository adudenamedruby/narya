// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Version: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Display or update the version number in the firefox-ios repository.",
        discussion: ""
    )

    // MARK: - Options

    enum BumpType: String, ExpressibleByArgument, CaseIterable {
        case major
        case minor
    }

    @Option(name: [.short, .long], help: "Bump version: 'major' (X.Y -> (X+1).0) or 'minor' (X.Y -> X.(Y+1)).")
    var bump: BumpType?

    @Option(name: .long, help: "Set version explicitly (e.g., '123.4').")
    var set: String?

    @Flag(name: .long, help: "Verify version consistency across all config files.")
    var verify = false

    // MARK: - Constants

    private static let versionFileName = "version.txt"

    private static let filesToUpdate = [
        "firefox-ios/Client/Info.plist",
        "firefox-ios/CredentialProvider/Info.plist",
        "firefox-ios/WidgetKit/Info.plist",
        "bitrise.yml"
    ]

    private static let extensionsDir = "firefox-ios/Extensions"

    mutating func run() throws {
        // Validate we're in a firefox-ios repository
        let repo = try RepoDetector.requireValidRepo()

        // Check for conflicting options
        let optionCount = [bump != nil, set != nil, verify].filter { $0 }.count
        if optionCount > 1 {
            throw ValidationError("Cannot combine --bump, --set, and --verify. Choose one.")
        }

        if let bumpType = bump {
            try runBump(type: bumpType, repoRoot: repo.root)
        } else if let newVersion = set {
            try runSet(version: newVersion, repoRoot: repo.root)
        } else if verify {
            try runVerify(repoRoot: repo.root)
        } else {
            try printVersion(repoRoot: repo.root)
        }
    }

    // MARK: - Print Version

    private func printVersion(repoRoot: URL) throws {
        let version = try readVersion(repoRoot: repoRoot)
        let gitSha = getGitSha(repoRoot: repoRoot)

        if let sha = gitSha {
            Herald.declare("\(version) (\(sha))", isNewCommand: true)
        } else {
            Herald.declare(version, isNewCommand: true)
        }
    }

    private func getGitSha(repoRoot: URL) -> String? {
        do {
            let output = try ShellRunner.runAndCapture(
                "git",
                arguments: ["rev-parse", "--short", "HEAD"],
                workingDirectory: repoRoot
            )
            let sha = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return sha.isEmpty ? nil : sha
        } catch {
            return nil
        }
    }

    // MARK: - Bump Version

    private func runBump(type: BumpType, repoRoot: URL) throws {
        let currentVersion = try readVersion(repoRoot: repoRoot)
        let (majorVersion, minorVersion) = try parseVersion(currentVersion)

        let newMajor: Int
        let newMinor: Int

        switch type {
        case .major:
            newMajor = majorVersion + 1
            newMinor = 0
        case .minor:
            newMajor = majorVersion
            newMinor = minorVersion + 1
        }

        let newVersion = "\(newMajor).\(newMinor)"

        Herald.declare("Bumping version: \(currentVersion) -> \(newVersion)", isNewCommand: true)
        try updateVersionInFiles(from: currentVersion, to: newVersion, repoRoot: repoRoot)
        Herald.declare("Version updated to \(newVersion)", asConclusion: true)
    }

    // MARK: - Set Version

    private func runSet(version newVersion: String, repoRoot: URL) throws {
        // Validate the new version format
        _ = try parseVersion(newVersion)

        let currentVersion = try readVersion(repoRoot: repoRoot)

        if currentVersion == newVersion {
            Herald.declare("Version is already \(newVersion)", isNewCommand: true, asConclusion: true)
            return
        }

        Herald.declare("Setting version: \(currentVersion) -> \(newVersion)", isNewCommand: true)
        try updateVersionInFiles(from: currentVersion, to: newVersion, repoRoot: repoRoot)
        Herald.declare("Version updated to \(newVersion)", asConclusion: true)
    }

    // MARK: - Verify Version

    private func runVerify(repoRoot: URL) throws {
        let expectedVersion = try readVersion(repoRoot: repoRoot)
        Herald.declare("Verifying version consistency (expected: \(expectedVersion))...", isNewCommand: true)

        var mismatches: [(file: String, found: String?)] = []

        // Check standard files
        for relativePath in Self.filesToUpdate {
            let filePath = repoRoot.appendingPathComponent(relativePath)
            if let mismatch = checkVersionInFile(at: filePath, expected: expectedVersion) {
                mismatches.append((relativePath, mismatch))
            }
        }

        // Check extension Info.plist files
        let extensionsPath = repoRoot.appendingPathComponent(Self.extensionsDir)
        if FileManager.default.fileExists(atPath: extensionsPath.path) {
            let extensionMismatches = try checkExtensionInfoPlists(
                in: extensionsPath,
                expected: expectedVersion,
                repoRoot: repoRoot
            )
            mismatches.append(contentsOf: extensionMismatches)
        }

        if mismatches.isEmpty {
            Herald.declare("All files have consistent version \(expectedVersion)", asConclusion: true)
        } else {
            Herald.declare("Version mismatches found:", asError: true, asConclusion: true)
            for mismatch in mismatches {
                if let found = mismatch.found {
                    print("  - \(mismatch.file): found '\(found)'")
                } else {
                    print("  - \(mismatch.file): version not found")
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

    // MARK: - Version File Operations

    private func readVersion(repoRoot: URL) throws -> String {
        let versionFile = repoRoot.appendingPathComponent(Self.versionFileName)
        guard FileManager.default.fileExists(atPath: versionFile.path) else {
            throw ValidationError("version.txt not found at \(versionFile.path)")
        }

        return try String(contentsOf: versionFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseVersion(_ version: String) throws -> (major: Int, minor: Int) {
        let components = version.split(separator: ".")
        guard components.count == 2,
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            throw ValidationError("Invalid version format '\(version)'. Expected X.Y where X and Y are numbers.")
        }
        return (major, minor)
    }

    private func updateVersionInFiles(from currentVersion: String, to newVersion: String, repoRoot: URL) throws {
        // Update specific files
        for relativePath in Self.filesToUpdate {
            let filePath = repoRoot.appendingPathComponent(relativePath)
            try updateVersionInFile(at: filePath, from: currentVersion, to: newVersion)
        }

        // Update extension Info.plist files
        let extensionsPath = repoRoot.appendingPathComponent(Self.extensionsDir)
        if FileManager.default.fileExists(atPath: extensionsPath.path) {
            try updateExtensionInfoPlists(in: extensionsPath, from: currentVersion, to: newVersion)
        }

        // Write new version to version.txt
        let versionFile = repoRoot.appendingPathComponent(Self.versionFileName)
        try (newVersion + "\n").write(to: versionFile, atomically: true, encoding: .utf8)
    }

    private func updateVersionInFile(at url: URL, from currentVersion: String, to newVersion: String) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Herald.declare("Warning: File not found, skipping: \(url.path)", asError: true)
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

            let extContents = try fileManager.contentsOfDirectory(at: extDir, includingPropertiesForKeys: nil)
            for file in extContents where file.lastPathComponent.hasSuffix("Info.plist") {
                try updateVersionInFile(at: file, from: currentVersion, to: newVersion)
            }
        }
    }
}
