// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

/// Tests for L10nXliffProcessor shared XML utilities.
@Suite("L10nXliffProcessor Tests")
struct L10nXliffProcessorTests {

    // MARK: - Test Fixtures

    /// Standard processor configured like ImportTask
    let importProcessor = L10nXliffProcessor(
        excludedTranslations: L10nTranslationKeys.excludedForImport,
        mode: .import
    )

    /// Standard processor configured like ExportTask
    let exportProcessor = L10nXliffProcessor(
        excludedTranslations: L10nTranslationKeys.excludedForExport,
        mode: .export
    )

    // MARK: - ActionExtension Identification Tests

    @Suite("ActionExtension File Identification")
    struct ActionExtensionTests {

        let processor = L10nXliffProcessor(excludedTranslations: [], mode: .import)

        @Test("Identifies ActionExtension InfoPlist file")
        func identifiesActionExtensionInfoPlist() {
            let fileNode = XMLElement(name: "file")
            fileNode.addAttribute(XMLNode.attribute(
                withName: "original",
                stringValue: "Extensions/ActionExtension/en.lproj/InfoPlist.strings"
            ) as! XMLNode)

            #expect(processor.isActionExtensionFile(fileNode) == true)
        }

        @Test("Rejects non-ActionExtension paths")
        func rejectsNonActionExtensionPaths() {
            let testCases = [
                "Client/en.lproj/InfoPlist.strings",
                "Extensions/ShareExtension/en.lproj/InfoPlist.strings",
                "Extensions/ActionExtension/en.lproj/Localizable.strings",
                "Client/Strings.swift",
            ]

            for path in testCases {
                let fileNode = XMLElement(name: "file")
                fileNode.addAttribute(XMLNode.attribute(
                    withName: "original",
                    stringValue: path
                ) as! XMLNode)

                #expect(processor.isActionExtensionFile(fileNode) == false,
                       "Path '\(path)' should not be identified as ActionExtension")
            }
        }

        @Test("Handles file node without original attribute")
        func handlesNodeWithoutOriginalAttribute() {
            let fileNode = XMLElement(name: "file")
            #expect(processor.isActionExtensionFile(fileNode) == false)
        }
    }

    // MARK: - Target Language Mapping Tests

    @Suite("Target Language Mapping")
    struct TargetLanguageMappingTests {

        @Test("Maps import locales correctly",
              arguments: [
                ("ga-IE", "ga"),
                ("nb-NO", "nb"),
                ("nn-NO", "nn"),
                ("sv-SE", "sv"),
                ("tl", "fil"),
                ("sat", "sat-Olck"),
                ("zgh", "tzm"),
              ])
        func mapsImportLocalesCorrectly(input: String, expected: String) {
            let processor = L10nXliffProcessor(excludedTranslations: [], mode: .import)

            let fileNode = XMLElement(name: "file")
            fileNode.addAttribute(XMLNode.attribute(
                withName: "target-language",
                stringValue: input
            ) as! XMLNode)

            processor.updateTargetLanguage(fileNode, locale: input)

            let updatedValue = fileNode.attribute(forName: "target-language")?.stringValue
            #expect(updatedValue == expected)
        }

        @Test("Maps export locales correctly",
              arguments: [
                ("ga", "ga-IE"),
                ("nb", "nb-NO"),
                ("nn", "nn-NO"),
                ("sv", "sv-SE"),
                ("fil", "tl"),
                ("sat-Olck", "sat"),
              ])
        func mapsExportLocalesCorrectly(input: String, expected: String) {
            let processor = L10nXliffProcessor(excludedTranslations: [], mode: .export)

            let fileNode = XMLElement(name: "file")
            fileNode.addAttribute(XMLNode.attribute(
                withName: "target-language",
                stringValue: input
            ) as! XMLNode)

            processor.updateTargetLanguage(fileNode, locale: input)

            let updatedValue = fileNode.attribute(forName: "target-language")?.stringValue
            #expect(updatedValue == expected)
        }

        @Test("Preserves unmapped locales")
        func preservesUnmappedLocales() {
            let processor = L10nXliffProcessor(excludedTranslations: [], mode: .import)

            let fileNode = XMLElement(name: "file")
            fileNode.addAttribute(XMLNode.attribute(
                withName: "target-language",
                stringValue: "fr"
            ) as! XMLNode)

            processor.updateTargetLanguage(fileNode, locale: "fr")

            let updatedValue = fileNode.attribute(forName: "target-language")?.stringValue
            #expect(updatedValue == "fr")
        }
    }

    // MARK: - Translation Exclusion Logic Tests

    @Suite("Translation Exclusion Logic")
    struct TranslationExclusionTests {

        let processor = L10nXliffProcessor(
            excludedTranslations: L10nTranslationKeys.excludedForImport,
            mode: .import
        )

        @Test("Excludes CFBundleName")
        func excludesCFBundleName() {
            #expect(processor.shouldExcludeTranslation(id: "CFBundleName", isActionExtension: false) == true)
        }

        @Test("Excludes CFBundleDisplayName in non-ActionExtension files")
        func excludesCFBundleDisplayName() {
            #expect(processor.shouldExcludeTranslation(id: "CFBundleDisplayName", isActionExtension: false) == true)
        }

        @Test("Excludes CFBundleShortVersionString")
        func excludesCFBundleShortVersionString() {
            #expect(processor.shouldExcludeTranslation(id: "CFBundleShortVersionString", isActionExtension: false) == true)
        }

        @Test("Allows CFBundleDisplayName in ActionExtension files")
        func allowsCFBundleDisplayNameInActionExtension() {
            #expect(processor.shouldExcludeTranslation(id: "CFBundleDisplayName", isActionExtension: true) == false)
        }

        @Test("Allows non-excluded translations")
        func allowsNonExcludedTranslations() {
            let allowed = [
                "NSCameraUsageDescription",
                "Menu.OpenNewTab",
                "Settings.Title",
            ]

            for id in allowed {
                #expect(processor.shouldExcludeTranslation(id: id, isActionExtension: false) == false,
                       "'\(id)' should not be excluded")
            }
        }

        @Test("Handles nil translation ID")
        func handlesNilTranslationId() {
            #expect(processor.shouldExcludeTranslation(id: nil, isActionExtension: false) == false)
        }
    }

    // MARK: - Translation Filtering Tests

    @Suite("Translation Filtering")
    struct TranslationFilteringTests {

        @Test("Removes excluded translations from file node")
        func removesExcludedTranslations() throws {
            let processor = L10nXliffProcessor(
                excludedTranslations: ["CFBundleName", "CFBundleDisplayName"],
                mode: .import
            )

            let doc = createL10nTestXliff(translations: [
                (id: "CFBundleName", source: "Firefox", target: "Firefox", note: nil),
                (id: "CFBundleDisplayName", source: "Firefox", target: "Firefox", note: nil),
                (id: "NSCameraUsageDescription", source: "Camera", target: "Kamera", note: nil),
            ])

            guard let root = doc.rootElement(),
                  let fileNode = try root.nodes(forXPath: "file").first as? XMLElement else {
                Issue.record("Failed to get file node")
                return
            }

            try processor.filterExcludedTranslations(fileNode, isActionExtension: false)

            let remainingTranslations = try fileNode.nodes(forXPath: "body/trans-unit")
            #expect(remainingTranslations.count == 1)

            if let transUnit = remainingTranslations.first as? XMLElement {
                #expect(transUnit.attribute(forName: "id")?.stringValue == "NSCameraUsageDescription")
            }
        }

        @Test("Preserves allowed translations")
        func preservesAllowedTranslations() throws {
            let processor = L10nXliffProcessor(
                excludedTranslations: ["CFBundleName"],
                mode: .import
            )

            let doc = createL10nTestXliff(translations: [
                (id: "Menu.OpenNewTab", source: "Open New Tab", target: "Nouvel onglet", note: nil),
                (id: "Menu.Settings", source: "Settings", target: "Parametres", note: nil),
            ])

            guard let root = doc.rootElement(),
                  let fileNode = try root.nodes(forXPath: "file").first as? XMLElement else {
                Issue.record("Failed to get file node")
                return
            }

            try processor.filterExcludedTranslations(fileNode, isActionExtension: false)

            let remainingTranslations = try fileNode.nodes(forXPath: "body/trans-unit")
            #expect(remainingTranslations.count == 2)
        }
    }

    // MARK: - Empty File Node Removal Tests

    @Suite("Empty File Node Removal")
    struct EmptyFileNodeRemovalTests {

        @Test("Removes empty file nodes")
        func removesEmptyFileNodes() throws {
            let processor = L10nXliffProcessor(excludedTranslations: [], mode: .import)

            let doc = createL10nTestXliff(translations: [])

            guard let root = doc.rootElement(),
                  let fileNode = try root.nodes(forXPath: "file").first as? XMLElement else {
                Issue.record("Failed to get file node")
                return
            }

            try processor.removeIfEmpty(fileNode)

            let remainingFiles = try root.nodes(forXPath: "file")
            #expect(remainingFiles.isEmpty)
        }

        @Test("Preserves non-empty file nodes")
        func preservesNonEmptyFileNodes() throws {
            let processor = L10nXliffProcessor(excludedTranslations: [], mode: .import)

            let doc = createL10nTestXliff(translations: [
                (id: "Test.Key", source: "Test", target: "Test", note: nil),
            ])

            guard let root = doc.rootElement(),
                  let fileNode = try root.nodes(forXPath: "file").first as? XMLElement else {
                Issue.record("Failed to get file node")
                return
            }

            try processor.removeIfEmpty(fileNode)

            let remainingFiles = try root.nodes(forXPath: "file")
            #expect(remainingFiles.count == 1)
        }
    }

    // MARK: - XPath Query Tests

    @Suite("XPath Queries")
    struct XPathQueryTests {

        let processor = L10nXliffProcessor(excludedTranslations: [], mode: .import)

        @Test("Queries all trans-unit elements")
        func queriesAllTransUnits() throws {
            let doc = createL10nTestXliff(translations: [
                (id: "Key1", source: "Source1", target: "Target1", note: nil),
                (id: "Key2", source: "Source2", target: "Target2", note: nil),
                (id: "Key3", source: "Source3", target: "Target3", note: nil),
            ])

            guard let root = doc.rootElement(),
                  let fileNode = try root.nodes(forXPath: "file").first as? XMLElement else {
                Issue.record("Failed to get file node")
                return
            }

            let translations = try processor.queryTranslations(in: fileNode)
            #expect(translations.count == 3)
        }

        @Test("Queries all file nodes")
        func queriesAllFileNodes() throws {
            let doc = createL10nMultiFileXliff(files: [
                (path: "File1.strings", translations: [(id: "Key1", source: "S1", target: "T1", note: nil)]),
                (path: "File2.strings", translations: [(id: "Key2", source: "S2", target: "T2", note: nil)]),
            ])

            guard let root = doc.rootElement() else {
                Issue.record("Failed to get root element")
                return
            }

            let fileNodes = try processor.queryFileNodes(in: root)
            #expect(fileNodes.count == 2)
        }
    }

    // MARK: - Process File Nodes Integration Tests

    @Suite("Process File Nodes Pipeline")
    struct ProcessFileNodesPipelineTests {

        @Test("Processes file nodes with full pipeline")
        func processesFileNodesWithFullPipeline() throws {
            let processor = L10nXliffProcessor(
                excludedTranslations: ["CFBundleName", "CFBundleDisplayName"],
                mode: .import
            )

            let doc = createL10nMultiFileXliff(
                targetLanguage: "ga-IE",
                files: [
                    (path: "Client/InfoPlist.strings", translations: [
                        (id: "CFBundleName", source: "Firefox", target: "Firefox", note: nil),
                        (id: "NSCameraUsageDescription", source: "Camera", target: "Ceamara", note: nil),
                    ]),
                    (path: "Extensions/ActionExtension/en.lproj/InfoPlist.strings", translations: [
                        (id: "CFBundleDisplayName", source: "Open in Firefox", target: "Oscail i Firefox", note: nil),
                    ]),
                ]
            )

            guard let root = doc.rootElement() else {
                Issue.record("Failed to get root element")
                return
            }

            let fileNodes = try processor.queryFileNodes(in: root)
            try processor.processFileNodes(fileNodes, locale: "ga-IE")

            // Check target-language was updated
            let updatedFileNodes = try root.nodes(forXPath: "file")
            for case let fileNode as XMLElement in updatedFileNodes {
                let targetLang = fileNode.attribute(forName: "target-language")?.stringValue
                #expect(targetLang == "ga")
            }

            // Check excluded translations were removed from non-ActionExtension file
            let clientTranslations = try root.nodes(forXPath: "file[contains(@original, 'Client/InfoPlist')]/body/trans-unit")
            #expect(clientTranslations.count == 1)

            // Check CFBundleDisplayName preserved in ActionExtension file
            let actionExtTranslations = try root.nodes(forXPath: "file[contains(@original, 'ActionExtension')]/body/trans-unit")
            #expect(actionExtTranslations.count == 1)
        }

        @Test("Calls additional processing closure")
        func callsAdditionalProcessingClosure() throws {
            let processor = L10nXliffProcessor(excludedTranslations: [], mode: .import)

            let doc = createL10nTestXliff(translations: [
                (id: "Key1", source: "Source", target: "Target", note: nil),
            ])

            guard let root = doc.rootElement() else {
                Issue.record("Failed to get root element")
                return
            }

            var processingCalled = false
            let fileNodes = try processor.queryFileNodes(in: root)

            try processor.processFileNodes(fileNodes, locale: "en") { _ in
                processingCalled = true
            }

            #expect(processingCalled == true)
        }
    }
}
