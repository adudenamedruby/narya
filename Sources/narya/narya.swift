// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser

@main
struct Narya: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: Configuration.name,
        abstract: Configuration.shortDescription,
        version: Configuration.version,
        subcommands: [
            Bootstrap.self,
            Clean.self,
            Setup.self,
            Telemetry.self,
            Update.self,
        ],
        defaultSubcommand: nil
    )

    @Flag(name: .long, help: "Show version and tool information.")
    var about = false

    mutating func run() throws {
        if about {
            print(Configuration.aboutText)
            return
        }

        // If no flags or subcommands provided, show help
        print(Narya.helpMessage())
    }
}
