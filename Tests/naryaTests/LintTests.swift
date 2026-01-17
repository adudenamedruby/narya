// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import narya

@Suite("Lint Tests", .serialized)
struct LintTests {
    // MARK: - Command Configuration Tests

    @Test("Command has correct name")
    func commandName() {
        #expect(Lint.configuration.commandName == "lint")
    }

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Lint.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = Lint.configuration.discussion
        #expect(!discussion.isEmpty)
    }

    @Test("Command has info subcommand")
    func hasInfoSubcommand() {
        let subcommands = Lint.configuration.subcommands
        #expect(subcommands.contains { $0 == LintInfo.self })
    }

    // MARK: - Argument Parsing Tests

    @Test("Can parse --all flag")
    func parseAllFlag() throws {
        let command = try Lint.parse(["--all"])
        #expect(command.all == true)
        #expect(command.changed == false)
    }

    @Test("Can parse --changed flag")
    func parseChangedFlag() throws {
        let command = try Lint.parse(["--changed"])
        #expect(command.changed == true)
        #expect(command.all == false)
    }

    @Test("Can parse --strict flag")
    func parseStrictFlag() throws {
        let command = try Lint.parse(["--strict"])
        #expect(command.strict == true)
    }

    @Test("Can parse --quiet flag short form")
    func parseQuietShort() throws {
        let command = try Lint.parse(["-q"])
        #expect(command.quiet == true)
    }

    @Test("Can parse --quiet flag long form")
    func parseQuietLong() throws {
        let command = try Lint.parse(["--quiet"])
        #expect(command.quiet == true)
    }

    @Test("Can parse --fix flag")
    func parseFixFlag() throws {
        let command = try Lint.parse(["--fix"])
        #expect(command.fix == true)
    }

    @Test("Can parse multiple flags together")
    func parseMultipleFlags() throws {
        let command = try Lint.parse(["--all", "--strict", "-q"])
        #expect(command.all == true)
        #expect(command.strict == true)
        #expect(command.quiet == true)
    }

    // MARK: - LintInfo Subcommand Tests

    @Test("LintInfo has correct name")
    func infoCommandName() {
        #expect(LintInfo.configuration.commandName == "info")
    }

    @Test("LintInfo has non-empty abstract")
    func infoHasAbstract() {
        let abstract = LintInfo.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    // MARK: - LintError Tests

    @Test("LintError.swiftlintNotFound has correct description")
    func swiftlintNotFoundError() {
        let error = LintError.swiftlintNotFound
        #expect(error.description.contains("swiftlint not found"))
    }

    @Test("LintError.lintFailed has correct description")
    func lintFailedError() {
        let error = LintError.lintFailed(exitCode: 1)
        #expect(error.description.contains("failed"))
        #expect(error.description.contains("1"))
    }

    @Test("LintError.noChangedFiles has correct description")
    func noChangedFilesError() {
        let error = LintError.noChangedFiles
        #expect(error.description.contains("No changed"))
    }
}
