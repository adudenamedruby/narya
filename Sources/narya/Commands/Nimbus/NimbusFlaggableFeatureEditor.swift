// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

/// Handles modifications to NimbusFlaggableFeature.swift
enum NimbusFlaggableFeatureEditor {
    struct ValidationResult {
        let isInDebugKey: Bool
        let isUserToggleable: Bool
    }

    static func addFeature(
        name: String,
        debug: Bool,
        userToggleable: Bool,
        filePath: URL
    ) throws {
        var content = try String(contentsOf: filePath, encoding: .utf8)

        // 1. Add enum case to NimbusFeatureFlagID
        content = try addEnumCase(name: name, to: content)

        // 2. Add to debugKey if --debug
        if debug {
            content = try addToDebugKey(name: name, to: content)
        }

        // 3. Add to featureKey
        if userToggleable {
            content = try addUserToggleableCase(name: name, to: content)
        } else {
            content = try addToDefaultCase(name: name, to: content)
        }

        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    static func validateRemoval(name: String, filePath: URL) throws -> ValidationResult {
        let content = try String(contentsOf: filePath, encoding: .utf8)

        // Check enum case exists
        let enumPattern = "case \(name)\\b"
        guard content.range(of: enumPattern, options: .regularExpression) != nil else {
            throw ValidationError("Feature '\(name)' not found in NimbusFeatureFlagID enum")
        }

        // Check if in debugKey
        let debugKeyPattern = "\\.\(name)[,:]"
        let isInDebugKey = content.range(of: debugKeyPattern, options: .regularExpression) != nil &&
            content.contains("debugKey")

        // Check if user toggleable (has its own case in featureKey with fatalError or specific return)
        let userToggleablePattern = "case \\.\(name):\\s*\n\\s*(return FlagKeys\\.|fatalError)"
        let isUserToggleable = content.range(of: userToggleablePattern, options: .regularExpression) != nil

        return ValidationResult(isInDebugKey: isInDebugKey, isUserToggleable: isUserToggleable)
    }

    static func removeFeature(
        name: String,
        isInDebugKey: Bool,
        isUserToggleable: Bool,
        filePath: URL
    ) throws {
        var content = try String(contentsOf: filePath, encoding: .utf8)

        // 1. Remove enum case
        content = try removeEnumCase(name: name, from: content)

        // 2. Remove from debugKey if present
        if isInDebugKey {
            content = try removeFromDebugKey(name: name, from: content)
        }

        // 3. Remove from featureKey
        if isUserToggleable {
            content = try removeUserToggleableCase(name: name, from: content)
        } else {
            content = try removeFromDefaultCase(name: name, from: content)
        }

        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    // MARK: - Enum Case Operations

    private static func addEnumCase(name: String, to content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find the enum and insert alphabetically
        var inEnum = false
        var insertIndex: Int?
        var lastCaseIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("enum NimbusFeatureFlagID") {
                inEnum = true
                continue
            }

            if inEnum {
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("case ") {
                    let caseName = extractCaseName(from: line)
                    lastCaseIndex = index

                    if caseName > name && insertIndex == nil {
                        insertIndex = index
                    }
                }

                // End of enum cases (next section or closing brace)
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("//") ||
                   line.trimmingCharacters(in: .whitespaces).hasPrefix("var ") ||
                   line.trimmingCharacters(in: .whitespaces) == "}" {
                    if insertIndex == nil {
                        insertIndex = lastCaseIndex.map { $0 + 1 }
                    }
                    break
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point for enum case")
        }

        lines.insert("    case \(name)", at: index)
        return lines.joined(separator: "\n")
    }

    private static func removeEnumCase(name: String, from content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        if let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "case \(name)" }) {
            lines.remove(at: index)
        }

        return lines.joined(separator: "\n")
    }

    private static func extractCaseName(from line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("case ") else { return "" }
        let afterCase = trimmed.dropFirst(5)
        return String(afterCase.prefix(while: { $0.isLetter || $0.isNumber }))
    }

    // MARK: - debugKey Operations

    private static func addToDebugKey(name: String, to content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find the debugKey var and the case list
        var inDebugKey = false
        var insertIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("var debugKey: String?") {
                inDebugKey = true
                continue
            }

            if inDebugKey {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Look for case entries like .featureName, or .featureName:
                if trimmed.hasPrefix(".") {
                    let featureName = String(trimmed.dropFirst().prefix(while: { $0.isLetter || $0.isNumber }))

                    if featureName > name && insertIndex == nil {
                        insertIndex = index
                    }
                }

                // End of the case list (return statement)
                if trimmed.hasPrefix("return rawValue") {
                    if insertIndex == nil {
                        // Insert before the last feature (which has : instead of ,)
                        insertIndex = index - 1
                        // Find the last .feature line
                        for i in stride(from: index - 1, through: 0, by: -1) {
                            let prevLine = lines[i].trimmingCharacters(in: .whitespaces)
                            if prevLine.hasPrefix(".") {
                                // Change the : to , and insert after
                                if prevLine.hasSuffix(":") {
                                    lines[i] = lines[i].replacingOccurrences(of: ":", with: ",")
                                    insertIndex = i + 1
                                }
                                break
                            }
                        }
                    }
                    break
                }

                if trimmed == "default:" {
                    break
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point for debugKey")
        }

        // Determine if this is the last entry (should end with :) or not (should end with ,)
        let nextLine = lines[index].trimmingCharacters(in: .whitespaces)
        let suffix = nextLine.hasPrefix("return") ? ":" : ","

        lines.insert("                .\(name)\(suffix)", at: index)

        // If we inserted before a line that had :, change it to ,
        if suffix == ":" {
            let nextIdx = index + 1
            if nextIdx < lines.count && lines[nextIdx].hasSuffix(":") {
                lines[nextIdx] = lines[nextIdx].replacingOccurrences(of: ":", with: ",")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func removeFromDebugKey(name: String, from content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find and remove the .featureName line from debugKey section
        var inDebugKey = false

        for (index, line) in lines.enumerated() {
            if line.contains("var debugKey: String?") {
                inDebugKey = true
                continue
            }

            if inDebugKey {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed == ".\(name)," || trimmed == ".\(name):" {
                    // If this was the last entry (ends with :), make the previous entry end with :
                    if trimmed.hasSuffix(":") {
                        for i in stride(from: index - 1, through: 0, by: -1) {
                            let prevLine = lines[i].trimmingCharacters(in: .whitespaces)
                            if prevLine.hasPrefix(".") && prevLine.hasSuffix(",") {
                                lines[i] = lines[i].replacingOccurrences(of: ",", with: ":")
                                break
                            }
                        }
                    }
                    lines.remove(at: index)
                    break
                }

                if trimmed == "default:" {
                    break
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - featureKey Operations

    private static func addUserToggleableCase(name: String, to content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find featureKey var and add a new case before the comment about non-toggleable cases
        var inFeatureKey = false
        var insertIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("private var featureKey: String?") || line.contains("var featureKey: String?") {
                inFeatureKey = true
                continue
            }

            if inFeatureKey {
                // Insert before the comment about non-toggleable cases
                if line.contains("Cases where users do not have the option") {
                    insertIndex = index
                    break
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point for featureKey user-toggleable case")
        }

        let caseCode = """
                case .\(name):
                    fatalError("Please implement a key for this feature")
        """
        lines.insert(caseCode, at: index)

        return lines.joined(separator: "\n")
    }

    private static func removeUserToggleableCase(name: String, from content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find and remove the case block
        var removeStart: Int?
        var removeEnd: Int?

        for (index, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "case .\(name):" {
                removeStart = index
                // Find the end of this case (next case or default)
                for i in (index + 1)..<lines.count {
                    let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if nextLine.hasPrefix("case ") || nextLine.hasPrefix("//") {
                        removeEnd = i
                        break
                    }
                }
                break
            }
        }

        if let start = removeStart, let end = removeEnd {
            lines.removeSubrange(start..<end)
        }

        return lines.joined(separator: "\n")
    }

    private static func addToDefaultCase(name: String, to content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find the default case in featureKey (the one with return nil)
        var inFeatureKey = false
        var inDefaultCase = false
        var insertIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("private var featureKey: String?") || line.contains("var featureKey: String?") {
                inFeatureKey = true
                continue
            }

            if inFeatureKey {
                if line.contains("Cases where users do not have the option") {
                    inDefaultCase = true
                    continue
                }

                if inDefaultCase {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)

                    if trimmed.hasPrefix(".") {
                        let featureName = String(trimmed.dropFirst().prefix(while: { $0.isLetter || $0.isNumber }))

                        if featureName > name && insertIndex == nil {
                            insertIndex = index
                        }
                    }

                    // End of the case list (return nil)
                    if trimmed.hasPrefix("return nil") {
                        if insertIndex == nil {
                            // Insert before the last .feature: line
                            for i in stride(from: index - 1, through: 0, by: -1) {
                                let prevLine = lines[i].trimmingCharacters(in: .whitespaces)
                                if prevLine.hasPrefix(".") && prevLine.hasSuffix(":") {
                                    // Change : to , and insert after
                                    lines[i] = lines[i].replacingOccurrences(of: ":", with: ",")
                                    insertIndex = i + 1
                                    break
                                }
                            }
                        }
                        break
                    }
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point for featureKey default case")
        }

        // Determine suffix
        let nextLine = lines[index].trimmingCharacters(in: .whitespaces)
        let suffix = nextLine.hasPrefix("return") ? ":" : ","

        lines.insert("                .\(name)\(suffix)", at: index)

        // If we inserted with :, change the next line's : to ,
        if suffix == ":" {
            let nextIdx = index + 1
            if nextIdx < lines.count && lines[nextIdx].contains(":") {
                let trimmedNext = lines[nextIdx].trimmingCharacters(in: .whitespaces)
                if trimmedNext.hasPrefix(".") && trimmedNext.hasSuffix(":") {
                    lines[nextIdx] = lines[nextIdx].replacingOccurrences(of: ":", with: ",")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func removeFromDefaultCase(name: String, from content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        var inFeatureKey = false
        var inDefaultCase = false

        for (index, line) in lines.enumerated() {
            if line.contains("private var featureKey: String?") || line.contains("var featureKey: String?") {
                inFeatureKey = true
                continue
            }

            if inFeatureKey {
                if line.contains("Cases where users do not have the option") {
                    inDefaultCase = true
                    continue
                }

                if inDefaultCase {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)

                    if trimmed == ".\(name)," || trimmed == ".\(name):" {
                        // If this was the last entry, make previous entry end with :
                        if trimmed.hasSuffix(":") {
                            for i in stride(from: index - 1, through: 0, by: -1) {
                                let prevLine = lines[i].trimmingCharacters(in: .whitespaces)
                                if prevLine.hasPrefix(".") && prevLine.hasSuffix(",") {
                                    lines[i] = lines[i].replacingOccurrences(of: ",", with: ":")
                                    break
                                }
                            }
                        }
                        lines.remove(at: index)
                        break
                    }

                    if trimmed.hasPrefix("return nil") {
                        break
                    }
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
