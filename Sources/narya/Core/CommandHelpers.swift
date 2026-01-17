// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

// MARK: - Command Helpers

/// Shared utilities for command implementations
enum CommandHelpers {
    // MARK: - Command Formatting

    /// Formats a command and its arguments for display (used by --expose)
    /// Arguments containing spaces, equals signs, or colons are quoted
    static func formatCommand(_ command: String, arguments: [String]) -> String {
        let escapedArgs = arguments.map { arg -> String in
            if arg.contains(" ") || arg.contains("=") || arg.contains(":") {
                return "'\(arg)'"
            }
            return arg
        }
        return "\(command) \(escapedArgs.joined(separator: " \\\n    "))"
    }

    // MARK: - Simulator Utilities

    /// Prints a formatted list of available iOS simulators
    static func printSimulatorList() throws {
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

    /// Resolves simulator from shorthand or returns default
    static func resolveSimulator(shorthand: String?, osVersion: String?) throws -> SimulatorSelection {
        if let shorthand = shorthand {
            return try DeviceShorthand.findSimulator(
                shorthand: shorthand,
                osVersion: osVersion
            )
        } else {
            return try SimulatorManager.findDefaultSimulator()
        }
    }

    // MARK: - Product Resolution

    /// Resolves product from explicit value, config, or default
    static func resolveProduct(explicit: BuildProduct?, config: NaryaConfig) -> BuildProduct {
        // Priority: command line flag > config file > default (firefox)
        if let explicit = explicit {
            return explicit
        }

        if let configDefault = config.defaultBuildProduct,
           let parsed = BuildProduct(rawValue: configDefault) {
            return parsed
        }

        return .firefox
    }

    // MARK: - Package Resolution

    /// Resolves Swift Package dependencies
    static func resolvePackages(projectPath: URL, quiet: Bool) throws {
        if !quiet {
            Herald.declare("Resolving Swift Package dependencies...")
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
            Herald.declare("Package resolution complete.")
            Herald.declare("")
        }
    }

    // MARK: - Clean Utilities

    /// Cleans derived data directory if specified
    static func cleanDerivedData(path: String?, quiet: Bool) throws {
        guard let derivedDataPath = path else { return }

        if !quiet {
            Herald.declare("Cleaning build folder...")
        }

        let ddURL = URL(fileURLWithPath: derivedDataPath)
        if FileManager.default.fileExists(atPath: ddURL.path) {
            try FileManager.default.removeItem(at: ddURL)
        }

        if !quiet {
            Herald.declare("Clean complete.")
        }
    }

    // MARK: - Xcodebuild Execution

    /// Runs xcodebuild with proper error handling for quiet/verbose modes
    static func runXcodebuild(
        arguments: [String],
        quiet: Bool,
        errorTransform: (Int32) -> Error
    ) throws {
        if quiet {
            do {
                _ = try ShellRunner.runAndCapture("xcodebuild", arguments: arguments)
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    throw errorTransform(exitCode)
                }
                throw error
            }
        } else {
            do {
                try ShellRunner.run("xcodebuild", arguments: arguments)
            } catch let error as ShellRunnerError {
                if case .commandFailed(_, let exitCode) = error {
                    throw errorTransform(exitCode)
                }
                throw error
            }
        }
    }
}
