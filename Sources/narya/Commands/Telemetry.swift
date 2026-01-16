// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

struct Telemetry: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Update telemetry configuration files in the firefox-ios repository.",
        discussion: """
            Updates glean_index.yaml and gleanProbes.xcfilelist with paths to metric YAML files.
            """
    )

    // MARK: - Constants

    private static let gleanIndexFile = "firefox-ios/Client/Glean/glean_index.yaml"
    private static let pathToFeatureYamls = "firefox-ios/Client/Glean/probes"
    private static let xcodeInfileList = "firefox-ios/Client/Glean/gleanProbes.xcfilelist"
    private static let tagsYamlFile = "firefox-ios/Client/Glean/tags.yaml"
    private static let storageMetricsYaml = "firefox-ios/Storage/metrics.yaml"

    // MARK: - Options

    @Flag(name: .long, help: "Refresh glean_index.yaml and gleanProbes.xcfilelist with current metric files.")
    var refresh = false

    @Option(name: .long, help: "Create a new metrics YAML for a feature (provide camelCase name).")
    var add: String?

    @Option(name: .long, help: "Description for the new tag in tags.yaml (used with --add).")
    var description: String?

    mutating func run() throws {
        // If neither flag is specified, show help
        guard refresh || add != nil else {
            print(Telemetry.helpMessage())
            return
        }

        // Can't specify both
        guard !(refresh && add != nil) else {
            throw ValidationError("💥💍 Cannot specify both --refresh and --add. Choose one.")
        }

        let repo = try RepoDetector.requireValidRepo()

        if refresh {
            try runUpdate(repoRoot: repo.root)
        } else if let featureName = add {
            try runAdd(featureName: featureName, description: description, repoRoot: repo.root)
        }
    }

    // MARK: - Update Command

    private func runUpdate(repoRoot: URL) throws {
        print("💍 Updating telemetry index files...")

        try updateIndexFile(repoRoot: repoRoot)
        print("💍 Successfully updated the glean index file.")

        try updateXcodeFileList(repoRoot: repoRoot)
        print("💍 Successfully updated the xcode build phase infile list.")
    }

    // MARK: - Add Command

    private func runAdd(featureName: String, description: String?, repoRoot: URL) throws {
        // Validate camelCase format
        if featureName.contains("_") || featureName.contains("-") {
            throw ValidationError("💥💍 Please enter a feature name in camelCase (not snake_case or kebab-case)")
        }

        let capitalizedTag = capitalizeFirst(featureName)
        let snakeCaseName = camelToSnakeCase(featureName)
        let newFilePath = "\(Self.pathToFeatureYamls)/\(snakeCaseName).yaml"
        let newFileURL = repoRoot.appendingPathComponent(newFilePath)

        // Create the new metrics YAML file
        print("💍 Creating metrics file for \(featureName)...")
        try writeMetricsTemplate(to: newFileURL, tagName: capitalizedTag)
        print("💍 Successfully added file: \(newFilePath)")

        // Update the glean index file
        try updateIndexFile(repoRoot: repoRoot)
        print("💍 Successfully updated the glean index file.")

        // Update the Xcode build phase input file list
        try updateXcodeFileList(repoRoot: repoRoot)
        print("💍 Successfully updated the xcode build phase infile list.")

        // Update tags.yaml
        let tagsFile = repoRoot.appendingPathComponent(Self.tagsYamlFile)
        if try updateTagsYaml(at: tagsFile, tagName: capitalizedTag, description: description) {
            print("💍 Successfully added \(capitalizedTag) tag to tags.yaml")
            if description == nil {
                print("💍 Please update the description in tags.yaml for the \(capitalizedTag) tag")
            }
        }
    }

    // MARK: - Index File Operations

    private func updateIndexFile(repoRoot: URL) throws {
        let indexFile = repoRoot.appendingPathComponent(Self.gleanIndexFile)

        // Read current content and truncate after "metrics_files:"
        var content = try String(contentsOf: indexFile, encoding: .utf8)
        if let range = content.range(of: "metrics_files:") {
            content = String(content[..<range.upperBound])
        }

        // Append metric file paths
        let probesDir = repoRoot.appendingPathComponent(Self.pathToFeatureYamls)
        let yamlFiles = try FileManager.default.contentsOfDirectory(at: probesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "yaml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        for file in yamlFiles {
            let relativePath = "\(Self.pathToFeatureYamls)/\(file.lastPathComponent)"
            content += "\n  - \(relativePath)"
        }

        // Add storage metrics
        content += "\n  - \(Self.storageMetricsYaml)"

        try content.write(to: indexFile, atomically: true, encoding: .utf8)
    }

    // MARK: - Xcode File List Operations

    private func updateXcodeFileList(repoRoot: URL) throws {
        let fileListPath = repoRoot.appendingPathComponent(Self.xcodeInfileList)

        var content = "# This is an autogenerated file using narya update telemetry\n"

        let probesDir = repoRoot.appendingPathComponent(Self.pathToFeatureYamls)
        let yamlFiles = try FileManager.default.contentsOfDirectory(at: probesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "yaml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        for file in yamlFiles {
            let relativePath = "Client/Glean/probes/\(file.lastPathComponent)"
            content += "$(PROJECT_DIR)/\(relativePath)\n"
        }

        try content.write(to: fileListPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Tags YAML Operations

    private func updateTagsYaml(at url: URL, tagName: String, description: String?) throws -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("💥💍 Warning: tags.yaml not found, skipping tag update")
            return false
        }

        var content = try String(contentsOf: url, encoding: .utf8)

        // Check if tag already exists
        if content.contains("\(tagName):") {
            print("💍 Tag \(tagName) already exists in tags.yaml")
            return false
        }

        let tagDescription = description ?? "TODO: Add description for \(tagName) tag"
        let newTagEntry = "\(tagName):\n  description: \(tagDescription)\n"

        // Parse existing tags and insert in alphabetical order
        var lines = content.components(separatedBy: "\n")
        var insertIndex: Int?

        for (index, line) in lines.enumerated() {
            // Look for lines that start a tag definition (capital letter at start)
            if let firstChar = line.first, firstChar.isUppercase, line.contains(":") {
                let existingTag = String(line.prefix(while: { $0 != ":" }))
                if tagName < existingTag {
                    insertIndex = index
                    break
                }
            }
        }

        if let index = insertIndex {
            lines.insert(newTagEntry, at: index)
            content = lines.joined(separator: "\n")
        } else {
            // Append at end
            if !content.hasSuffix("\n") {
                content += "\n"
            }
            content += "\n\(newTagEntry)"
        }

        try content.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    // MARK: - Metrics Template

    private func writeMetricsTemplate(to url: URL, tagName: String) throws {
        let template = """
            # This Source Code Form is subject to the terms of the Mozilla Public
            # License, v. 2.0. If a copy of the MPL was not distributed with this
            # file, You can obtain one at http://mozilla.org/MPL/2.0/.

            # This file defines the metrics that are recorded by the Glean SDK. They are
            # automatically converted to Swift code at build time using the `glean_parser`
            # PyPI package.

            # This file is organized (roughly) alphabetically by metric names
            # for easy navigation

            ---
            $schema: moz://mozilla.org/schemas/glean/metrics/2-0-0

            $tags:
              - \(tagName)

            ###############################################################################
            # Documentation
            ###############################################################################

            # Add your new metrics and/or events here.

            """
        try template.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - String Helpers

    private func camelToSnakeCase(_ input: String) -> String {
        var result = ""
        for (index, char) in input.enumerated() {
            if char.isUppercase && index > 0 {
                result += "_"
            }
            result += char.lowercased()
        }
        return result
    }

    private func capitalizeFirst(_ input: String) -> String {
        guard let first = input.first else { return input }
        return first.uppercased() + input.dropFirst()
    }
}
