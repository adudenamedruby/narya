// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// MARK: - Build Product

enum BuildProduct: String, ExpressibleByArgument, CaseIterable {
    case firefox
    case focus
    case klar

    var scheme: String {
        switch self {
        case .firefox: return "Fennec"
        case .focus: return "Focus"
        case .klar: return "Klar"
        }
    }

    var projectPath: String {
        switch self {
        case .firefox: return "firefox-ios/Client.xcodeproj"
        case .focus, .klar: return "focus-ios/Blockzilla.xcodeproj"
        }
    }

    var defaultConfiguration: String {
        switch self {
        case .firefox: return "Fennec"
        case .focus: return "FocusDebug"
        case .klar: return "KlarDebug"
        }
    }

    var testingConfiguration: String {
        switch self {
        case .firefox: return "Fennec_Testing"
        case .focus: return "FocusDebug"
        case .klar: return "KlarDebug"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .firefox: return "org.mozilla.ios.Fennec"
        case .focus: return "org.mozilla.ios.Focus"
        case .klar: return "org.mozilla.ios.Klar"
        }
    }
}

// MARK: - Build Errors

enum BuildError: Error, CustomStringConvertible {
    case projectNotFound(String)
    case buildFailed(exitCode: Int32)

    var description: String {
        switch self {
        case .projectNotFound(let path):
            return "💥💍 Project not found at \(path). Run 'narya setup' first."
        case .buildFailed(let exitCode):
            return "💥💍 Build failed with exit code \(exitCode)."
        }
    }
}

// MARK: - Build Command

struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build Firefox, Focus, or Klar for development.",
        discussion: """
            Builds the specified product using xcodebuild. By default, builds \
            Firefox for the iOS Simulator in debug configuration.

            The simulator is auto-detected to use the latest iOS version with \
            a standard iPhone model (non-Pro, non-Max).

            Examples:
              narya build                    Build Firefox for simulator
              narya build -p focus           Build Focus for simulator
              narya build --for-testing      Build Firefox for testing
              narya build --device           Build Firefox for device
              narya build --list-simulators  Show available simulators
            """
    )

    // MARK: - Product Selection

    @Option(name: [.short, .long], help: "Product to build: firefox, focus, or klar.")
    var product: BuildProduct?

    // MARK: - Build Type

    @Flag(name: .long, help: "Build for testing (generates xctestrun bundle).")
    var forTesting = false

    // MARK: - Destination

    @Flag(name: .long, help: "Build for a connected device instead of simulator.")
    var device = false

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

    // MARK: - Info

    @Flag(name: .long, help: "List available iOS simulators.")
    var listSimulators = false

    // MARK: - Run

    mutating func run() throws {
        // Handle --list-simulators separately (doesn't need repo validation)
        if listSimulators {
            try printSimulatorList()
            return
        }

        // Validate we're in a firefox-ios repository
        let repo = try RepoDetector.requireValidRepo()

        // Check for required tools
        try ToolChecker.requireXcodebuild()

        // Determine product
        let buildProduct = resolveProduct(from: repo.config)

        // Validate project exists
        let projectPath = repo.root.appendingPathComponent(buildProduct.projectPath)
        guard FileManager.default.fileExists(atPath: projectPath.path) else {
            throw BuildError.projectNotFound(projectPath.path)
        }

        // Determine simulator (if not building for device)
        var simulatorSelection: SimulatorSelection?
        if !device {
            try ToolChecker.requireSimctl()
            simulatorSelection = try resolveSimulator()
        }

        // Print build info
        printBuildInfo(product: buildProduct, simulator: simulatorSelection, repoRoot: repo.root)

        // Clean if requested
        if clean {
            try performClean(repoRoot: repo.root)
        }

        // Resolve packages
        if !skipResolve {
            try resolvePackages(projectPath: projectPath)
        }

        // Build
        try performBuild(
            product: buildProduct,
            projectPath: projectPath,
            simulator: simulatorSelection
        )

        print("💍 Build succeeded!")
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

    private func printBuildInfo(product: BuildProduct, simulator: SimulatorSelection?, repoRoot: URL) {
        if quiet { return }

        print("💍 Build Configuration:")
        print("   Product: \(product.scheme)")
        print("   Project: \(product.projectPath)")

        let config = configuration ?? (forTesting ? product.testingConfiguration : product.defaultConfiguration)
        print("   Configuration: \(config)")

        if let sim = simulator {
            print("   Simulator: \(sim.simulator.name) (iOS \(sim.runtime.version))")
        } else if device {
            print("   Destination: Connected device")
        }

        if forTesting {
            print("   Build Type: build-for-testing")
        }

        print("")
    }

    private func performClean(repoRoot: URL) throws {
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
        simulator: SimulatorSelection?
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
        args.append(forTesting ? "build-for-testing" : "build")

        if quiet {
            do {
                _ = try ShellRunner.runAndCapture("xcodebuild", arguments: args)
            } catch let error as ShellRunnerError {
                // Re-throw with more context
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
    }

    private func buildXcodebuildArgs(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection?
    ) -> [String] {
        var args: [String] = []

        // Project
        args += ["-project", projectPath.path]

        // Scheme
        args += ["-scheme", product.scheme]

        // Configuration
        let config = configuration ?? (forTesting ? product.testingConfiguration : product.defaultConfiguration)
        args += ["-configuration", config]

        // Destination and SDK
        if device {
            args += ["-destination", "generic/platform=iOS"]
            args += ["-sdk", "iphoneos"]
        } else if let sim = simulator {
            let destination = "platform=iOS Simulator,name=\(sim.simulator.name),OS=\(sim.runtime.version)"
            args += ["-destination", destination]
            args += ["-sdk", "iphonesimulator"]
        }

        // Derived data path
        if let derivedData = derivedData {
            args += ["-derivedDataPath", derivedData]
        }

        // Common build settings (from bitrise patterns)
        args += ["COMPILER_INDEX_STORE_ENABLE=NO"]

        // Code signing for simulator builds
        if !device {
            args += ["CODE_SIGN_IDENTITY="]
            args += ["CODE_SIGNING_REQUIRED=NO"]
            args += ["CODE_SIGNING_ALLOWED=NO"]
        }

        return args
    }

    // MARK: - List Simulators

    private func printSimulatorList() throws {
        try ToolChecker.requireSimctl()

        let simulatorsByRuntime = try SimulatorManager.listSimulators()

        guard !simulatorsByRuntime.isEmpty else {
            print("💍 No iOS simulators found. Please install simulators via Xcode.")
            return
        }

        print("💍 Available iOS Simulators:")
        print("")

        for (runtime, devices) in simulatorsByRuntime {
            print("\(runtime.name):")

            for device in devices {
                let bootedIndicator = device.isBooted ? " (Booted)" : ""
                let udidShort = String(device.udid.prefix(8)) + "..."
                print("  \(device.name)\(bootedIndicator)".padding(toLength: 35, withPad: " ", startingAt: 0) + udidShort)
            }

            print("")
        }

        // Show default
        do {
            let defaultSim = try SimulatorManager.findDefaultSimulator()
            print("💍 Default: \(defaultSim.simulator.name) (iOS \(defaultSim.runtime.version))")
        } catch {
            // Ignore errors finding default
        }
    }
}
