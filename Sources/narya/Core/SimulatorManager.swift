// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

// MARK: - Data Models

/// Represents an iOS simulator device
struct Simulator: Codable {
    let udid: String
    let name: String
    let state: String
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case udid
        case name
        case state
        case isAvailable
    }

    var isBooted: Bool {
        state == "Booted"
    }
}

/// Represents a simulator runtime (iOS version)
struct SimulatorRuntime: Codable {
    let identifier: String
    let name: String
    let version: String
    let isAvailable: Bool

    enum CodingKeys: String, CodingKey {
        case identifier
        case name
        case version
        case isAvailable
    }
}

/// Result of finding a simulator
struct SimulatorSelection {
    let simulator: Simulator
    let runtime: SimulatorRuntime
}

/// Type alias for simulator list grouped by runtime
typealias SimulatorsByRuntime = [(runtime: SimulatorRuntime, devices: [Simulator])]

// MARK: - Errors

enum SimulatorManagerError: Error, CustomStringConvertible {
    case simctlFailed(reason: String, underlyingError: Error?)
    case noSimulatorsFound
    case simulatorNotFound(String)
    case parseError(reason: String, underlyingError: Error?)
    case bootFailed(reason: String, underlyingError: Error?)
    case installFailed(reason: String, underlyingError: Error?)
    case launchFailed(reason: String, underlyingError: Error?)

    var description: String {
        switch self {
        case .simctlFailed(let reason, let underlyingError):
            var message = "simctl command failed: \(reason)"
            if let error = underlyingError {
                message += " (\(error.localizedDescription))"
            }
            return message
        case .noSimulatorsFound:
            return "No iOS simulators found. Please install simulators via Xcode."
        case .simulatorNotFound(let name):
            return "Simulator '\(name)' not found. Use --list-sims to see available options."
        case .parseError(let reason, let underlyingError):
            var message = "Failed to parse simulator list: \(reason)"
            if let error = underlyingError {
                message += " (\(error.localizedDescription))"
            }
            return message
        case .bootFailed(let reason, let underlyingError):
            var message = "Failed to boot simulator: \(reason)"
            if let error = underlyingError {
                message += " (\(error.localizedDescription))"
            }
            return message
        case .installFailed(let reason, let underlyingError):
            var message = "Failed to install app: \(reason)"
            if let error = underlyingError {
                message += " (\(error.localizedDescription))"
            }
            return message
        case .launchFailed(let reason, let underlyingError):
            var message = "Failed to launch app: \(reason)"
            if let error = underlyingError {
                message += " (\(error.localizedDescription))"
            }
            return message
        }
    }
}

// MARK: - SimulatorManager

enum SimulatorManager {
    // MARK: - Constants

    /// Timeout for simctl commands in seconds.
    /// simctl can hang indefinitely if CoreSimulator service is stuck.
    private static let simctlTimeout: TimeInterval = 15

    // MARK: - simctl JSON Response Structures

    private struct SimctlDevicesResponse: Codable {
        let devices: [String: [SimctlDevice]]
    }

    private struct SimctlDevice: Codable {
        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool
    }

    private struct SimctlRuntimesResponse: Codable {
        let runtimes: [SimctlRuntime]
    }

    private struct SimctlRuntime: Codable {
        let identifier: String
        let name: String
        let version: String
        let isAvailable: Bool
    }

    // MARK: - Public Methods

    /// Lists all available iOS simulators grouped by runtime
    static func listSimulators() throws -> [(runtime: SimulatorRuntime, devices: [Simulator])] {
        let runtimes = try getRuntimes()
        let devicesByRuntime = try getDevices()

        var result: [(runtime: SimulatorRuntime, devices: [Simulator])] = []

        // Sort runtimes by version (newest first)
        let sortedRuntimes = runtimes
            .filter { $0.isAvailable && $0.name.contains("iOS") }
            .sorted { compareVersions($0.version, $1.version) == .orderedDescending }

        for runtime in sortedRuntimes {
            if let devices = devicesByRuntime[runtime.identifier] {
                let availableDevices = devices.filter { $0.isAvailable }
                if !availableDevices.isEmpty {
                    result.append((runtime: runtime, devices: availableDevices))
                }
            }
        }

        return result
    }

    /// Finds the best default simulator (latest iOS, numbered base iPhone preferred)
    /// This overload fetches the simulator list. Use `findDefaultSimulator(from:)` if you already have the list.
    static func findDefaultSimulator() throws -> SimulatorSelection {
        let simulatorsByRuntime = try listSimulators()
        return try findDefaultSimulator(from: simulatorsByRuntime)
    }

    /// Finds the best default simulator from a pre-fetched simulator list
    /// Use this to avoid redundant simctl calls when you already have the list.
    static func findDefaultSimulator(from simulatorsByRuntime: SimulatorsByRuntime) throws -> SimulatorSelection {
        guard !simulatorsByRuntime.isEmpty else {
            throw SimulatorManagerError.noSimulatorsFound
        }

        // Go through runtimes from newest to oldest
        for (runtime, devices) in simulatorsByRuntime {
            // First priority: numbered base iPhone (e.g., "iPhone 17", "iPhone 16")
            let numberedDevices = devices.filter { isNumberedBaseIPhone($0.name) }
            if let device = numberedDevices.sorted(by: { extractIPhoneNumber($0.name) > extractIPhoneNumber($1.name) }).first {
                return SimulatorSelection(simulator: device, runtime: runtime)
            }

            // Second priority: any base model iPhone (includes Air, SE, etc.)
            let baseDevices = devices.filter { isPreferredSimulator($0.name) }
            if let device = baseDevices.first {
                return SimulatorSelection(simulator: device, runtime: runtime)
            }

            // Third priority: any iPhone
            let iPhones = devices.filter { $0.name.hasPrefix("iPhone") }
            if let device = iPhones.first {
                return SimulatorSelection(simulator: device, runtime: runtime)
            }
        }

        // Last resort: return the first available device
        if let first = simulatorsByRuntime.first, let device = first.devices.first {
            return SimulatorSelection(simulator: device, runtime: first.runtime)
        }

        throw SimulatorManagerError.noSimulatorsFound
    }

    /// Finds a simulator by name, optionally filtering by iOS version
    static func findSimulator(name: String, osVersion: String? = nil) throws -> SimulatorSelection {
        let simulatorsByRuntime = try listSimulators()

        // If OS version specified, filter to that runtime
        let filteredRuntimes: [(runtime: SimulatorRuntime, devices: [Simulator])]
        if let osVersion = osVersion {
            filteredRuntimes = simulatorsByRuntime.filter { $0.runtime.version.hasPrefix(osVersion) }
        } else {
            filteredRuntimes = simulatorsByRuntime
        }

        // Search for the simulator by name
        for (runtime, devices) in filteredRuntimes {
            if let device = devices.first(where: { $0.name == name }) {
                return SimulatorSelection(simulator: device, runtime: runtime)
            }
        }

        throw SimulatorManagerError.simulatorNotFound(name)
    }

    /// Boots a simulator if not already booted
    static func bootSimulator(udid: String) throws {
        // Check if already booted
        let devicesByRuntime = try getDevices()
        for (_, devices) in devicesByRuntime {
            if let device = devices.first(where: { $0.udid == udid }), device.isBooted {
                // Already booted
                return
            }
        }

        // Boot the simulator
        do {
            try ShellRunner.run("xcrun", arguments: ["simctl", "boot", udid])
        } catch {
            Logger.error("Simulator boot failed for UDID: \(udid)", error: error)
            throw SimulatorManagerError.bootFailed(reason: "simctl boot failed", underlyingError: error)
        }
    }

    /// Installs an app on a simulator
    static func installApp(path: String, simulatorUdid: String) throws {
        do {
            try ShellRunner.run("xcrun", arguments: ["simctl", "install", simulatorUdid, path])
        } catch {
            Logger.error("App install failed for path: \(path)", error: error)
            throw SimulatorManagerError.installFailed(reason: "simctl install failed", underlyingError: error)
        }
    }

    /// Launches an app on a simulator
    static func launchApp(bundleId: String, simulatorUdid: String) throws {
        do {
            try ShellRunner.run("xcrun", arguments: ["simctl", "launch", simulatorUdid, bundleId])
        } catch {
            Logger.error("App launch failed for bundle ID: \(bundleId)", error: error)
            throw SimulatorManagerError.launchFailed(reason: "simctl launch failed", underlyingError: error)
        }
    }

    /// Opens the Simulator.app
    static func openSimulatorApp() throws {
        try ShellRunner.run("open", arguments: ["-a", "Simulator"])
    }

    // MARK: - Simulator Selection Logic

    /// Determines if a simulator is a numbered base iPhone (e.g., "iPhone 17", "iPhone 16")
    /// These are preferred over special models like iPhone Air or iPhone SE
    static func isNumberedBaseIPhone(_ name: String) -> Bool {
        // Pattern: "iPhone <number>" exactly (not Pro, Plus, etc.)
        // Examples: "iPhone 17", "iPhone 16" - but NOT "iPhone 17 Pro" or "iPhone 16e"
        let pattern = #"^iPhone \d+$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }
        let range = NSRange(name.startIndex..., in: name)
        return regex.firstMatch(in: name, range: range) != nil
    }

    /// Extracts the model number from an iPhone name (e.g., "iPhone 17" -> 17)
    static func extractIPhoneNumber(_ name: String) -> Int {
        let pattern = #"^iPhone (\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
              let numberRange = Range(match.range(at: 1), in: name),
              let number = Int(name[numberRange]) else {
            return 0
        }
        return number
    }

    /// Determines if a simulator name is a "preferred" base model (non-Pro, non-Max, etc.)
    static func isPreferredSimulator(_ name: String) -> Bool {
        guard name.hasPrefix("iPhone") else { return false }

        // Exclude Pro, Pro Max, Plus, mini, SE variants
        let excludedSuffixes = ["Pro", "Pro Max", "Plus", "mini"]
        let excludedContains = ["SE"]

        for suffix in excludedSuffixes {
            if name.hasSuffix(suffix) {
                return false
            }
        }

        for substring in excludedContains {
            if name.contains(substring) {
                return false
            }
        }

        return true
    }

    // MARK: - Private Helpers

    private static func getRuntimes() throws -> [SimulatorRuntime] {
        Logger.debug("Fetching simulator runtimes via simctl")
        let output = try runSimctlWithFileFlow(command: "runtimes")

        guard let data = output.data(using: .utf8) else {
            throw SimulatorManagerError.parseError(reason: "Invalid output encoding", underlyingError: nil)
        }

        do {
            let response = try JSONDecoder().decode(SimctlRuntimesResponse.self, from: data)
            Logger.debug("Found \(response.runtimes.count) runtimes")
            return response.runtimes.map { runtime in
                SimulatorRuntime(
                    identifier: runtime.identifier,
                    name: runtime.name,
                    version: runtime.version,
                    isAvailable: runtime.isAvailable
                )
            }
        } catch {
            Logger.error("Failed to parse runtimes JSON", error: error)
            throw SimulatorManagerError.parseError(reason: "JSON decoding failed", underlyingError: error)
        }
    }

    private static func getDevices() throws -> [String: [Simulator]] {
        Logger.debug("Fetching simulator devices via simctl")
        let output = try runSimctlWithFileFlow(command: "devices")

        guard let data = output.data(using: .utf8) else {
            throw SimulatorManagerError.parseError(reason: "Invalid output encoding", underlyingError: nil)
        }

        do {
            let response = try JSONDecoder().decode(SimctlDevicesResponse.self, from: data)
            var result: [String: [Simulator]] = [:]

            for (runtimeId, devices) in response.devices {
                result[runtimeId] = devices.map { device in
                    Simulator(
                        udid: device.udid,
                        name: device.name,
                        state: device.state,
                        isAvailable: device.isAvailable
                    )
                }
            }

            Logger.debug("Found \(result.count) runtime groups with devices")
            return result
        } catch {
            Logger.error("Failed to parse devices JSON", error: error)
            throw SimulatorManagerError.parseError(reason: "JSON decoding failed", underlyingError: error)
        }
    }

    /// Runs a simctl list command by writing JSON output to a temp file, then reading it.
    /// This works around potential issues with large output causing pipe buffer hangs.
    /// - Parameter command: The simctl list subcommand (e.g., "devices" or "runtimes")
    /// - Returns: The JSON content as a string
    private static func runSimctlWithFileFlow(command: String) throws -> String {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("narya_simctl_\(command)_\(UUID().uuidString).json")

        Logger.debug("Writing simctl \(command) output to: \(tempFile.path) (timeout: \(simctlTimeout)s)")

        // Run the command with shell redirection to the temp file
        // Use runAndCapture for timeout support - stdout is empty since output goes to file
        let shellCommand = "xcrun simctl list \(command) --json > '\(tempFile.path)'"
        do {
            _ = try ShellRunner.runAndCapture("bash", arguments: ["-c", shellCommand], timeout: simctlTimeout)
        } catch let error as ShellRunnerError {
            // Clean up temp file if it was created
            try? FileManager.default.removeItem(at: tempFile)
            if case .timedOut = error {
                Logger.error("simctl list \(command) timed out", error: error)
                throw SimulatorManagerError.simctlFailed(
                    reason: "simctl timed out. The CoreSimulator service may be stuck. Try: killall -9 com.apple.CoreSimulator.CoreSimulatorService",
                    underlyingError: error
                )
            }
            Logger.error("Failed to run simctl \(command)", error: error)
            throw SimulatorManagerError.simctlFailed(
                reason: "Failed to list \(command)",
                underlyingError: error
            )
        } catch {
            // Clean up temp file if it was created
            try? FileManager.default.removeItem(at: tempFile)
            Logger.error("Failed to run simctl \(command)", error: error)
            throw SimulatorManagerError.simctlFailed(
                reason: "Failed to list \(command)",
                underlyingError: error
            )
        }

        // Read the file contents
        let output: String
        do {
            output = try String(contentsOf: tempFile, encoding: .utf8)
            Logger.debug("Read \(output.count) characters from temp file")
        } catch {
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempFile)
            Logger.error("Failed to read simctl \(command) output file", error: error)
            throw SimulatorManagerError.parseError(
                reason: "Failed to read temp file",
                underlyingError: error
            )
        }

        // Clean up temp file
        do {
            try FileManager.default.removeItem(at: tempFile)
            Logger.debug("Cleaned up temp file")
        } catch {
            Logger.debug("Warning: Could not delete temp file: \(error)")
            // Don't throw - we have the data we need
        }

        return output
    }

    private static func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let components1 = v1.split(separator: ".").compactMap { Int($0) }
        let components2 = v2.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(components1.count, components2.count)

        for i in 0..<maxLength {
            let c1 = i < components1.count ? components1[i] : 0
            let c2 = i < components2.count ? components2[i] : 0

            if c1 < c2 {
                return .orderedAscending
            } else if c1 > c2 {
                return .orderedDescending
            }
        }

        return .orderedSame
    }
}
