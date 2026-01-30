// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

/// Tests for L10n Templates functionality.
@Suite("L10n Templates Tests")
struct L10nTemplatesTests {
    // MARK: - Task Configuration Tests

    @Suite("Template Task Configuration")
    struct TaskConfigurationTests {
        @Test("Creates task with valid configuration")
        func createsTaskWithValidConfiguration() {
            let task = L10nTemplatesTask(
                l10nRepoPath: "/path/to/l10n",
                xliffName: "firefox-ios.xliff"
            )

            #expect(type(of: task) == L10nTemplatesTask.self)
        }
    }

    // MARK: - XML Transformation Tests

    @Suite("Template XML Transformations")
    struct XmlTransformationTests {

        @Test("Removes target-language attribute from file nodes")
        func removesTargetLanguageAttribute() throws {
            let doc = createL10nTestXliff(
                targetLanguage: "en-US",
                translations: [
                    (id: "Test", source: "Test", target: "Test", note: nil),
                ]
            )

            guard let root = doc.rootElement() else {
                Issue.record("Failed to get root element")
                return
            }

            // Simulate the template transformation
            try root.nodes(forXPath: "file").forEach { node in
                guard let fileNode = node as? XMLElement else { return }
                fileNode.removeAttribute(forName: "target-language")
            }

            let fileNode = try root.nodes(forXPath: "file").first as? XMLElement
            #expect(fileNode?.attribute(forName: "target-language") == nil)
            #expect(fileNode?.attribute(forName: "source-language")?.stringValue == "en")
        }

        @Test("Removes all target elements")
        func removesAllTargetElements() throws {
            let doc = createL10nTestXliff(translations: [
                (id: "Key1", source: "Source1", target: "Target1", note: nil),
                (id: "Key2", source: "Source2", target: "Target2", note: nil),
                (id: "Key3", source: "Source3", target: "Target3", note: nil),
            ])

            guard let root = doc.rootElement() else {
                Issue.record("Failed to get root element")
                return
            }

            // Verify targets exist before transformation
            let targetsBefore = try root.nodes(forXPath: "file/body/trans-unit/target")
            #expect(targetsBefore.count == 3)

            // Simulate the template transformation
            try root.nodes(forXPath: "file/body/trans-unit/target").forEach { $0.detach() }

            // Verify targets are removed
            let targetsAfter = try root.nodes(forXPath: "file/body/trans-unit/target")
            #expect(targetsAfter.isEmpty)
        }

        @Test("Preserves source elements")
        func preservesSourceElements() throws {
            let doc = createL10nTestXliff(translations: [
                (id: "Key1", source: "Hello", target: "Bonjour", note: nil),
                (id: "Key2", source: "World", target: "Monde", note: nil),
            ])

            guard let root = doc.rootElement() else {
                Issue.record("Failed to get root element")
                return
            }

            // Simulate the template transformation (remove targets)
            try root.nodes(forXPath: "file/body/trans-unit/target").forEach { $0.detach() }

            // Verify sources are preserved
            let sources = try root.nodes(forXPath: "file/body/trans-unit/source")
            #expect(sources.count == 2)

            let sourceValues = sources.compactMap { $0.stringValue }
            #expect(sourceValues.contains("Hello"))
            #expect(sourceValues.contains("World"))
        }

        @Test("Preserves note elements")
        func preservesNoteElements() throws {
            let doc = createL10nTestXliff(translations: [
                (id: "Key1", source: "Hello", target: "Bonjour", note: "Greeting"),
                (id: "Key2", source: "Settings", target: "Parametres", note: "App settings"),
            ])

            guard let root = doc.rootElement() else {
                Issue.record("Failed to get root element")
                return
            }

            // Simulate the template transformation (remove targets)
            try root.nodes(forXPath: "file/body/trans-unit/target").forEach { $0.detach() }

            // Verify notes are preserved
            let notes = try root.nodes(forXPath: "file/body/trans-unit/note")
            #expect(notes.count == 2)

            let noteValues = notes.compactMap { $0.stringValue }
            #expect(noteValues.contains("Greeting"))
            #expect(noteValues.contains("App settings"))
        }

        @Test("Handles XLIFF with no target elements")
        func handlesXliffWithNoTargets() throws {
            let doc = createL10nTestXliff(translations: [
                (id: "Key1", source: "Source1", target: nil, note: "Note1"),
                (id: "Key2", source: "Source2", target: nil, note: "Note2"),
            ])

            guard let root = doc.rootElement() else {
                Issue.record("Failed to get root element")
                return
            }

            // Verify no targets exist
            let targetsBefore = try root.nodes(forXPath: "file/body/trans-unit/target")
            #expect(targetsBefore.isEmpty)

            // Transformation should succeed without error
            try root.nodes(forXPath: "file/body/trans-unit/target").forEach { $0.detach() }

            // Sources should still be there
            let sources = try root.nodes(forXPath: "file/body/trans-unit/source")
            #expect(sources.count == 2)
        }

        @Test("Produces valid template structure")
        func producesValidTemplateStructure() throws {
            let doc = createL10nTestXliff(
                sourceLanguage: "en",
                targetLanguage: "en-US",
                translations: [
                    (id: "Menu.Open", source: "Open", target: "Open", note: "Opens a new tab"),
                    (id: "Menu.Close", source: "Close", target: "Close", note: "Closes current tab"),
                ]
            )

            guard let root = doc.rootElement() else {
                Issue.record("Failed to get root element")
                return
            }

            // Apply full template transformation
            try root.nodes(forXPath: "file").forEach { node in
                guard let fileNode = node as? XMLElement else { return }
                fileNode.removeAttribute(forName: "target-language")
            }
            try root.nodes(forXPath: "file/body/trans-unit/target").forEach { $0.detach() }

            // Verify the result is a valid template
            let fileNodes = try root.nodes(forXPath: "file")
            #expect(fileNodes.count == 1)

            let fileNode = fileNodes.first as? XMLElement
            #expect(fileNode?.attribute(forName: "source-language")?.stringValue == "en")
            #expect(fileNode?.attribute(forName: "target-language") == nil)

            let transUnits = try root.nodes(forXPath: "file/body/trans-unit")
            #expect(transUnits.count == 2)

            for case let transUnit as XMLElement in transUnits {
                let sources = try transUnit.nodes(forXPath: "source")
                let targets = try transUnit.nodes(forXPath: "target")
                let notes = try transUnit.nodes(forXPath: "note")

                #expect(sources.count == 1, "Each trans-unit should have exactly one source")
                #expect(targets.isEmpty, "Template trans-units should have no targets")
                #expect(notes.count == 1, "Each trans-unit should have exactly one note")
            }
        }
    }

    // MARK: - Command Configuration Tests

    @Suite("Templates Command Configuration")
    struct CommandConfigurationTests {

        @Test("Command has correct name")
        func commandName() {
            #expect(L10n.Templates.configuration.commandName == "templates")
        }

        @Test("Command has abstract")
        func commandAbstract() {
            #expect(!L10n.Templates.configuration.abstract.isEmpty)
        }

        @Test("Command has discussion")
        func commandDiscussion() {
            #expect(!L10n.Templates.configuration.discussion.isEmpty)
        }
    }
}
