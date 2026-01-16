// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Testing
@testable import narya

@Suite("Update Tests")
struct UpdateTests {
    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Update.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("Command has Version as subcommand")
    func hasVersionSubcommand() {
        let subcommands = Update.configuration.subcommands
        #expect(subcommands.contains { $0 == Version.self })
    }

    @Test("Version subcommand count is correct")
    func subcommandCount() {
        let subcommands = Update.configuration.subcommands
        #expect(subcommands.count == 1)
    }
}
