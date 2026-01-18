// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

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
