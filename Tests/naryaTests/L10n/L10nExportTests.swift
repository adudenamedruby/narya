// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

/// Tests for L10n Export functionality.
@Suite("L10n Export Tests")
struct L10nExportTests {

    // MARK: - Locale Discovery Tests

    @Suite("Locale Discovery")
    struct LocaleDiscoveryTests {

        @Test("Discovers locales from directory structure")
        func discoversLocalesFromDirectories() throws {
            try withL10nTemporaryDirectory { tempDir in
                let locales = ["en-US", "fr", "de", "ja", "zh-Hans"]
                for locale in locales {
                    let localeDir = tempDir.appendingPathComponent(locale)
                    try FileManager.default.createDirectory(at: localeDir, withIntermediateDirectories: true)
                }

                let discovered = try L10nExportTask.discoverLocales(at: tempDir.path)

                #expect(discovered.count == 5)
                #expect(discovered.contains("en-US"))
                #expect(discovered.contains("fr"))
            }
        }

        @Test("Skips templates directory")
        func skipsTemplatesDirectory() throws {
            try withL10nTemporaryDirectory { tempDir in
                let dirs = ["en-US", "fr", "templates", "de"]
                for dir in dirs {
                    let dirPath = tempDir.appendingPathComponent(dir)
                    try FileManager.default.createDirectory(at: dirPath, withIntermediateDirectories: true)
                }

                let discovered = try L10nExportTask.discoverLocales(at: tempDir.path)

                #expect(discovered.count == 3)
                #expect(!discovered.contains("templates"))
            }
        }

        @Test("Sorts locales alphabetically")
        func sortsLocalesAlphabetically() throws {
            try withL10nTemporaryDirectory { tempDir in
                let locales = ["zh-Hans", "ar", "fr", "de", "en-US"]
                for locale in locales {
                    let localeDir = tempDir.appendingPathComponent(locale)
                    try FileManager.default.createDirectory(at: localeDir, withIntermediateDirectories: true)
                }

                let discovered = try L10nExportTask.discoverLocales(at: tempDir.path)

                #expect(discovered == ["ar", "de", "en-US", "fr", "zh-Hans"])
            }
        }
    }

    // MARK: - Comment Override Tests

    @Suite("Comment Overrides")
    struct CommentOverrideTests {

        @Test("Parses comment overrides file")
        func parsesCommentOverridesFile() throws {
            let content = """
            NSCameraUsageDescription=Used for QR code scanning
            NSLocationWhenInUseUsageDescription=Used for location features
            Menu.Open=Opens a new tab
            """

            let overrides = content
                .split(whereSeparator: \.isNewline)
                .reduce(into: [String: String]()) { result, item in
                    let items = item.split(separator: "=")
                    guard let key = items.first, let value = items.last else { return }
                    result[String(key)] = String(value)
                }

            #expect(overrides["NSCameraUsageDescription"] == "Used for QR code scanning")
            #expect(overrides["NSLocationWhenInUseUsageDescription"] == "Used for location features")
            #expect(overrides["Menu.Open"] == "Opens a new tab")
            #expect(overrides.count == 3)
        }

        @Test("Handles empty lines in comment overrides")
        func handlesEmptyLines() {
            let content = """
            Key1=Value1

            Key2=Value2

            """

            let overrides = content
                .split(whereSeparator: \.isNewline)
                .reduce(into: [String: String]()) { result, item in
                    let items = item.split(separator: "=")
                    guard let key = items.first, let value = items.last else { return }
                    result[String(key)] = String(value)
                }

            #expect(overrides.count == 2)
            #expect(overrides["Key1"] == "Value1")
            #expect(overrides["Key2"] == "Value2")
        }

        @Test("Returns empty dictionary for missing file")
        func returnsEmptyForMissingFile() throws {
            try withL10nTemporaryDirectory { tempDir in
                let nonExistentURL = tempDir.appendingPathComponent("nonexistent.txt")

                let overrides: [String: String] = (try? String(contentsOf: nonExistentURL))?
                    .split(whereSeparator: \.isNewline)
                    .reduce(into: [String: String]()) { result, item in
                        let items = item.split(separator: "=")
                        guard let key = items.first, let value = items.last else { return }
                        result[String(key)] = String(value)
                    } ?? [:]

                #expect(overrides.isEmpty)
            }
        }
    }

    // MARK: - Excluded Translations Tests

    @Suite("Export Excluded Translations")
    struct ExcludedTranslationsTests {

        @Test("Export excludes CFBundleName")
        func excludesCFBundleName() {
            #expect(L10nTranslationKeys.excludedForExport.contains("CFBundleName"))
        }

        @Test("Export excludes CFBundleDisplayName")
        func excludesCFBundleDisplayName() {
            #expect(L10nTranslationKeys.excludedForExport.contains("CFBundleDisplayName"))
        }

        @Test("Export excludes 1Password Fill Browser Action")
        func excludes1PasswordFillBrowserAction() {
            #expect(L10nTranslationKeys.excludedForExport.contains("1Password Fill Browser Action"))
        }
    }

    // MARK: - XLIFF Processing Tests

    @Suite("Export XLIFF Processing")
    struct XliffProcessingTests {

        @Test("Updates target-language using export mapping")
        func updatesTargetLanguage() throws {
            let processor = L10nXliffProcessor(
                excludedTranslations: [],
                mode: .export
            )

            let doc = createL10nTestXliff(
                targetLanguage: "ga",
                translations: [(id: "Test", source: "Test", target: "Test", note: nil)]
            )

            guard let root = doc.rootElement(),
                  let fileNode = try root.nodes(forXPath: "file").first as? XMLElement else {
                Issue.record("Failed to get file node")
                return
            }

            processor.updateTargetLanguage(fileNode, locale: "ga")

            let targetLang = fileNode.attribute(forName: "target-language")?.stringValue
            #expect(targetLang == "ga-IE")
        }

        @Test("Removes excluded translations during export")
        func removesExcludedTranslations() throws {
            let processor = L10nXliffProcessor(
                excludedTranslations: [
                    "CFBundleName",
                    "CFBundleDisplayName",
                    "1Password Fill Browser Action"
                ],
                mode: .export
            )

            let doc = createL10nTestXliff(translations: [
                (id: "CFBundleName", source: "Firefox", target: "Firefox", note: nil),
                (id: "1Password Fill Browser Action", source: "1Password", target: "1Password", note: nil),
                (id: "Menu.Open", source: "Open", target: "Ouvrir", note: nil),
            ])

            guard let root = doc.rootElement(),
                  let fileNode = try root.nodes(forXPath: "file").first as? XMLElement else {
                Issue.record("Failed to get file node")
                return
            }

            try processor.filterExcludedTranslations(fileNode, isActionExtension: false)

            let remaining = try fileNode.nodes(forXPath: "body/trans-unit")
            #expect(remaining.count == 1)

            if let transUnit = remaining.first as? XMLElement {
                #expect(transUnit.attribute(forName: "id")?.stringValue == "Menu.Open")
            }
        }
    }

    // MARK: - Task Configuration Tests

    @Suite("ExportTask Configuration")
    struct ConfigurationTests {

        @Test("Creates task with valid configuration")
        func createsTaskWithValidConfiguration() {
            let task = L10nExportTask(
                xcodeProjPath: "/path/to/project.xcodeproj",
                l10nRepoPath: "/path/to/l10n",
                locales: ["en", "fr", "de"],
                xliffName: "test.xliff",
                exportBasePath: "/tmp/export"
            )

            #expect(type(of: task) == L10nExportTask.self)
        }
    }

    // MARK: - Command Configuration Tests

    @Suite("Export Command Configuration")
    struct CommandConfigurationTests {

        @Test("Command has correct name")
        func commandName() {
            #expect(L10n.Export.configuration.commandName == "export")
        }

        @Test("Command has abstract")
        func commandAbstract() {
            #expect(!L10n.Export.configuration.abstract.isEmpty)
        }

        @Test("Command has discussion")
        func commandDiscussion() {
            #expect(!L10n.Export.configuration.discussion.isEmpty)
        }
    }
}
