// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Nimbus: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Manage Nimbus feature configuration files.",
        discussion: """
            Updates the nimbus.fml.yaml include block with feature files from nimbus-features/.

            Use --refresh to refresh the include block with current feature files.
            Use --add to create a new feature YAML file.
            """
    )

    // MARK: - Constants

    private static let nimbusFmlPath = "firefox-ios/nimbus.fml.yaml"
    private static let nimbusFeaturesPath = "firefox-ios/nimbus-features"

    // MARK: - Options

    @Flag(name: .long, help: "Refresh the include block in nimbus.fml.yaml with current feature files.")
    var refresh = false

    @Option(name: .long, help: "Create a new feature YAML file (provide camelCase name).")
    var add: String?

    mutating func run() throws {
        // If neither flag is specified, show help
        guard refresh || add != nil else {
            print(Nimbus.helpMessage())
            return
        }

        let repo = try RepoDetector.requireValidRepo()

        if let featureName = add {
            try runAdd(featureName: featureName, repoRoot: repo.root)
        } else if refresh {
            try runUpdate(repoRoot: repo.root)
        }
    }

    // MARK: - Update Command

    private func runUpdate(repoRoot: URL) throws {
        print("💍 Updating nimbus.fml.yaml include block...")
        try updateNimbusFml(repoRoot: repoRoot)
        print("💍 Successfully updated nimbus.fml.yaml")
    }

    // MARK: - Add Command

    private func runAdd(featureName: String, repoRoot: URL) throws {
        // Standardize name to end with "Feature"
        let standardizedName = standardizeFeatureName(featureName)
        let fileName = "\(standardizedName).yaml"
        let newFilePath = repoRoot
            .appendingPathComponent(Self.nimbusFeaturesPath)
            .appendingPathComponent(fileName)

        // Create the feature file
        print("💍 Creating feature file for \(standardizedName)...")
        try writeFeatureTemplate(to: newFilePath, featureName: standardizedName)
        print("💍 Successfully added file: \(Self.nimbusFeaturesPath)/\(fileName)")

        // Update the FML include block
        try updateNimbusFml(repoRoot: repoRoot)
        print("💍 Successfully updated nimbus.fml.yaml")

        print("💍 Please remember to add this feature to the feature flag spreadsheet.")
    }

    // MARK: - FML Operations

    private func updateNimbusFml(repoRoot: URL) throws {
        let fmlPath = repoRoot.appendingPathComponent(Self.nimbusFmlPath)

        guard FileManager.default.fileExists(atPath: fmlPath.path) else {
            throw ValidationError("💥💍 nimbus.fml.yaml not found at \(fmlPath.path)")
        }

        // Read current content
        var content = try String(contentsOf: fmlPath, encoding: .utf8)

        // Remove existing nimbus-features lines
        let lines = content.components(separatedBy: "\n")
        let filteredLines = lines.filter { !$0.contains("nimbus-features") }
        content = filteredLines.joined(separator: "\n")

        // Add feature files
        let featuresDir = repoRoot.appendingPathComponent(Self.nimbusFeaturesPath)
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

    // MARK: - Feature Template

    private func writeFeatureTemplate(to url: URL, featureName: String) throws {
        let kebabName = camelToKebabCase(featureName)

        let template = """
            # The configuration for the \(featureName) feature
            # Please remember to add this feature to the feature flag spreadsheet.
            features:
              \(kebabName):
                description: >
                  Feature description
                variables:
                  new-variable:
                    description: >
                      Variable description
                    type: Boolean
                    default: false
                defaults:
                  - channel: beta
                    value:
                      new-variable: false
                  - channel: developer
                    value:
                      new-variable: false

            objects:

            enums:

            """
        try template.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - String Helpers

    private func camelToKebabCase(_ input: String) -> String {
        var result = ""
        for (index, char) in input.enumerated() {
            if char.isUppercase && index > 0 {
                result += "-"
            }
            result += char.lowercased()
        }
        return result
    }

    private func standardizeFeatureName(_ input: String) -> String {
        if input.hasSuffix("Feature") {
            return input
        }
        return "\(input)Feature"
    }
}
