// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

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
        StringUtils.camelToKebabCase(input)
    }

    /// Converts camelCase to Title Case (e.g., "testButtress" -> "Test Buttress")
    static func camelToTitleCase(_ input: String) -> String {
        StringUtils.camelToTitleCase(input)
    }

    /// Capitalizes the first letter of a string
    static func capitalizeFirst(_ input: String) -> String {
        StringUtils.capitalizeFirst(input)
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
