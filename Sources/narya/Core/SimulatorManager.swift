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

// MARK: - Errors

enum SimulatorManagerError: Error, CustomStringConvertible {
    case simctlFailed(String)
    case noSimulatorsFound
    case simulatorNotFound(String)
    case parseError(String)
    case bootFailed(String)
    case installFailed(String)
    case launchFailed(String)

    var description: String {
        switch self {
        case .simctlFailed(let reason):
            return "simctl command failed: \(reason)"
        case .noSimulatorsFound:
            return "No iOS simulators found. Please install simulators via Xcode."
        case .simulatorNotFound(let name):
            return "Simulator '\(name)' not found. Use --list-simulators to see available options."
        case .parseError(let reason):
            return "Failed to parse simulator list: \(reason)"
        case .bootFailed(let reason):
            return "Failed to boot simulator: \(reason)"
        case .installFailed(let reason):
            return "Failed to install app: \(reason)"
        case .launchFailed(let reason):
            return "Failed to launch app: \(reason)"
        }
    }
}

// MARK: - SimulatorManager

enum SimulatorManager {
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

    /// Finds the best default simulator (latest iOS, non-Pro/non-Max iPhone)
    static func findDefaultSimulator() throws -> SimulatorSelection {
        let simulatorsByRuntime = try listSimulators()

        guard !simulatorsByRuntime.isEmpty else {
            throw SimulatorManagerError.noSimulatorsFound
        }

        // Go through runtimes from newest to oldest
        for (runtime, devices) in simulatorsByRuntime {
            // First, try to find a preferred (base model) iPhone
            let preferredDevices = devices.filter { isPreferredSimulator($0.name) }
            if let device = preferredDevices.first {
                return SimulatorSelection(simulator: device, runtime: runtime)
            }

            // If no preferred device, fall back to any iPhone
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
            throw SimulatorManagerError.bootFailed(String(describing: error))
        }
    }

    /// Installs an app on a simulator
    static func installApp(path: String, simulatorUdid: String) throws {
        do {
            try ShellRunner.run("xcrun", arguments: ["simctl", "install", simulatorUdid, path])
        } catch {
            throw SimulatorManagerError.installFailed(String(describing: error))
        }
    }

    /// Launches an app on a simulator
    static func launchApp(bundleId: String, simulatorUdid: String) throws {
        do {
            try ShellRunner.run("xcrun", arguments: ["simctl", "launch", simulatorUdid, bundleId])
        } catch {
            throw SimulatorManagerError.launchFailed(String(describing: error))
        }
    }

    /// Opens the Simulator.app
    static func openSimulatorApp() throws {
        try ShellRunner.run("open", arguments: ["-a", "Simulator"])
    }

    // MARK: - Simulator Selection Logic

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
        let output: String
        do {
            output = try ShellRunner.runAndCapture("xcrun", arguments: ["simctl", "list", "runtimes", "--json"])
        } catch {
            throw SimulatorManagerError.simctlFailed(String(describing: error))
        }

        guard let data = output.data(using: .utf8) else {
            throw SimulatorManagerError.parseError("Invalid output encoding")
        }

        do {
            let response = try JSONDecoder().decode(SimctlRuntimesResponse.self, from: data)
            return response.runtimes.map { runtime in
                SimulatorRuntime(
                    identifier: runtime.identifier,
                    name: runtime.name,
                    version: runtime.version,
                    isAvailable: runtime.isAvailable
                )
            }
        } catch {
            throw SimulatorManagerError.parseError(String(describing: error))
        }
    }

    private static func getDevices() throws -> [String: [Simulator]] {
        let output: String
        do {
            output = try ShellRunner.runAndCapture("xcrun", arguments: ["simctl", "list", "devices", "--json"])
        } catch {
            throw SimulatorManagerError.simctlFailed(String(describing: error))
        }

        guard let data = output.data(using: .utf8) else {
            throw SimulatorManagerError.parseError("Invalid output encoding")
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

            return result
        } catch {
            throw SimulatorManagerError.parseError(String(describing: error))
        }
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
