// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

// MARK: - Device Type

enum DeviceType: String {
    case phone
    case ipad

    var displayName: String {
        switch self {
        case .phone: return "iPhone"
        case .ipad: return "iPad"
        }
    }
}

// MARK: - Shorthand Errors

enum DeviceShorthandError: Error, CustomStringConvertible {
    case invalidShorthand(shorthand: String)
    case simulatorNotFound(shorthand: String, type: DeviceType, available: [String])

    var description: String {
        switch self {
        case .invalidShorthand(let shorthand):
            return """
                Invalid simulator shorthand '\(shorthand)'.

                iPhone examples: 17, 17pro, 17max, 16e, air, se
                iPad examples:   air11, air13, pro11, pro13, mini
                """

        case .simulatorNotFound(let shorthand, let type, let available):
            var message = "No \(type.displayName) simulator found matching '\(shorthand)'.\n"
            message += "\nAvailable \(type.displayName) simulators:\n"
            for sim in available.prefix(10) {
                message += "  - \(sim)\n"
            }
            if available.count > 10 {
                message += "  ... and \(available.count - 10) more\n"
            }
            if available.isEmpty {
                message += "  (none installed)\n"
            }
            return message
        }
    }
}

// MARK: - Parsed Shorthand

private struct ParsedShorthand {
    let type: DeviceType
    let pattern: String
}

// MARK: - Device Shorthand

enum DeviceShorthand {
    // MARK: - Public API

    /// Finds a simulator matching the shorthand (auto-detects iPhone vs iPad)
    /// - Parameters:
    ///   - shorthand: The user-provided shorthand (e.g., "17pro", "air13", "mini")
    ///   - osVersion: Optional iOS version filter
    /// - Returns: The matching simulator selection
    static func findSimulator(
        shorthand: String,
        osVersion: String?
    ) throws -> SimulatorSelection {
        // Parse the shorthand to determine device type and regex pattern
        guard let parsed = parseShorthand(shorthand) else {
            throw DeviceShorthandError.invalidShorthand(shorthand: shorthand)
        }

        // Get all simulators
        let simulatorsByRuntime = try SimulatorManager.listSimulators()

        // Filter by OS version if specified
        let filteredRuntimes: [(runtime: SimulatorRuntime, devices: [Simulator])]
        if let osVersion = osVersion {
            filteredRuntimes = simulatorsByRuntime.filter { $0.runtime.version.hasPrefix(osVersion) }
        } else {
            filteredRuntimes = simulatorsByRuntime
        }

        // Create regex for matching
        guard let regex = try? NSRegularExpression(pattern: parsed.pattern, options: []) else {
            throw DeviceShorthandError.invalidShorthand(shorthand: shorthand)
        }

        // Find matching simulators (runtimes are already sorted newest first)
        for (runtime, devices) in filteredRuntimes {
            for device in devices {
                let range = NSRange(device.name.startIndex..., in: device.name)
                if regex.firstMatch(in: device.name, range: range) != nil {
                    return SimulatorSelection(simulator: device, runtime: runtime)
                }
            }
        }

        // No match found - gather available simulators for error message
        let available = gatherAvailableSimulators(type: parsed.type, from: simulatorsByRuntime)
        throw DeviceShorthandError.simulatorNotFound(
            shorthand: shorthand,
            type: parsed.type,
            available: available
        )
    }

    // MARK: - Shorthand Parsing

    /// Parses a shorthand string and returns the device type and regex pattern
    private static func parseShorthand(_ shorthand: String) -> ParsedShorthand? {
        let lowered = shorthand.lowercased()

        // Try iPad patterns first (more specific)
        if let pattern = ipadPattern(for: lowered) {
            return ParsedShorthand(type: .ipad, pattern: pattern)
        }

        // Then try iPhone patterns
        if let pattern = phonePattern(for: lowered) {
            return ParsedShorthand(type: .phone, pattern: pattern)
        }

        return nil
    }

    /// Generates regex pattern for iPhone shorthands
    ///
    /// Patterns:
    /// - `17` → iPhone 17 (base model)
    /// - `17pro` → iPhone 17 Pro
    /// - `17max` → iPhone 17 Pro Max
    /// - `17plus` → iPhone 17 Plus
    /// - `16e` → iPhone 16e
    /// - `air` → iPhone Air
    /// - `se` → iPhone SE
    private static func phonePattern(for shorthand: String) -> String? {
        // Special cases
        if shorthand == "air" {
            return "^iPhone Air"
        }
        if shorthand == "se" {
            return "^iPhone SE"
        }

        // Pattern: <number>[e|pro|max|plus]
        let pattern = #"^(\d+)(e|pro|max|plus)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: shorthand, range: NSRange(shorthand.startIndex..., in: shorthand)) else {
            return nil
        }

        // Extract number
        guard let numberRange = Range(match.range(at: 1), in: shorthand) else {
            return nil
        }
        let number = String(shorthand[numberRange])

        // Extract suffix (if any)
        var suffix: String? = nil
        if match.range(at: 2).location != NSNotFound,
           let suffixRange = Range(match.range(at: 2), in: shorthand) {
            suffix = String(shorthand[suffixRange])
        }

        // Build the regex pattern for simulator name matching
        switch suffix {
        case nil:
            // Base model: "iPhone 17" but NOT "iPhone 17 Pro" or "iPhone 17 Plus"
            return "^iPhone \(number)$"
        case "e":
            // iPhone 16e
            return "^iPhone \(number)e$"
        case "pro":
            // "iPhone 17 Pro" but NOT "iPhone 17 Pro Max"
            return "^iPhone \(number) Pro$"
        case "max":
            // "iPhone 17 Pro Max"
            return "^iPhone \(number) Pro Max$"
        case "plus":
            // "iPhone 17 Plus"
            return "^iPhone \(number) Plus$"
        default:
            return nil
        }
    }

    /// Generates regex pattern for iPad shorthands
    ///
    /// Patterns:
    /// - `air11` → iPad Air 11-inch
    /// - `air13` → iPad Air 13-inch
    /// - `pro11` → iPad Pro 11-inch
    /// - `pro13` → iPad Pro 13-inch
    /// - `mini` → iPad mini
    private static func ipadPattern(for shorthand: String) -> String? {
        // Special case: mini
        if shorthand == "mini" {
            return "^iPad mini"
        }

        // Pattern: <type><size> where type is air|pro and size is a number
        let pattern = #"^(air|pro)(\d+)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: shorthand, range: NSRange(shorthand.startIndex..., in: shorthand)) else {
            return nil
        }

        guard let typeRange = Range(match.range(at: 1), in: shorthand),
              let sizeRange = Range(match.range(at: 2), in: shorthand) else {
            return nil
        }

        let deviceType = String(shorthand[typeRange])
        let size = String(shorthand[sizeRange])

        // Build the regex pattern
        // Matches "iPad Air 11-inch" or "iPad Pro 13-inch" (with any generation suffix)
        let typeName = deviceType == "air" ? "Air" : "Pro"
        return "^iPad \(typeName) \(size)-inch"
    }

    // MARK: - Helpers

    /// Gathers available simulator names for a device type (for error messages)
    private static func gatherAvailableSimulators(
        type: DeviceType,
        from simulatorsByRuntime: [(runtime: SimulatorRuntime, devices: [Simulator])]
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        let prefix = type == .phone ? "iPhone" : "iPad"

        for (runtime, devices) in simulatorsByRuntime {
            for device in devices {
                if device.name.hasPrefix(prefix) && !seen.contains(device.name) {
                    seen.insert(device.name)
                    result.append("\(device.name) (iOS \(runtime.version))")
                }
            }
        }

        return result
    }
}
