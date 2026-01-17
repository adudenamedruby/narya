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
            return "Built app not found at expected path: \(path). Build may have failed."
        case .simulatorOnly:
            return "The 'run' command only supports simulators. Use 'build --device' for device builds."
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

            SIMULATOR SHORTHAND PATTERNS:
              17, 16e, 17pro, 17max    iPhone 17 / 16e / 17 Pro / 17 Pro Max
              air, se                  iPhone Air / SE
              air11, air13             iPad Air 11-inch / 13-inch
              pro11, pro13             iPad Pro 11-inch / 13-inch
              mini                     iPad mini

            The latest iOS version is used unless --os is specified.
            """
    )

    // MARK: - Product Selection

    @Option(name: [.short, .long], help: "Product to build and run: firefox, focus, or klar.")
    var product: BuildProduct?

    // MARK: - Destination

    @Option(name: .long, help: "Simulator shorthand (e.g., 17, 17pro, air13, pro11, mini).")
    var sim: String?

    @Flag(name: .long, help: "List available iOS simulators.")
    var listSimulators = false

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

    @Flag(name: .long, help: "Print the commands instead of running them.")
    var expose = false

    // MARK: - Run

    mutating func run() throws {
        // Handle --list-simulators separately (doesn't need repo validation)
        if listSimulators {
            Herald.reset()
            try printSimulatorList()
            return
        }

        Herald.reset()

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

        // Handle --expose: print commands instead of running
        if expose {
            printExposedCommands(
                product: buildProduct,
                projectPath: projectPath,
                simulator: simulatorSelection
            )
            return
        }

        // Print run info
        if !quiet {
            Herald.declare(" Run Configuration:")
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
            Herald.declare(" Booting simulator...")
        }
        try SimulatorManager.bootSimulator(udid: simulatorSelection.simulator.udid)

        // Open Simulator.app
        try SimulatorManager.openSimulatorApp()

        // Find the built app
        let appPath = try findBuiltApp(product: buildProduct, repoRoot: repo.root)

        // Install the app
        if !quiet {
            Herald.declare(" Installing \(buildProduct.scheme)...")
        }
        try SimulatorManager.installApp(path: appPath, simulatorUdid: simulatorSelection.simulator.udid)

        // Launch the app
        if !quiet {
            Herald.declare(" Launching \(buildProduct.scheme)...")
        }
        try SimulatorManager.launchApp(
            bundleId: buildProduct.bundleIdentifier,
            simulatorUdid: simulatorSelection.simulator.udid
        )

        Herald.declare(" \(buildProduct.scheme) is running in \(simulatorSelection.simulator.name)!")
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
        if let shorthand = sim {
            // User specified a simulator shorthand
            return try DeviceShorthand.findSimulator(
                shorthand: shorthand,
                osVersion: os
            )
        } else {
            // Auto-detect the best simulator (default iPhone behavior)
            return try SimulatorManager.findDefaultSimulator()
        }
    }

    private func performClean() throws {
        if !quiet {
            Herald.declare(" Cleaning build folder...")
        }

        // Clean derived data if a custom path was specified
        if let derivedDataPath = derivedData {
            let ddURL = URL(fileURLWithPath: derivedDataPath)
            if FileManager.default.fileExists(atPath: ddURL.path) {
                try FileManager.default.removeItem(at: ddURL)
            }
        }

        if !quiet {
            Herald.declare(" Clean complete.")
        }
    }

    private func resolvePackages(projectPath: URL) throws {
        if !quiet {
            Herald.declare(" Resolving Swift Package dependencies...")
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
            Herald.declare(" Package resolution complete.")
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
            Herald.declare(" Building \(product.scheme)...")
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
            Herald.declare(" Build succeeded!")
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

    // MARK: - Expose Command

    private func printExposedCommands(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection
    ) {
        // Print resolve command if applicable
        if !skipResolve {
            let resolveArgs = [
                "-resolvePackageDependencies",
                "-onlyUsePackageVersionsFromResolvedFile",
                "-project", projectPath.path
            ]
            print("# Resolve Swift Package dependencies")
            print(formatCommand("xcodebuild", arguments: resolveArgs))
            print("")
        }

        // Print build command
        var buildArgs = buildXcodebuildArgs(
            product: product,
            projectPath: projectPath,
            simulator: simulator
        )
        buildArgs.append("build")

        print("# Build \(product.scheme)")
        print(formatCommand("xcodebuild", arguments: buildArgs))
        print("")

        // Print simctl commands
        print("# Boot simulator")
        print("xcrun simctl boot '\(simulator.simulator.udid)'")
        print("")

        print("# Open Simulator.app")
        print("open -a Simulator")
        print("")

        // Note: We can't know the exact app path without building
        let config = configuration ?? product.defaultConfiguration
        let appPathExample = "~/Library/Developer/Xcode/DerivedData/.../Build/Products/\(config)-iphonesimulator/\(product.scheme).app"

        print("# Install app (path determined after build)")
        print("xcrun simctl install '\(simulator.simulator.udid)' '\(appPathExample)'")
        print("")

        print("# Launch app")
        print("xcrun simctl launch '\(simulator.simulator.udid)' '\(product.bundleIdentifier)'")
    }

    private func formatCommand(_ command: String, arguments: [String]) -> String {
        let escapedArgs = arguments.map { arg -> String in
            // Quote arguments that contain spaces or special characters
            if arg.contains(" ") || arg.contains("=") {
                return "'\(arg)'"
            }
            return arg
        }
        return "\(command) \(escapedArgs.joined(separator: " \\\n    "))"
    }

    // MARK: - List Simulators

    private func printSimulatorList() throws {
        try ToolChecker.requireSimctl()

        let simulatorsByRuntime = try SimulatorManager.listSimulators()

        guard !simulatorsByRuntime.isEmpty else {
            Herald.declare("No iOS simulators found. Please install simulators via Xcode.")
            return
        }

        Herald.declare("Available iOS Simulators:")
        Herald.declare("")

        for (runtime, devices) in simulatorsByRuntime {
            Herald.declare("\(runtime.name):")

            for device in devices {
                let bootedIndicator = device.isBooted ? " (Booted)" : ""
                let udidShort = String(device.udid.prefix(8)) + "..."
                Herald.declare("  \(device.name)\(bootedIndicator)".padding(toLength: 35, withPad: " ", startingAt: 0) + udidShort)
            }

            Herald.declare("")
        }

        // Show default
        do {
            let defaultSim = try SimulatorManager.findDefaultSimulator()
            Herald.declare("Default: \(defaultSim.simulator.name) (iOS \(defaultSim.runtime.version))")
        } catch {
            // Ignore errors finding default
        }
    }
}
