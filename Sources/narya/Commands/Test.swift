// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// MARK: - Test Plan

enum TestPlan: String, ExpressibleByArgument, CaseIterable {
    case unit
    case smoke
    case accessibility
    case performance
    case full  // Focus/Klar only (FullFunctionalTests)

    /// Returns the xctestrun file name prefix for a given product
    func xctestrunPrefix(for product: BuildProduct) -> String? {
        switch (self, product) {
        case (.unit, .firefox):
            return "Fennec_UnitTest"
        case (.unit, .focus):
            return "Focus_UnitTests"
        case (.unit, .klar):
            return "Klar_UnitTests"
        case (.smoke, .firefox):
            return "Fennec_Smoketest"
        case (.smoke, .focus):
            return "Focus_SmokeTest"
        case (.smoke, .klar):
            return "Klar_SmokeTest"
        case (.accessibility, .firefox):
            return "Fennec_AccessibilityTestPlan"
        case (.accessibility, .focus), (.accessibility, .klar):
            return nil  // Not available for Focus/Klar
        case (.performance, .firefox):
            return "Fennec_PerformanceTestPlan"
        case (.performance, .focus), (.performance, .klar):
            return nil  // Not available for Focus/Klar
        case (.full, .focus):
            return "Focus_FullFunctionalTests"
        case (.full, .klar):
            return "Klar_FullFunctionalTests"
        case (.full, .firefox):
            return nil  // Not available for Firefox
        }
    }

    /// Returns the test plan name for xcodebuild -testPlan argument
    func testPlanName(for product: BuildProduct) -> String? {
        switch (self, product) {
        case (.unit, .firefox):
            return "UnitTest"
        case (.unit, .focus):
            return "UnitTests"
        case (.unit, .klar):
            return "UnitTests"
        case (.smoke, .firefox):
            return "Smoketest"
        case (.smoke, .focus):
            return "SmokeTest"
        case (.smoke, .klar):
            return "SmokeTest"
        case (.accessibility, .firefox):
            return "AccessibilityTestPlan"
        case (.accessibility, .focus), (.accessibility, .klar):
            return nil
        case (.performance, .firefox):
            return "PerformanceTestPlan"
        case (.performance, .focus), (.performance, .klar):
            return nil
        case (.full, .focus):
            return "FullFunctionalTests"
        case (.full, .klar):
            return "FullFunctionalTests"
        case (.full, .firefox):
            return nil
        }
    }

    /// Human-readable description
    var displayName: String {
        switch self {
        case .unit: return "Unit Tests"
        case .smoke: return "Smoke Tests"
        case .accessibility: return "Accessibility Tests"
        case .performance: return "Performance Tests"
        case .full: return "Full Functional Tests"
        }
    }
}

// MARK: - Test Errors

enum TestError: Error, CustomStringConvertible {
    case testPlanNotAvailable(plan: TestPlan, product: BuildProduct)
    case testBundleNotFound(path: String)
    case xctestrunNotFound(pattern: String)
    case testsFailed(exitCode: Int32)

    var description: String {
        switch self {
        case .testPlanNotAvailable(let plan, let product):
            return "Test plan '\(plan.rawValue)' is not available for \(product.scheme)."
        case .testBundleNotFound(let path):
            return "Test bundle not found at \(path). Run 'narya test --build-first' to build tests."
        case .xctestrunNotFound(let pattern):
            return "No xctestrun file found matching '\(pattern)'. Run 'narya build --for-testing' first."
        case .testsFailed(let exitCode):
            return "Tests failed with exit code \(exitCode)."
        }
    }
}

// MARK: - Test Command

struct Test: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Run tests for Firefox, Focus, or Klar.",
        discussion: """
            Runs tests using xcodebuild. By default, runs unit tests for the \
            product specified in .narya.yaml, or Firefox if not configured.

            TEST PLAN OPTIONS:
              - unit: Unit tests (default)
              - smoke: Smoke/UI tests
              - accessibility: Accessibility tests (Firefox only)
              - performance: Performance tests (Firefox only)
              - full: Full functional tests (Focus/Klar only)

            SIMULATOR SELECTION:
              Use --sim with a shorthand to select a simulator.
              If not specified, auto-detects a standard iPhone.

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

    @Option(name: [.short, .long], help: "Product to test: firefox, focus, or klar.")
    var product: BuildProduct?

    // MARK: - Test Plan

    @Option(name: .long, help: "Test plan to run: unit, smoke, accessibility, performance, or full.")
    var plan: TestPlan = .unit

    // MARK: - Test Filtering

    @Option(name: .long, help: "Filter tests by name (passed to -only-testing).")
    var filter: String?

    // MARK: - Destination

    @Option(name: .long, help: "Simulator shorthand (e.g., 17, 17pro, air13, pro11, mini).")
    var sim: String?

    @Flag(name: .long, help: "List available iOS simulators.")
    var listSimulators = false

    @Option(name: .long, help: "iOS version for simulator (default: latest).")
    var os: String?

    // MARK: - Build Options

    @Flag(name: .long, help: "Build for testing before running tests.")
    var buildFirst = false

    @Option(name: .long, help: "Custom derived data path.")
    var derivedData: String?

    // MARK: - Test Options

    @Option(name: .long, help: "Maximum test retries on failure (default: 0).")
    var retries: Int = 0

    // MARK: - Workflow Options

    @Flag(name: [.short, .long], help: "Minimize output (show only errors and summary).")
    var quiet = false

    @Flag(name: .long, help: "Print the xcodebuild command instead of running it.")
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
        let testProduct = resolveProduct(from: repo.config)

        // Validate test plan is available for this product
        guard plan.testPlanName(for: testProduct) != nil else {
            throw TestError.testPlanNotAvailable(plan: plan, product: testProduct)
        }

        // Validate project exists
        let projectPath = repo.root.appendingPathComponent(testProduct.projectPath)
        guard FileManager.default.fileExists(atPath: projectPath.path) else {
            throw BuildError.projectNotFound(projectPath.path)
        }

        // Determine simulator
        let simulatorSelection = try resolveSimulator()

        // Handle --expose: print commands instead of running
        if expose {
            printExposedCommands(
                product: testProduct,
                projectPath: projectPath,
                simulator: simulatorSelection
            )
            return
        }

        // Print test info
        if !quiet {
            Herald.declare(" Test Configuration:")
            print("   Product: \(testProduct.scheme)")
            print("   Test Plan: \(plan.displayName)")
            print("   Simulator: \(simulatorSelection.simulator.name) (iOS \(simulatorSelection.runtime.version))")
            if let filter = filter {
                print("   Filter: \(filter)")
            }
            print("")
        }

        // Build for testing if requested
        if buildFirst {
            try performBuildForTesting(
                product: testProduct,
                projectPath: projectPath,
                simulator: simulatorSelection
            )
        }

        // Run tests
        try runTests(
            product: testProduct,
            projectPath: projectPath,
            simulator: simulatorSelection,
            repoRoot: repo.root
        )

        Herald.declare(" Tests passed!")
    }

    // MARK: - Private Methods

    private func resolveProduct(from config: NaryaConfig) -> BuildProduct {
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

    private func performBuildForTesting(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection
    ) throws {
        if !quiet {
            Herald.declare(" Building \(product.scheme) for testing...")
        }

        var args = [
            "-project", projectPath.path,
            "-scheme", product.scheme,
            "-configuration", product.testingConfiguration,
            "-destination", "platform=iOS Simulator,name=\(simulator.simulator.name),OS=\(simulator.runtime.version)",
            "-sdk", "iphonesimulator",
            "COMPILER_INDEX_STORE_ENABLE=NO",
            "CODE_SIGN_IDENTITY=",
            "CODE_SIGNING_REQUIRED=NO",
            "CODE_SIGNING_ALLOWED=NO",
            "build-for-testing"
        ]

        if let derivedData = derivedData {
            args.insert(contentsOf: ["-derivedDataPath", derivedData], at: args.count - 1)
        }

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
            Herald.declare(" Build for testing succeeded!")
            print("")
        }
    }

    private func runTests(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection,
        repoRoot: URL
    ) throws {
        if !quiet {
            Herald.declare(" Running \(plan.displayName) for \(product.scheme)...")
        }

        var args = [
            "-project", projectPath.path,
            "-scheme", product.scheme,
            "-destination", "platform=iOS Simulator,name=\(simulator.simulator.name),OS=\(simulator.runtime.version)",
            "COMPILER_INDEX_STORE_ENABLE=NO",
            "CODE_SIGN_IDENTITY=",
            "CODE_SIGNING_REQUIRED=NO",
            "CODE_SIGNING_ALLOWED=NO"
        ]

        // Add test plan if available
        if let testPlanName = plan.testPlanName(for: product) {
            args += ["-testPlan", testPlanName]
        }

        // Add derived data path
        if let derivedData = derivedData {
            args += ["-derivedDataPath", derivedData]
        }

        // Add test filter
        if let filter = filter {
            args += ["-only-testing:\(filter)"]
        }

        // Add retry count
        if retries > 0 {
            args += ["-retry-tests-on-failure"]
            args += ["-test-iterations", String(retries + 1)]
        }

        // Add test action
        args.append("test")

        if quiet {
            do {
                _ = try ShellRunner.runAndCapture("xcodebuild", arguments: args)
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    throw TestError.testsFailed(exitCode: exitCode)
                }
                throw error
            }
        } else {
            do {
                try ShellRunner.run("xcodebuild", arguments: args)
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    throw TestError.testsFailed(exitCode: exitCode)
                }
                throw error
            }
        }
    }

    // MARK: - Expose Command

    private func printExposedCommands(
        product: BuildProduct,
        projectPath: URL,
        simulator: SimulatorSelection
    ) {
        // Print build-for-testing command if applicable
        if buildFirst {
            var buildArgs = [
                "-project", projectPath.path,
                "-scheme", product.scheme,
                "-configuration", product.testingConfiguration,
                "-destination", "platform=iOS Simulator,name=\(simulator.simulator.name),OS=\(simulator.runtime.version)",
                "-sdk", "iphonesimulator",
                "COMPILER_INDEX_STORE_ENABLE=NO",
                "CODE_SIGN_IDENTITY=",
                "CODE_SIGNING_REQUIRED=NO",
                "CODE_SIGNING_ALLOWED=NO"
            ]

            if let derivedData = derivedData {
                buildArgs += ["-derivedDataPath", derivedData]
            }

            buildArgs.append("build-for-testing")

            print("# Build for testing")
            print(formatCommand("xcodebuild", arguments: buildArgs))
            print("")
        }

        // Print test command
        var testArgs = [
            "-project", projectPath.path,
            "-scheme", product.scheme,
            "-destination", "platform=iOS Simulator,name=\(simulator.simulator.name),OS=\(simulator.runtime.version)",
            "COMPILER_INDEX_STORE_ENABLE=NO",
            "CODE_SIGN_IDENTITY=",
            "CODE_SIGNING_REQUIRED=NO",
            "CODE_SIGNING_ALLOWED=NO"
        ]

        // Add test plan if available
        if let testPlanName = plan.testPlanName(for: product) {
            testArgs += ["-testPlan", testPlanName]
        }

        // Add derived data path
        if let derivedData = derivedData {
            testArgs += ["-derivedDataPath", derivedData]
        }

        // Add test filter
        if let filter = filter {
            testArgs += ["-only-testing:\(filter)"]
        }

        // Add retry count
        if retries > 0 {
            testArgs += ["-retry-tests-on-failure"]
            testArgs += ["-test-iterations", String(retries + 1)]
        }

        testArgs.append("test")

        print("# Run \(plan.displayName)")
        print(formatCommand("xcodebuild", arguments: testArgs))
    }

    private func formatCommand(_ command: String, arguments: [String]) -> String {
        let escapedArgs = arguments.map { arg -> String in
            // Quote arguments that contain spaces or special characters
            if arg.contains(" ") || arg.contains("=") || arg.contains(":") {
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
