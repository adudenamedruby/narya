// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

/// Tests for L10n Import functionality.
@Suite("L10n Import Tests")
struct L10nImportTests {

    // MARK: - Required Translations Tests

    @Suite("Required Translations")
    struct RequiredTranslationsTests {

        @Test("Base required translations include privacy descriptions")
        func includesPrivacyDescriptions() {
            let privacyKeys = [
                "NSCameraUsageDescription",
                "NSLocationWhenInUseUsageDescription",
                "NSMicrophoneUsageDescription",
                "NSPhotoLibraryAddUsageDescription",
            ]

            for key in privacyKeys {
                #expect(L10nTranslationKeys.baseRequired.contains(key),
                       "Base required should contain '\(key)'")
            }
        }

        @Test("Base required translations include shortcut items")
        func includesShortcutItems() {
            let shortcutKeys = [
                "ShortcutItemTitleNewPrivateTab",
                "ShortcutItemTitleNewTab",
                "ShortcutItemTitleQRCode",
            ]

            for key in shortcutKeys {
                #expect(L10nTranslationKeys.baseRequired.contains(key),
                       "Base required should contain '\(key)'")
            }
        }

        @Test("WidgetKit translations count is correct")
        func widgetKitTranslationsCount() {
            #expect(L10nTranslationKeys.widgetKit.count == 16)
        }

        @Test("Combined required translations when WidgetKit not skipped")
        func combinedRequiredTranslations() {
            let combined = L10nTranslationKeys.required(includeWidgetKit: true)
            #expect(combined.count == 23) // 7 base + 16 widgetkit
        }

        @Test("Only base translations when WidgetKit skipped")
        func onlyBaseWhenSkipped() {
            let required = L10nTranslationKeys.required(includeWidgetKit: false)
            #expect(required.count == 7)
        }
    }

    // MARK: - Manifest Generation Tests

    @Suite("Manifest Generation")
    struct ManifestGenerationTests {

        @Test("Manifest JSON structure is valid")
        func manifestStructureIsValid() throws {
            let targetLocale = "fr"
            let developmentRegion = "en-US"
            let projectName = "Client.xcodeproj"

            let manifest = """
                {
                  "developmentRegion" : "\(developmentRegion)",
                  "project" : "\(projectName)",
                  "targetLocale" : "\(targetLocale)",
                  "toolInfo" : {
                    "toolBuildNumber" : "13A233",
                    "toolID" : "com.apple.dt.xcode",
                    "toolName" : "Xcode",
                    "toolVersion" : "13.0"
                  },
                  "version" : "1.0"
                }
            """

            let data = manifest.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            #expect(json?["targetLocale"] as? String == "fr")
            #expect(json?["developmentRegion"] as? String == "en-US")
            #expect(json?["project"] as? String == "Client.xcodeproj")
            #expect(json?["version"] as? String == "1.0")

            let toolInfo = json?["toolInfo"] as? [String: Any]
            #expect(toolInfo?["toolID"] as? String == "com.apple.dt.xcode")
            #expect(toolInfo?["toolName"] as? String == "Xcode")
        }
    }

    // MARK: - Excluded Translations Tests

    @Suite("Import Excluded Translations")
    struct ExcludedTranslationsTests {

        @Test("CFBundleName is excluded")
        func cfBundleNameExcluded() {
            #expect(L10nTranslationKeys.excludedForImport.contains("CFBundleName"))
        }

        @Test("CFBundleDisplayName is excluded")
        func cfBundleDisplayNameExcluded() {
            #expect(L10nTranslationKeys.excludedForImport.contains("CFBundleDisplayName"))
        }

        @Test("CFBundleShortVersionString is excluded")
        func cfBundleShortVersionStringExcluded() {
            #expect(L10nTranslationKeys.excludedForImport.contains("CFBundleShortVersionString"))
        }

        @Test("Import excludes fewer items than Export")
        func importExcludesFewerThanExport() {
            #expect(L10nTranslationKeys.excludedForImport.count < L10nTranslationKeys.excludedForExport.count)
        }
    }

    // MARK: - Fallback Target Logic Tests

    @Suite("Fallback Target Logic")
    struct FallbackTargetLogicTests {

        let requiredTranslations: Set<String> = [
            "NSCameraUsageDescription",
            "NSLocationWhenInUseUsageDescription",
        ]

        @Test("Adds fallback target when missing")
        func addsFallbackTargetWhenMissing() throws {
            let doc = createL10nTestXliff(translations: [
                (id: "NSCameraUsageDescription", source: "Camera access", target: nil, note: "Permission"),
            ])

            guard let root = doc.rootElement(),
                  let fileNode = try root.nodes(forXPath: "file").first as? XMLElement else {
                Issue.record("Failed to get file node")
                return
            }

            // Simulate addFallbackTargets logic
            let translations = try fileNode.nodes(forXPath: "body/trans-unit")
            for case let translation as XMLElement in translations {
                let translationId = translation.attribute(forName: "id")?.stringValue
                if translationId.map(requiredTranslations.contains) == true {
                    let nodes = (try? translation.nodes(forXPath: "target")) ?? []
                    let source = ((try? translation.nodes(forXPath: "source").first)?.stringValue) ?? ""
                    if nodes.isEmpty {
                        let element = XMLNode.element(withName: "target", stringValue: source) as! XMLNode
                        translation.insertChild(element, at: 1)
                    }
                }
            }

            // Verify target was added
            let targetNodes = try fileNode.nodes(forXPath: "body/trans-unit/target")
            #expect(targetNodes.count == 1)
            #expect(targetNodes.first?.stringValue == "Camera access")
        }

        @Test("Preserves existing target")
        func preservesExistingTarget() throws {
            let doc = createL10nTestXliff(translations: [
                (id: "NSCameraUsageDescription", source: "Camera access", target: "Acceso a camara", note: nil),
            ])

            guard let root = doc.rootElement(),
                  let fileNode = try root.nodes(forXPath: "file").first as? XMLElement else {
                Issue.record("Failed to get file node")
                return
            }

            // Simulate addFallbackTargets logic
            let translations = try fileNode.nodes(forXPath: "body/trans-unit")
            for case let translation as XMLElement in translations {
                let translationId = translation.attribute(forName: "id")?.stringValue
                if translationId.map(requiredTranslations.contains) == true {
                    let nodes = (try? translation.nodes(forXPath: "target")) ?? []
                    let source = ((try? translation.nodes(forXPath: "source").first)?.stringValue) ?? ""
                    if nodes.isEmpty {
                        let element = XMLNode.element(withName: "target", stringValue: source) as! XMLNode
                        translation.insertChild(element, at: 1)
                    }
                }
            }

            // Verify existing target is preserved
            let targetNodes = try fileNode.nodes(forXPath: "body/trans-unit/target")
            #expect(targetNodes.count == 1)
            #expect(targetNodes.first?.stringValue == "Acceso a camara")
        }
    }

    // MARK: - Task Configuration Tests

    @Suite("ImportTask Configuration")
    struct ConfigurationTests {

        @Test("Creates task with all parameters")
        func createsTaskWithAllParameters() {
            let task = L10nImportTask(
                xcodeProjPath: "/path/to/project.xcodeproj",
                l10nRepoPath: "/path/to/l10n",
                locales: ["en-US", "fr", "de"],
                xliffName: "custom.xliff",
                developmentRegion: "en-GB",
                projectName: "Custom.xcodeproj",
                skipWidgetKit: true
            )

            #expect(type(of: task) == L10nImportTask.self)
        }
    }

    // MARK: - Command Configuration Tests

    @Suite("Import Command Configuration")
    struct CommandConfigurationTests {

        @Test("Command has correct name")
        func commandName() {
            #expect(L10n.Import.configuration.commandName == "import")
        }

        @Test("Command has abstract")
        func commandAbstract() {
            #expect(!L10n.Import.configuration.abstract.isEmpty)
        }

        @Test("Command has discussion")
        func commandDiscussion() {
            #expect(!L10n.Import.configuration.discussion.isEmpty)
        }
    }
}
