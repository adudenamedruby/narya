// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// MARK: - Run Errors

enum RunError: Error, CustomStringConvertible {
    case appNotFound(String)
    case simulatorOnly

    var description: String {
        switch self {
        case .appNotFound(let path):
            return "💥💍 Built app not found at expected path: \(path). Build may have failed."
        case .simulatorOnly:
            return "💥💍 The 'run' command only supports simulators. Use 'build --device' for device builds."
        }
    }
}

// MARK: - Run Command

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Build and launch Firefox, Focus, or Klar in the simulator.",
        discussion: """
            Builds the specified product and launches it in the iOS Simulator. \
            This is equivalent to running 'narya build' followed by launching \
            the app.

            Examples:
              narya run                      Build and run Firefox
              narya run -p focus             Build and run Focus
              narya run --simulator "iPhone 16 Pro"
            """
    )

    // MARK: - Product Selection

    @Option(name: [.short, .long], help: "Product to build and run: firefox, focus, or klar.")
    var product: BuildProduct?

    // MARK: - Destination

    @Option(name: .long, help: "Simulator name (default: auto-detect latest).")
    var simulator: String?

    @Option(name: .long, help: "iOS version for simulator (default: latest).")
    var os: String?

    // MARK: - Configuration

    @Option(name: .long, help: "Override the build configuration.")
    var configuration: String?

    @Option(name: .long, help: "Custom derived data path.")
    var derivedData: String?

    // MARK: - Workflow Options

    @Flag(name: .long, help: "Skip resolving Swift Package dependencies.")
    var skipResolve = false

    @Flag(name: .long, help: "Clean build folder before building.")
    var clean = false

    @Flag(name: [.short, .long], help: "Minimize output (show only errors and summary).")
    var quiet = false

    // MARK: - Run

    mutating func run() throws {
        // Validate we're in a firefox-ios repository
        let repo = try RepoDetector.requireValidRepo()

        // Check for required tools
        try ToolChecker.requireXcodebuild()
        try ToolChecker.requireSimctl()

        // Determine product
        let buildProduct = resolveProduct(from: repo.config)

        // Validate project exists
        let projectPath = repo.root.appendingPathComponent(buildProduct.projectPath)
        guard FileManager.default.fileExists(atPath: projectPath.path) else {
            throw BuildError.projectNotFound(projectPath.path)
        }

        // Determine simulator
        let simulatorSelection = try resolveSimulator()

        // Print run info
        if !quiet {
            print("💍 Run Configuration:")
            print("   Product: \(buildProduct.scheme)")
            print("   Simulator: \(simulatorSelection.simulator.name) (iOS \(simulatorSelection.runtime.version))")
            print("")
        }

        // Clean if requested
        if clean {
            try performClean()
        }

        // Resolve packages
        if !skipResolve {
            try resolvePackages(projectPath: projectPath)
        }

        // Build
        try performBuild(
            product: buildProduct,
            projectPath: projectPath,
            simulator: simulatorSelection,
            repoRoot: repo.root
        )

        // Boot simulator if needed
        if !quiet {
            print("💍 Booting simulator...")
        }
        try SimulatorManager.bootSimulator(udid: simulatorSelection.simulator.udid)

        // Open Simulator.app
        try SimulatorManager.openSimulatorApp()

        // Find the built app
        let appPath = try findBuiltApp(product: buildProduct, repoRoot: repo.root)

        // Install the app
        if !quiet {
            print("💍 Installing \(buildProduct.scheme)...")
        }
        try SimulatorManager.installApp(path: appPath, simulatorUdid: simulatorSelection.simulator.udid)

        // Launch the app
        if !quiet {
            print("💍 Launching \(buildProduct.scheme)...")
        }
        try SimulatorManager.launchApp(
            bundleId: buildProduct.bundleIdentifier,
            simulatorUdid: simulatorSelection.simulator.udid
        )

        print("💍 \(buildProduct.scheme) is running in \(simulatorSelection.simulator.name)!")
    }

    // MARK: - Private Methods

    private func resolveProduct(from config: NaryaConfig) -> BuildProduct {
        // Priority: command line flag > config file > default (firefox)
        if let product = product {
            return product
        }

        if let configDefault = config.defaultBuildProduct,
           let parsed = BuildProduct(rawValue: configDefault) {
            return parsed
        }

        return .firefox
    }

    private func resolveSimulator() throws -> SimulatorSelection {
        if let simulatorName = simulator {
            // User specified a simulator name
            return try SimulatorManager.findSimulator(name: simulatorName, osVersion: os)
        } else {
            // Auto-detect the best simulator
            return try SimulatorManager.findDefaultSimulator()
        }
    }

    private func performClean() throws {
        if !quiet {
            print("💍 Cleaning build folder...")
        }

        // Clean derived data if a custom path was specified
        if let derivedDataPath = derivedData {
            let ddURL = URL(fileURLWithPath: derivedDataPath)
            if FileManager.default.fileExists(atPath: ddURL.path) {
                try FileManager.default.removeItem(at: ddURL)
            }
        }

        if !quiet {
            print("💍 Clean complete.")
        }
    }

    private func resolvePackages(projectPath: URL) throws {
        if !quiet {
            print("💍 Resolving Swift Package dependencies...")
        }

        let args = [
            "-resolvePackageDependencies",
            "-onlyUsePackageVersionsFromResolvedFile",
            "-project", projectPath.path
        ]

        if quiet {
            _ = try ShellRunner.runAndCapture("xcodebuild", arguments: args)
        } else {
            try ShellRunner.run("xcodebuild", arguments: args)
        }

        if !quiet {
            print("💍 Package resolution complete.")
            print("")
        }
    }

    private func performBuild(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection,
        repoRoot: URL
    ) throws {
        if !quiet {
            print("💍 Building \(product.scheme)...")
        }

        var args = buildXcodebuildArgs(
            product: product,
            projectPath: projectPath,
            simulator: simulator
        )

        // Add build action
        args.append("build")

        if quiet {
            do {
                _ = try ShellRunner.runAndCapture("xcodebuild", arguments: args)
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    throw BuildError.buildFailed(exitCode: exitCode)
                }
                throw error
            }
        } else {
            do {
                try ShellRunner.run("xcodebuild", arguments: args)
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    throw BuildError.buildFailed(exitCode: exitCode)
                }
                throw error
            }
        }

        if !quiet {
            print("💍 Build succeeded!")
            print("")
        }
    }

    private func buildXcodebuildArgs(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection
    ) -> [String] {
        var args: [String] = []

        // Project
        args += ["-project", projectPath.path]

        // Scheme
        args += ["-scheme", product.scheme]

        // Configuration
        let config = configuration ?? product.defaultConfiguration
        args += ["-configuration", config]

        // Destination and SDK
        let destination = "platform=iOS Simulator,name=\(simulator.simulator.name),OS=\(simulator.runtime.version)"
        args += ["-destination", destination]
        args += ["-sdk", "iphonesimulator"]

        // Derived data path
        if let derivedData = derivedData {
            args += ["-derivedDataPath", derivedData]
        }

        // Common build settings
        args += ["COMPILER_INDEX_STORE_ENABLE=NO"]

        // Code signing for simulator builds
        args += ["CODE_SIGN_IDENTITY="]
        args += ["CODE_SIGNING_REQUIRED=NO"]
        args += ["CODE_SIGNING_ALLOWED=NO"]

        return args
    }

    private func findBuiltApp(product: BuildProduct, repoRoot: URL) throws -> String {
        // The app is built to DerivedData
        // Default location: ~/Library/Developer/Xcode/DerivedData/{ProjectName}-{hash}/Build/Products/{Configuration}-iphonesimulator/{AppName}.app

        let config = configuration ?? product.defaultConfiguration
        let fileManager = FileManager.default

        // If custom derived data path was specified
        if let derivedDataPath = derivedData {
            let appPath = "\(derivedDataPath)/Build/Products/\(config)-iphonesimulator/\(product.scheme).app"
            if fileManager.fileExists(atPath: appPath) {
                return appPath
            }
        }

        // Search in default DerivedData location
        let derivedDataBase = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        // Find the project's derived data folder
        let projectName: String
        switch product {
        case .firefox:
            projectName = "Client"
        case .focus, .klar:
            projectName = "Blockzilla"
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: derivedDataBase.path) else {
            throw RunError.appNotFound("Could not read DerivedData directory")
        }

        // Find matching folder (e.g., "Client-abcdef123")
        guard let matchingFolder = contents.first(where: { $0.hasPrefix(projectName + "-") }) else {
            throw RunError.appNotFound("No DerivedData folder found for \(projectName)")
        }

        let appPath = derivedDataBase
            .appendingPathComponent(matchingFolder)
            .appendingPathComponent("Build/Products/\(config)-iphonesimulator/\(product.scheme).app")

        guard fileManager.fileExists(atPath: appPath.path) else {
            throw RunError.appNotFound(appPath.path)
        }

        return appPath.path
    }
}
