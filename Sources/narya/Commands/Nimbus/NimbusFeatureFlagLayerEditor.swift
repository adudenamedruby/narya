// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

/// Handles modifications to NimbusFeatureFlagLayer.swift
enum NimbusFeatureFlagLayerEditor {
    static func addFeature(name: String, filePath: URL) throws {
        var content = try String(contentsOf: filePath, encoding: .utf8)

        // 1. Add case to checkNimbusConfigFor switch
        content = try addSwitchCase(name: name, to: content)

        // 2. Add private check function
        content = try addCheckFunction(name: name, to: content)

        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    static func validateRemoval(name: String, filePath: URL) throws {
        let content = try String(contentsOf: filePath, encoding: .utf8)

        // Check switch case exists
        let casePattern = "case \\.\(name):"
        guard content.range(of: casePattern, options: .regularExpression) != nil else {
            throw ValidationError("Feature '\(name)' not found in checkNimbusConfigFor switch")
        }

        // Check function exists
        let funcName = "check\(StringUtils.capitalizeFirst(name))Feature"
        let funcPattern = "private func \(funcName)"
        guard content.contains(funcPattern) else {
            throw ValidationError("Function '\(funcName)' not found in NimbusFeatureFlagLayer")
        }
    }

    static func removeFeature(name: String, filePath: URL) throws {
        var content = try String(contentsOf: filePath, encoding: .utf8)

        // 1. Remove switch case
        content = try removeSwitchCase(name: name, from: content)

        // 2. Remove check function
        content = try removeCheckFunction(name: name, from: content)

        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    private static func addSwitchCase(name: String, to content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find the switch statement in checkNimbusConfigFor
        var inSwitch = false
        var insertIndex: Int?
        var lastCaseIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("switch featureID") {
                inSwitch = true
                continue
            }

            if inSwitch {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                if trimmed.hasPrefix("case .") {
                    let caseName = String(trimmed.dropFirst(6).prefix(while: { $0.isLetter || $0.isNumber }))
                    lastCaseIndex = index

                    if caseName > name && insertIndex == nil {
                        insertIndex = index
                    }
                }

                // End of switch (closing brace at same indentation level)
                if trimmed == "}" && line.hasPrefix("        }") {
                    if insertIndex == nil {
                        insertIndex = lastCaseIndex.map { $0 + 2 } // After the return line
                    }
                    break
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point for switch case")
        }

        let funcName = "check\(StringUtils.capitalizeFirst(name))Feature"
        let caseCode = """

                case .\(name):
                    return \(funcName)(from: nimbus)
        """
        lines.insert(caseCode, at: index)

        return lines.joined(separator: "\n")
    }

    private static func removeSwitchCase(name: String, from content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find and remove the case block (case line + return line + possible blank line before)
        var caseIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "case .\(name):" {
                caseIndex = index
                break
            }
        }

        if let index = caseIndex {
            // Remove blank line before if present
            if index > 0 && lines[index - 1].trimmingCharacters(in: .whitespaces).isEmpty {
                lines.remove(at: index - 1)
                // Adjust index after removal
                lines.remove(at: index - 1) // case line
                lines.remove(at: index - 1) // return line
            } else {
                lines.remove(at: index) // case line
                lines.remove(at: index) // return line
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func addCheckFunction(name: String, to content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        // Find the last closing brace of the class (should be the last } in the file)
        var insertIndex: Int?

        for index in stride(from: lines.count - 1, through: 0, by: -1) {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed == "}" {
                insertIndex = index
                break
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find class closing brace")
        }

        let funcName = "check\(StringUtils.capitalizeFirst(name))Feature"
        let funcCode = """

            private func \(funcName)(from nimbus: FxNimbus) -> Bool {
                return nimbus.features.\(name).value().enabled
            }
        """
        lines.insert(funcCode, at: index)

        return lines.joined(separator: "\n")
    }

    private static func removeCheckFunction(name: String, from content: String) throws -> String {
        var lines = content.components(separatedBy: "\n")

        let funcName = "check\(StringUtils.capitalizeFirst(name))Feature"

        // Find the function and remove it (including blank line before)
        var funcStartIndex: Int?
        var funcEndIndex: Int?
        var braceCount = 0
        var foundFunc = false

        for (index, line) in lines.enumerated() {
            if line.contains("private func \(funcName)") {
                funcStartIndex = index
                foundFunc = true
            }

            if foundFunc {
                braceCount += line.filter { $0 == "{" }.count
                braceCount -= line.filter { $0 == "}" }.count

                if braceCount == 0 {
                    funcEndIndex = index
                    break
                }
            }
        }

        if let start = funcStartIndex, let end = funcEndIndex {
            // Check for blank line before
            let removeStart = (start > 0 && lines[start - 1].trimmingCharacters(in: .whitespaces).isEmpty)
                ? start - 1
                : start
            lines.removeSubrange(removeStart...end)
        }

        return lines.joined(separator: "\n")
    }
}
