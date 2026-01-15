// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Bootstrap: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Bootstrap the firefox-ios repository for development."
    )

    enum Product: String, ExpressibleByArgument, CaseIterable {
        case firefox
        case focus
    }

    @Option(name: [.short, .long], help: "Product to bootstrap: firefox (default) or focus.")
    var product: Product = .firefox

    @Flag(name: .long, help: "Force a re-build by deleting the build directory. Only applies to firefox.")
    var force = false

    mutating func run() throws {
        // Validate we're in a firefox-ios repository
        _ = try RepoDetector.requireValidRepo()

        try ToolChecker.requireGit()
        try ToolChecker.requireNode()
        try ToolChecker.requireNpm()

        switch product {
        case .firefox:
            try bootstrapFirefox()
        case .focus:
            try bootstrapFocus()
        }
    }

    private func bootstrapFirefox() throws {
        print("Running Firefox bootstrap...")

        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)

        // Force rebuild: delete build directory
        if force {
            let buildDir = currentDir.appendingPathComponent("build")
            if fileManager.fileExists(atPath: buildDir.path) {
                print("Removing build directory...")
                try fileManager.removeItem(at: buildDir)
            }
        }

        // Delete all .venv folders
        print("Cleaning up virtual environments...")
        try deleteVenvFolders(in: currentDir)

        // Download and run nimbus-fml bootstrap script
        print("Setting up Nimbus FML...")
        let nimbusFmlFile = "./firefox-ios/nimbus.fml.yaml"
        try runNimbusBootstrap(
            nimbusFmlFile: nimbusFmlFile,
            extraArgs: ["--directory", "./firefox-ios/bin"]
        )

        // Copy git hooks
        print("Installing git hooks...")
        try installGitHooks(currentDir: currentDir)

        // Run npm install and build
        print("Installing Node.js dependencies...")
        try ShellRunner.run("npm", arguments: ["install"])

        print("Building user scripts...")
        try ShellRunner.run("npm", arguments: ["run", "build"])

        print("Firefox bootstrap complete!")
    }

    private func bootstrapFocus() throws {
        print("Running Focus bootstrap...")

        let fileManager = FileManager.default
        let currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let focusDir = currentDir.appendingPathComponent("focus-ios")

        // Download and run nimbus-fml bootstrap script
        print("Setting up Nimbus FML...")
        let nimbusFmlFile = "./nimbus.fml.yaml"
        try runNimbusBootstrap(
            nimbusFmlFile: nimbusFmlFile,
            workingDirectory: focusDir
        )

        // Clone shavar-prod-lists
        print("Setting up shavar-prod-lists...")
        let shavarCommitHash = "91cf7dd142fc69aabe334a1a6e0091a1db228203"
        let shavarDir = currentDir.appendingPathComponent("shavar-prod-lists")

        // Remove existing shavar-prod-lists if present
        if fileManager.fileExists(atPath: shavarDir.path) {
            try fileManager.removeItem(at: shavarDir)
        }

        try ShellRunner.run("git", arguments: [
            "clone",
            "https://github.com/mozilla-services/shavar-prod-lists.git"
        ])
        try ShellRunner.run("git", arguments: [
            "-C", "shavar-prod-lists",
            "checkout", shavarCommitHash
        ])

        // Run swift in BrowserKit
        print("Building BrowserKit...")
        let browserKitDir = currentDir.appendingPathComponent("BrowserKit")

        // MARK: - Swift retry logic
        // TODO: Investigate why this double-run is needed and remove if unnecessary.
        // The original bootstrap script runs `swift run || true` followed by `swift run`.
        // This suggests the first run may fail but sets up something needed for the second run.
        do {
            try ShellRunner.run("swift", arguments: ["run"], workingDirectory: browserKitDir)
        } catch {
            print("First swift run failed, retrying...")
            try ShellRunner.run("swift", arguments: ["run"], workingDirectory: browserKitDir)
        }

        print("Focus bootstrap complete!")
    }

    private func deleteVenvFolders(in directory: URL) throws {
        let fileManager = FileManager.default
        let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var venvDirs: [URL] = []

        while let url = enumerator?.nextObject() as? URL {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
            if resourceValues.isDirectory == true && url.lastPathComponent == ".venv" {
                venvDirs.append(url)
                enumerator?.skipDescendants()
            }
        }

        for venvDir in venvDirs {
            try fileManager.removeItem(at: venvDir)
        }
    }

    private func runNimbusBootstrap(
        nimbusFmlFile: String,
        extraArgs: [String] = [],
        workingDirectory: URL? = nil
    ) throws {
        let bootstrapURL = "https://raw.githubusercontent.com/mozilla/application-services/main/components/nimbus/ios/scripts/bootstrap.sh"

        // Download the script first (safer than piping directly to bash)
        let tempDir = FileManager.default.temporaryDirectory
        let scriptPath = tempDir.appendingPathComponent("nimbus-bootstrap-\(UUID().uuidString).sh")

        defer {
            try? FileManager.default.removeItem(at: scriptPath)
        }

        try ShellRunner.run("curl", arguments: [
            "--proto", "=https",
            "--tlsv1.2",
            "-sSf",
            "-o", scriptPath.path,
            bootstrapURL
        ])

        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptPath.path
        )

        // Run the script
        let bashArgs = [scriptPath.path] + extraArgs + [nimbusFmlFile]
        try ShellRunner.run("bash", arguments: bashArgs, workingDirectory: workingDirectory)
    }

    private func installGitHooks(currentDir: URL) throws {
        let fileManager = FileManager.default
        let gitHooksSource = currentDir.appendingPathComponent(".githooks")
        let gitHooksDest = currentDir.appendingPathComponent(".git/hooks")

        guard fileManager.fileExists(atPath: gitHooksSource.path) else {
            print("No .githooks directory found, skipping hook installation.")
            return
        }

        let contents = try fileManager.contentsOfDirectory(
            at: gitHooksSource,
            includingPropertiesForKeys: nil
        )

        for sourceFile in contents {
            let destFile = gitHooksDest.appendingPathComponent(sourceFile.lastPathComponent)

            // Remove existing hook if present
            if fileManager.fileExists(atPath: destFile.path) {
                try fileManager.removeItem(at: destFile)
            }

            // Copy the hook
            try fileManager.copyItem(at: sourceFile, to: destFile)

            // Make executable
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destFile.path
            )
        }
    }
}
