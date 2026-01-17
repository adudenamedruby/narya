// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Nimbus: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage Nimbus feature configuration files.",
        discussion: """
            Manages Nimbus feature flags across the firefox-ios codebase.

            Use 'refresh' to update the include block in nimbus.fml.yaml.
            Use 'add' to create a new feature with all required boilerplate.
            Use 'remove' to remove a feature from all locations.
            """,
        subcommands: [Refresh.self, Add.self, Remove.self]
    )
}

// MARK: - Constants

enum NimbusConstants {
    static let nimbusFmlPath = "firefox-ios/nimbus.fml.yaml"
    static let nimbusFeaturesPath = "firefox-ios/nimbus-features"
    static let nimbusFlaggableFeaturePath = "firefox-ios/Client/FeatureFlags/NimbusFlaggableFeature.swift"
    static let nimbusFeatureFlagLayerPath = "firefox-ios/Client/Nimbus/NimbusFeatureFlagLayer.swift"
    static let featureFlagsDebugViewControllerPath = "firefox-ios/Client/Frontend/Settings/Main/Debug/FeatureFlags/FeatureFlagsDebugViewController.swift"
}

// MARK: - Refresh Subcommand

extension Nimbus {
    struct Refresh: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Refresh the include block in nimbus.fml.yaml with current feature files."
        )

        mutating func run() throws {
            Herald.reset()

            let repo = try RepoDetector.requireValidRepo()

            Herald.declare("Updating nimbus.fml.yaml include block...")
            try NimbusHelpers.updateNimbusFml(repoRoot: repo.root)
            Herald.declare("Successfully updated nimbus.fml.yaml")
        }
    }
}

// MARK: - Add Subcommand

extension Nimbus {
    struct Add: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Add a new Nimbus feature flag.",
            discussion: """
                Creates a new feature YAML file and adds the feature to all required Swift files.

                The feature name should be in camelCase without the 'Feature' suffix.
                For example: 'testButtress' will create 'testButtressFeature.yaml'.
                """
        )

        @Argument(help: "The feature name in camelCase (without 'Feature' suffix).")
        var featureName: String

        @Flag(name: .long, help: "Add the feature to the debug settings UI.")
        var debug = false

        @Flag(name: .long, help: "Mark the feature as user-toggleable (requires implementing a preference key).")
        var userToggleable = false

        mutating func run() throws {
            Herald.reset()

            let repo = try RepoDetector.requireValidRepo()

            // Standardize the feature name (remove Feature suffix if present)
            let cleanName = NimbusHelpers.cleanFeatureName(featureName)

            Herald.declare("Adding feature '\(cleanName)'...")

            // 1. Create the YAML file
            let yamlFileName = "\(cleanName)Feature.yaml"
            let yamlFilePath = repo.root
                .appendingPathComponent(NimbusConstants.nimbusFeaturesPath)
                .appendingPathComponent(yamlFileName)

            Herald.declare("Creating feature file: \(NimbusConstants.nimbusFeaturesPath)/\(yamlFileName)")
            try NimbusHelpers.writeFeatureTemplate(to: yamlFilePath, featureName: "\(cleanName)Feature")

            // 2. Update nimbus.fml.yaml
            Herald.declare("Updating nimbus.fml.yaml...")
            try NimbusHelpers.updateNimbusFml(repoRoot: repo.root)

            // 3. Update NimbusFlaggableFeature.swift
            let flaggableFeaturePath = repo.root.appendingPathComponent(NimbusConstants.nimbusFlaggableFeaturePath)
            Herald.declare("Updating NimbusFlaggableFeature.swift...")
            try NimbusFlaggableFeatureEditor.addFeature(
                name: cleanName,
                debug: debug,
                userToggleable: userToggleable,
                filePath: flaggableFeaturePath
            )

            // 4. Update NimbusFeatureFlagLayer.swift
            let flagLayerPath = repo.root.appendingPathComponent(NimbusConstants.nimbusFeatureFlagLayerPath)
            Herald.declare("Updating NimbusFeatureFlagLayer.swift...")
            try NimbusFeatureFlagLayerEditor.addFeature(name: cleanName, filePath: flagLayerPath)

            // 5. If --debug, update FeatureFlagsDebugViewController.swift
            if debug {
                let debugVCPath = repo.root.appendingPathComponent(NimbusConstants.featureFlagsDebugViewControllerPath)
                Herald.declare("Updating FeatureFlagsDebugViewController.swift...")
                try FeatureFlagsDebugViewControllerEditor.addFeature(name: cleanName, filePath: debugVCPath)
            }

            Herald.declare("Successfully added feature '\(cleanName)'")
            Herald.declare("Please remember to add this feature to the feature flag spreadsheet.")
        }
    }
}

// MARK: - Remove Subcommand

extension Nimbus {
    struct Remove: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Remove a Nimbus feature flag.",
            discussion: """
                Removes a feature from all locations where it was added.

                The command will validate that all patterns match exactly before removing anything.
                If any validation fails, no changes will be made.
                """
        )

        @Argument(help: "The feature name in camelCase (without 'Feature' suffix).")
        var featureName: String

        mutating func run() throws {
            Herald.reset()

            let repo = try RepoDetector.requireValidRepo()

            // Standardize the feature name
            let cleanName = NimbusHelpers.cleanFeatureName(featureName)

            Herald.declare("Removing feature '\(cleanName)'...")

            // Collect all file paths
            let yamlFileName = "\(cleanName)Feature.yaml"
            let yamlFilePath = repo.root
                .appendingPathComponent(NimbusConstants.nimbusFeaturesPath)
                .appendingPathComponent(yamlFileName)
            let flaggableFeaturePath = repo.root.appendingPathComponent(NimbusConstants.nimbusFlaggableFeaturePath)
            let flagLayerPath = repo.root.appendingPathComponent(NimbusConstants.nimbusFeatureFlagLayerPath)
            let debugVCPath = repo.root.appendingPathComponent(NimbusConstants.featureFlagsDebugViewControllerPath)

            // Phase 1: Validate all removals are possible
            Herald.declare("Validating removal...")

            // Check YAML file exists
            guard FileManager.default.fileExists(atPath: yamlFilePath.path) else {
                throw ValidationError("Feature YAML file not found: \(yamlFilePath.path)")
            }

            // Validate NimbusFlaggableFeature.swift
            let flaggableValidation = try NimbusFlaggableFeatureEditor.validateRemoval(
                name: cleanName,
                filePath: flaggableFeaturePath
            )

            // Validate NimbusFeatureFlagLayer.swift
            try NimbusFeatureFlagLayerEditor.validateRemoval(name: cleanName, filePath: flagLayerPath)

            // Check if feature is in debug settings
            let isInDebugVC = try FeatureFlagsDebugViewControllerEditor.featureExists(
                name: cleanName,
                filePath: debugVCPath
            )

            // Phase 2: Perform all removals
            Herald.declare("Removing from all locations...")

            // Remove YAML file
            Herald.declare("Removing feature file: \(NimbusConstants.nimbusFeaturesPath)/\(yamlFileName)")
            try FileManager.default.removeItem(at: yamlFilePath)

            // Update nimbus.fml.yaml
            Herald.declare("Updating nimbus.fml.yaml...")
            try NimbusHelpers.updateNimbusFml(repoRoot: repo.root)

            // Remove from NimbusFlaggableFeature.swift
            Herald.declare("Updating NimbusFlaggableFeature.swift...")
            try NimbusFlaggableFeatureEditor.removeFeature(
                name: cleanName,
                isInDebugKey: flaggableValidation.isInDebugKey,
                isUserToggleable: flaggableValidation.isUserToggleable,
                filePath: flaggableFeaturePath
            )

            // Remove from NimbusFeatureFlagLayer.swift
            Herald.declare("Updating NimbusFeatureFlagLayer.swift...")
            try NimbusFeatureFlagLayerEditor.removeFeature(name: cleanName, filePath: flagLayerPath)

            // Remove from FeatureFlagsDebugViewController.swift if present
            if isInDebugVC {
                Herald.declare("Updating FeatureFlagsDebugViewController.swift...")
                try FeatureFlagsDebugViewControllerEditor.removeFeature(name: cleanName, filePath: debugVCPath)
            }

            Herald.declare("Successfully removed feature '\(cleanName)'")
        }
    }
}

// MARK: - Shared Helpers

enum NimbusHelpers {
    /// Removes the "Feature" suffix from a feature name if present
    static func cleanFeatureName(_ input: String) -> String {
        if input.hasSuffix("Feature") {
            return String(input.dropLast(7))
        }
        return input
    }

    /// Converts camelCase to kebab-case
    static func camelToKebabCase(_ input: String) -> String {
        var result = ""
        for (index, char) in input.enumerated() {
            if char.isUppercase && index > 0 {
                result += "-"
            }
            result += char.lowercased()
        }
        return result
    }

    /// Converts camelCase to Title Case (e.g., "testButtress" -> "Test Buttress")
    static func camelToTitleCase(_ input: String) -> String {
        var result = ""
        for (index, char) in input.enumerated() {
            if char.isUppercase && index > 0 {
                result += " "
            }
            if index == 0 {
                result += char.uppercased()
            } else {
                result += String(char)
            }
        }
        return result
    }

    /// Capitalizes the first letter of a string
    static func capitalizeFirst(_ input: String) -> String {
        guard let first = input.first else { return input }
        return first.uppercased() + input.dropFirst()
    }

    /// Updates the nimbus.fml.yaml include block with current feature files
    static func updateNimbusFml(repoRoot: URL) throws {
        let fmlPath = repoRoot.appendingPathComponent(NimbusConstants.nimbusFmlPath)

        guard FileManager.default.fileExists(atPath: fmlPath.path) else {
            throw ValidationError("nimbus.fml.yaml not found at \(fmlPath.path)")
        }

        // Read current content
        var content = try String(contentsOf: fmlPath, encoding: .utf8)

        // Remove existing nimbus-features lines
        let lines = content.components(separatedBy: "\n")
        let filteredLines = lines.filter { !$0.contains("nimbus-features") }
        content = filteredLines.joined(separator: "\n")

        // Add feature files
        let featuresDir = repoRoot.appendingPathComponent(NimbusConstants.nimbusFeaturesPath)
        if FileManager.default.fileExists(atPath: featuresDir.path) {
            let yamlFiles = try FileManager.default.contentsOfDirectory(at: featuresDir, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "yaml" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            for file in yamlFiles {
                let relativePath = "nimbus-features/\(file.lastPathComponent)"
                content += "\n  - \(relativePath)"
            }
        }

        try content.write(to: fmlPath, atomically: true, encoding: .utf8)
    }

    /// Writes the feature YAML template
    static func writeFeatureTemplate(to url: URL, featureName: String) throws {
        let kebabName = camelToKebabCase(featureName)

        let template = """
            # The configuration for the \(featureName) feature
            features:
              \(kebabName):
                description: >
                  Feature description
                variables:
                  enabled:
                    description: >
                      Whether or not this feature is enabled
                    type: Boolean
                    default: false
                defaults:
                  - channel: beta
                    value:
                      enabled: false
                  - channel: developer
                    value:
                      enabled: true
            """
        try template.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - NimbusFlaggableFeature Editor

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

// MARK: - NimbusFeatureFlagLayer Editor

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
        let funcName = "check\(NimbusHelpers.capitalizeFirst(name))Feature"
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

        let funcName = "check\(NimbusHelpers.capitalizeFirst(name))Feature"
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

        let funcName = "check\(NimbusHelpers.capitalizeFirst(name))Feature"
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

        let funcName = "check\(NimbusHelpers.capitalizeFirst(name))Feature"

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

// MARK: - FeatureFlagsDebugViewController Editor

enum FeatureFlagsDebugViewControllerEditor {
    static func addFeature(name: String, filePath: URL) throws {
        var content = try String(contentsOf: filePath, encoding: .utf8)

        let titleText = NimbusHelpers.camelToTitleCase(name)

        // Find the children array and insert alphabetically by titleText
        var lines = content.components(separatedBy: "\n")
        var inChildren = false
        var insertIndex: Int?
        var lastSettingEndIndex: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("var children: [Setting]") {
                inChildren = true
                continue
            }

            if inChildren {
                // Look for FeatureFlagsBoolSetting blocks
                if line.contains("FeatureFlagsBoolSetting(") {
                    // Extract the titleText from the next few lines
                    for i in index..<min(index + 5, lines.count) {
                        if lines[i].contains("titleText:") {
                            if let titleRange = lines[i].range(of: "\"([^\"]+)\"", options: .regularExpression) {
                                let existingTitle = String(lines[i][titleRange]).replacingOccurrences(of: "\"", with: "")
                                if existingTitle > titleText && insertIndex == nil {
                                    insertIndex = index
                                }
                            }
                            break
                        }
                    }
                }

                // Track end of each setting block
                if line.trimmingCharacters(in: .whitespaces) == "}," {
                    lastSettingEndIndex = index
                }

                // End of children array (before the conditional #if block or closing bracket)
                if line.contains("#if canImport") || line.trimmingCharacters(in: .whitespaces) == "]" {
                    if insertIndex == nil {
                        insertIndex = lastSettingEndIndex.map { $0 + 1 }
                    }
                    break
                }
            }
        }

        guard let index = insertIndex else {
            throw ValidationError("Could not find insertion point for debug setting")
        }

        let settingCode = """
                    FeatureFlagsBoolSetting(
                        with: .\(name),
                        titleText: format(string: "\(titleText)"),
                        statusText: format(string: "Toggle \(titleText)")
                    ) { [weak self] _ in
                        self?.reloadView()
                    },
        """
        lines.insert(settingCode, at: index)

        content = lines.joined(separator: "\n")
        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }

    static func featureExists(name: String, filePath: URL) throws -> Bool {
        let content = try String(contentsOf: filePath, encoding: .utf8)
        return content.contains("with: .\(name),")
    }

    static func removeFeature(name: String, filePath: URL) throws {
        var content = try String(contentsOf: filePath, encoding: .utf8)
        var lines = content.components(separatedBy: "\n")

        // Find the FeatureFlagsBoolSetting block for this feature
        var blockStart: Int?
        var blockEnd: Int?

        for (index, line) in lines.enumerated() {
            if line.contains("with: .\(name),") {
                // Find the start of this block (FeatureFlagsBoolSetting line)
                for i in stride(from: index, through: max(0, index - 5), by: -1) {
                    if lines[i].contains("FeatureFlagsBoolSetting(") {
                        blockStart = i
                        break
                    }
                }

                // Find the end of this block (}, line)
                for i in index..<min(index + 10, lines.count) {
                    if lines[i].trimmingCharacters(in: .whitespaces) == "}," {
                        blockEnd = i
                        break
                    }
                }
                break
            }
        }

        if let start = blockStart, let end = blockEnd {
            lines.removeSubrange(start...end)
        }

        content = lines.joined(separator: "\n")
        try content.write(to: filePath, atomically: true, encoding: .utf8)
    }
}
