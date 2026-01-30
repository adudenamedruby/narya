// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import narya

/// Tests for the main L10n command and its configuration.
@Suite("L10n Command Tests")
struct L10nCommandTests {
    // MARK: - Command Configuration Tests

    @Suite("Command Configuration")
    struct ConfigurationTests {
        @Test("Command has correct name")
        func commandName() {
            #expect(L10n.configuration.commandName == "l10n")
        }

        @Test("Command has abstract")
        func commandAbstract() {
            #expect(!L10n.configuration.abstract.isEmpty)
            #expect(L10n.configuration.abstract.contains("Localization"))
        }

        @Test("Command has discussion")
        func commandDiscussion() {
            #expect(!L10n.configuration.discussion.isEmpty)
        }

        @Test("Command has three subcommands")
        func hasThreeSubcommands() {
            #expect(L10n.configuration.subcommands.count == 3)
        }

        @Test("Subcommands include Export")
        func includesExportSubcommand() {
            let subcommandTypes = L10n.configuration.subcommands.map { String(describing: $0) }
            #expect(subcommandTypes.contains("Export"))
        }

        @Test("Subcommands include Import")
        func includesImportSubcommand() {
            let subcommandTypes = L10n.configuration.subcommands.map { String(describing: $0) }
            #expect(subcommandTypes.contains("Import"))
        }

        @Test("Subcommands include Templates")
        func includesTemplatesSubcommand() {
            let subcommandTypes = L10n.configuration.subcommands.map { String(describing: $0) }
            #expect(subcommandTypes.contains("Templates"))
        }
    }

    // MARK: - Default Values Tests
    //
    // Note: Values like xliffName, developmentRegion, projectName, exportBasePath, and skipWidgetKit
    // are now optional at parse time and resolved at runtime from product presets or config defaults.

    @Suite("Default Values")
    struct DefaultValuesTests {

        @Test("XLIFF name is nil by default (resolved at runtime from product)")
        func defaultXliffNameIsNil() throws {
            let exportCommand = try L10n.Export.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test"
            ])
            #expect(exportCommand.xliffName == nil)
        }

        @Test("Development region is nil by default (resolved at runtime from product)")
        func defaultDevelopmentRegionIsNil() throws {
            let importCommand = try L10n.Import.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test"
            ])
            #expect(importCommand.developmentRegion == nil)
        }

        @Test("Project name is nil by default (resolved at runtime from product)")
        func defaultProjectNameIsNil() throws {
            let importCommand = try L10n.Import.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test"
            ])
            #expect(importCommand.projectName == nil)
        }

        @Test("Export base path is nil by default (resolved at runtime from product)")
        func defaultExportBasePathIsNil() throws {
            let exportCommand = try L10n.Export.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test"
            ])
            #expect(exportCommand.exportBasePath == nil)
        }

        @Test("skipWidgetKit is nil by default (resolved at runtime from product)")
        func defaultSkipWidgetKitIsNil() throws {
            let importCommand = try L10n.Import.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test"
            ])
            #expect(importCommand.skipWidgetKit == nil)
        }

        @Test("Default createTemplates is false")
        func defaultCreateTemplates() throws {
            let exportCommand = try L10n.Export.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test"
            ])
            #expect(exportCommand.createTemplates == false)
        }
    }

    // MARK: - Argument Parsing Tests

    @Suite("Argument Parsing")
    struct ArgumentParsingTests {

        @Test("Export parses project-path option")
        func exportParsesProjectPath() throws {
            let command = try L10n.Export.parse([
                "--project-path", "/path/to/project.xcodeproj",
                "--l10n-project-path", "/path/to/l10n"
            ])
            #expect(command.projectPath == "/path/to/project.xcodeproj")
        }

        @Test("Export parses l10n-project-path option")
        func exportParsesL10nProjectPath() throws {
            let command = try L10n.Export.parse([
                "--project-path", "/path/to/project.xcodeproj",
                "--l10n-project-path", "/path/to/l10n"
            ])
            #expect(command.l10nProjectPath == "/path/to/l10n")
        }

        @Test("Export parses locale option")
        func exportParsesLocale() throws {
            let command = try L10n.Export.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test",
                "--locale", "fr"
            ])
            #expect(command.localeCode == "fr")
        }

        @Test("Export parses xliff-name option")
        func exportParsesXliffName() throws {
            let command = try L10n.Export.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test",
                "--xliff-name", "custom.xliff"
            ])
            #expect(command.xliffName == "custom.xliff")
        }

        @Test("Export parses create-templates flag")
        func exportParsesCreateTemplates() throws {
            let command = try L10n.Export.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test",
                "--create-templates"
            ])
            #expect(command.createTemplates == true)
        }

        @Test("Import parses skip-widget-kit flag")
        func importParsesSkipWidgetKit() throws {
            let command = try L10n.Import.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test",
                "--skip-widget-kit"
            ])
            #expect(command.skipWidgetKit == true)
        }

        @Test("Import parses development-region option")
        func importParsesDevelopmentRegion() throws {
            let command = try L10n.Import.parse([
                "--project-path", "/test",
                "--l10n-project-path", "/test",
                "--development-region", "en-GB"
            ])
            #expect(command.developmentRegion == "en-GB")
        }
    }
}
