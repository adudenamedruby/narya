// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

// MARK: - Derivable Shorthand Rules
//
// Shorthands are designed to be easily derivable from device names. If a device
// doesn't fit these patterns, it gets no shorthand and the user must provide
// the full device name to --sim.
//
// iPhone Patterns:
//   <N>        → iPhone N (base model only, e.g., "17" → "iPhone 17")
//   <N>pro     → iPhone N Pro (e.g., "17pro" → "iPhone 17 Pro")
//   <N>max     → iPhone N Pro Max (e.g., "17max" → "iPhone 17 Pro Max")
//   <N>plus    → iPhone N Plus (e.g., "17plus" → "iPhone 17 Plus")
//   <N>e       → iPhone Ne (e.g., "16e" → "iPhone 16e")
//   se         → iPhone SE (any generation)
//   air        → iPhone Air
//
// iPad Patterns:
//   air<size>  → iPad Air <size>-inch (e.g., "air11" → "iPad Air 11-inch")
//   pro<size>  → iPad Pro <size>-inch (e.g., "pro13" → "iPad Pro 13-inch")
//   mini       → iPad mini (any generation/chip)
//   mini<N>g   → iPad mini (Nth generation) (e.g., "mini6g" → "iPad mini (6th generation)")
//   miniA<N>   → iPad mini (A<N> chip) (e.g., "miniA17" → "iPad mini (A17 Pro)")
//   pad<N>g    → iPad (Nth generation) (e.g., "pad10g" → "iPad (10th generation)")
//   padA<N>    → iPad (A<N> chip) (e.g., "padA16" → "iPad (A16)")
//
// Size Matching:
//   - Guessable sizes: "13" matches both "13-inch" and "12.9-inch" (prefers exact)
//   - Precise sizes: "129" matches only "12.9-inch"
//   - Same logic for 10.2/10.5/10.9-inch (use "10" for guessable, "102"/"105"/"109" for precise)
//

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

                iPhone examples: 17, 17pro, 17max, 17plus, 16e, air, se
                iPad examples:   air11, pro13, pro129, mini, mini6g, miniA17, pad10g, padA16

                You can also use the full simulator name (e.g., "iPhone 17 Pro").
                Use 'list-sims' to see available simulators and their shorthands.
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
    /// Fallback pattern for guessable sizes (e.g., "13" matches "12.9-inch" as fallback)
    let fallbackPattern: String?

    init(type: DeviceType, pattern: String, fallbackPattern: String? = nil) {
        self.type = type
        self.pattern = pattern
        self.fallbackPattern = fallbackPattern
    }
}

// MARK: - Device Shorthand

enum DeviceShorthand {
    // MARK: - Cached Regex Patterns

    // swiftlint:disable force_try line_length
    /// Pre-compiled regex patterns to avoid repeated compilation (force_try safe for static literals)
    private static let phoneNumberPattern = try! NSRegularExpression(pattern: #"^(\d+)(e|pro|max|plus)?$"#, options: .caseInsensitive)
    private static let miniGenPattern = try! NSRegularExpression(pattern: #"^mini(\d+)g$"#, options: .caseInsensitive)
    private static let miniChipPattern = try! NSRegularExpression(pattern: #"^minia(\d+)$"#, options: .caseInsensitive)
    private static let padGenerationPattern = try! NSRegularExpression(pattern: #"^pad(\d+)g$"#, options: .caseInsensitive)
    private static let padChipPattern = try! NSRegularExpression(pattern: #"^pada(\d+)$"#, options: .caseInsensitive)
    private static let ipadSizePattern = try! NSRegularExpression(pattern: #"^(air|pro)(\d+)$"#, options: .caseInsensitive)
    // swiftlint:enable force_try line_length

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
        // First pass: try exact/primary pattern
        for (runtime, devices) in filteredRuntimes {
            for device in devices {
                let range = NSRange(device.name.startIndex..., in: device.name)
                if regex.firstMatch(in: device.name, range: range) != nil {
                    return SimulatorSelection(simulator: device, runtime: runtime)
                }
            }
        }

        // Second pass: try fallback pattern (for guessable sizes like "13" matching "12.9-inch")
        if let fallbackPattern = parsed.fallbackPattern,
           let fallbackRegex = try? NSRegularExpression(pattern: fallbackPattern, options: []) {
            for (runtime, devices) in filteredRuntimes {
                for device in devices {
                    let range = NSRange(device.name.startIndex..., in: device.name)
                    if fallbackRegex.firstMatch(in: device.name, range: range) != nil {
                        return SimulatorSelection(simulator: device, runtime: runtime)
                    }
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
        if let result = ipadPattern(for: lowered) {
            return ParsedShorthand(type: .ipad, pattern: result.pattern, fallbackPattern: result.fallback)
        }

        // Then try iPhone patterns
        if let pattern = phonePattern(for: lowered) {
            return ParsedShorthand(type: .phone, pattern: pattern)
        }

        return nil
    }

    /// Returns the ordinal suffix regex pattern for a given generation number
    /// e.g., 1 -> "1st", 2 -> "2nd", 3 -> "3rd", 4+ -> "4th"
    private static func ordinalPattern(for generation: String) -> String {
        guard let num = Int(generation) else {
            return "\(generation)th"
        }
        switch num {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(num)th"
        }
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

        // Use cached pattern: <number>[e|pro|max|plus]
        let range = NSRange(shorthand.startIndex..., in: shorthand)
        guard let match = phoneNumberPattern.firstMatch(in: shorthand, range: range) else {
            return nil
        }

        // Extract number
        guard let numberRange = Range(match.range(at: 1), in: shorthand) else {
            return nil
        }
        let number = String(shorthand[numberRange])

        // Extract suffix (if any)
        var suffix: String?
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
    /// Returns a tuple of (primary pattern, optional fallback pattern for guessable sizes)
    ///
    /// Patterns:
    /// - `air11` → iPad Air 11-inch
    /// - `air13` → iPad Air 13-inch (also matches 12.9-inch as fallback)
    /// - `pro11` → iPad Pro 11-inch
    /// - `pro13` → iPad Pro 13-inch (also matches 12.9-inch as fallback)
    /// - `pro129` → iPad Pro 12.9-inch (precise, no fallback)
    /// - `mini` → iPad mini (any)
    /// - `mini6g` → iPad mini (6th generation)
    /// - `miniA17` → iPad mini (A17 Pro)
    /// - `pad10g` → iPad (10th generation)
    /// - `padA16` → iPad (A16)
    private static func ipadPattern(for shorthand: String) -> (pattern: String, fallback: String?)? {
        let range = NSRange(shorthand.startIndex..., in: shorthand)

        // Special case: mini (any)
        if shorthand == "mini" {
            return ("^iPad mini", nil)
        }

        // mini<N>g → iPad mini (Nth generation)
        if let genMatch = miniGenPattern.firstMatch(in: shorthand, range: range),
           let genRange = Range(genMatch.range(at: 1), in: shorthand) {
            let generation = String(shorthand[genRange])
            let ordinal = ordinalPattern(for: generation)
            return ("^iPad mini \\(\(ordinal) generation\\)$", nil)
        }

        // miniA<chip> → iPad mini (A<chip> Pro) or iPad mini (A<chip>)
        if let chipMatch = miniChipPattern.firstMatch(in: shorthand, range: range),
           let chipRange = Range(chipMatch.range(at: 1), in: shorthand) {
            let chip = String(shorthand[chipRange])
            // Match both "iPad mini (A17 Pro)" and "iPad mini (A17)"
            return ("^iPad mini \\(A\(chip)", nil)
        }

        // pad<N>g → iPad (Nth generation)
        if let genMatch = padGenerationPattern.firstMatch(in: shorthand, range: range),
           let genRange = Range(genMatch.range(at: 1), in: shorthand) {
            let generation = String(shorthand[genRange])
            let ordinal = ordinalPattern(for: generation)
            return ("^iPad \\(\(ordinal) generation\\)$", nil)
        }

        // padA<chip> → iPad (A<chip>)
        if let chipMatch = padChipPattern.firstMatch(in: shorthand, range: range),
           let chipRange = Range(chipMatch.range(at: 1), in: shorthand) {
            let chip = String(shorthand[chipRange])
            return ("^iPad \\(A\(chip)\\)$", nil)
        }

        // Pattern: <type><size> where type is air|pro and size is a number
        guard let match = ipadSizePattern.firstMatch(in: shorthand, range: range) else {
            return nil
        }

        guard let typeRange = Range(match.range(at: 1), in: shorthand),
              let sizeRange = Range(match.range(at: 2), in: shorthand) else {
            return nil
        }

        let deviceType = String(shorthand[typeRange])
        let size = String(shorthand[sizeRange])
        let typeName = deviceType == "air" ? "Air" : "Pro"

        // Handle size patterns with fallbacks for guessable sizes
        // Precise sizes (3+ digits): no fallback
        // Guessable sizes (1-2 digits): may have fallback for fractional inch sizes
        let (primarySize, fallbackSize) = sizePatterns(for: size)
        let primaryPattern = "^iPad \(typeName) \(primarySize)-inch"
        let fallbackPattern = fallbackSize.map { "^iPad \(typeName) \($0)-inch" }

        return (primaryPattern, fallbackPattern)
    }

    /// Returns primary and fallback size patterns for iPad screen sizes
    /// - "13" -> ("13", "12.9") - guessable, 12.9 is fallback
    /// - "129" -> ("12.9", nil) - precise 12.9-inch
    /// - "10" -> ("10", "10.[259]") - guessable, matches 10.2, 10.5, 10.9
    /// - "102" -> ("10.2", nil) - precise 10.2-inch
    /// - "11" -> ("11", nil) - exact, no fallback needed
    private static func sizePatterns(for size: String) -> (primary: String, fallback: String?) {
        switch size {
        // Precise sizes (user typed exact decimal like "129" for 12.9)
        case "129":
            return ("12.9", nil)
        case "105":
            return ("10.5", nil)
        case "102":
            return ("10.2", nil)
        case "109":
            return ("10.9", nil)
        case "97":
            return ("9.7", nil)

        // Guessable sizes with fallbacks
        case "13":
            return ("13", "12.9")
        case "10":
            return ("10", "10\\.[259]")  // matches 10.2, 10.5, or 10.9

        // Exact sizes (no fallback needed)
        default:
            return (size, nil)
        }
    }

    // MARK: - Shorthand Derivation

    /// Derives the shorthand code from a device name (e.g., "iPhone 17 Pro" → "17pro")
    /// Returns nil if no shorthand can be derived (device doesn't fit derivable patterns)
    static func shorthand(for deviceName: String) -> String? {
        // iPhone patterns
        if deviceName.hasPrefix("iPhone") {
            return iphoneShorthand(for: deviceName)
        }

        // iPad patterns
        if deviceName.hasPrefix("iPad") {
            return ipadShorthand(for: deviceName)
        }

        return nil
    }

    /// Derives shorthand for iPhone device names
    private static func iphoneShorthand(for deviceName: String) -> String? {
        // iPhone Air
        if deviceName == "iPhone Air" {
            return "air"
        }
        // iPhone SE (any generation)
        if deviceName.hasPrefix("iPhone SE") {
            return "se"
        }
        // iPhone 16e
        if let match = deviceName.range(of: #"^iPhone (\d+)e$"#, options: .regularExpression) {
            let number = deviceName[match]
                .replacingOccurrences(of: "iPhone ", with: "")
                .replacingOccurrences(of: "e", with: "")
            return "\(number)e"
        }
        // iPhone XX Pro Max
        if let match = deviceName.range(of: #"^iPhone (\d+) Pro Max$"#, options: .regularExpression) {
            let number = deviceName[match]
                .replacingOccurrences(of: "iPhone ", with: "")
                .replacingOccurrences(of: " Pro Max", with: "")
            return "\(number)max"
        }
        // iPhone XX Pro
        if let match = deviceName.range(of: #"^iPhone (\d+) Pro$"#, options: .regularExpression) {
            let number = deviceName[match]
                .replacingOccurrences(of: "iPhone ", with: "")
                .replacingOccurrences(of: " Pro", with: "")
            return "\(number)pro"
        }
        // iPhone XX Plus
        if let match = deviceName.range(of: #"^iPhone (\d+) Plus$"#, options: .regularExpression) {
            let number = deviceName[match]
                .replacingOccurrences(of: "iPhone ", with: "")
                .replacingOccurrences(of: " Plus", with: "")
            return "\(number)plus"
        }
        // iPhone XX (base model)
        if let match = deviceName.range(of: #"^iPhone (\d+)$"#, options: .regularExpression) {
            let number = deviceName[match].replacingOccurrences(of: "iPhone ", with: "")
            return number
        }
        return nil
    }

    /// Derives shorthand for iPad device names
    private static func ipadShorthand(for deviceName: String) -> String? {
        // iPad mini with generation: "iPad mini (6th generation)" → "mini6g"
        if let match = deviceName.range(of: #"^iPad mini \((\d+)(st|nd|rd|th) generation\)$"#, options: .regularExpression) {
            let matched = String(deviceName[match])
            if let numMatch = matched.range(of: #"\d+"#, options: .regularExpression) {
                let generation = String(matched[numMatch])
                return "mini\(generation)g"
            }
        }
        // iPad mini with chip: "iPad mini (A17 Pro)" → "miniA17"
        if let match = deviceName.range(of: #"^iPad mini \(A(\d+)"#, options: .regularExpression) {
            let matched = String(deviceName[match])
            if let numMatch = matched.range(of: #"\d+"#, options: .regularExpression) {
                let chip = String(matched[numMatch])
                return "miniA\(chip)"
            }
        }
        // iPad mini (any) - only if no generation/chip suffix matched above
        if deviceName == "iPad mini" {
            return "mini"
        }

        // iPad (Nth generation): "iPad (10th generation)" → "pad10g"
        if let match = deviceName.range(of: #"^iPad \((\d+)(st|nd|rd|th) generation\)$"#, options: .regularExpression) {
            let matched = String(deviceName[match])
            if let numMatch = matched.range(of: #"\d+"#, options: .regularExpression) {
                let generation = String(matched[numMatch])
                return "pad\(generation)g"
            }
        }

        // iPad (A<chip>): "iPad (A16)" → "padA16"
        if let match = deviceName.range(of: #"^iPad \(A(\d+)\)$"#, options: .regularExpression) {
            let chip = deviceName[match]
                .replacingOccurrences(of: "iPad (A", with: "")
                .replacingOccurrences(of: ")", with: "")
            return "padA\(chip)"
        }

        // iPad Air XX-inch or XX.X-inch: derive guessable size
        if let match = deviceName.range(of: #"^iPad Air (\d+(\.\d+)?)-inch"#, options: .regularExpression) {
            let sizeStr = deviceName[match]
                .replacingOccurrences(of: "iPad Air ", with: "")
                .replacingOccurrences(of: "-inch", with: "")
            let size = deriveGuessableSize(sizeStr)
            return "air\(size)"
        }

        // iPad Pro XX-inch or XX.X-inch: derive guessable size
        if let match = deviceName.range(of: #"^iPad Pro (\d+(\.\d+)?)-inch"#, options: .regularExpression) {
            let sizeStr = deviceName[match]
                .replacingOccurrences(of: "iPad Pro ", with: "")
                .replacingOccurrences(of: "-inch", with: "")
            let size = deriveGuessableSize(sizeStr)
            return "pro\(size)"
        }

        return nil
    }

    /// Converts a size string to its guessable shorthand form
    /// "12.9" → "13", "10.5" → "10", "11" → "11"
    private static func deriveGuessableSize(_ size: String) -> String {
        switch size {
        case "12.9":
            return "13"
        case "10.2", "10.5", "10.9":
            return "10"
        case "9.7":
            return "10"  // Round up to 10 for guessability
        default:
            // For whole numbers or unknown sizes, return as-is
            if let dotIndex = size.firstIndex(of: ".") {
                return String(size[..<dotIndex])
            }
            return size
        }
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
