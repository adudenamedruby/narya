// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

@main
struct Narya: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: Configuration.name,
        abstract: Configuration.shortDescription,
        version: Configuration.version,
        subcommands: [
            Bootstrap.self,
            Build.self,
            Clean.self,
            Lint.self,
            Nimbus.self,
            Run.self,
            Setup.self,
            Telemetry.self,
            Test.self,
            Version.self,
        ],
        defaultSubcommand: nil
    )

    @Flag(name: .long, help: "Show tool information.")
    var about = false

    mutating func run() throws {
        if about {
            print(Configuration.aboutText)
            return
        }

        // If no flags or subcommands provided, show help
        print(Narya.helpMessage())
    }

    /// Custom main to handle errors through Herald
    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch let error as CleanExit {
            // Clean exits (help, version, etc.)
            Self.exit(withError: error)
        } catch let error as ValidationError {
            // ArgumentParser validation errors - let it handle formatting
            Self.exit(withError: error)
        } catch {
            // Report other errors through Herald
            Herald.warn(String(describing: error))
            Self.exit(withError: ExitCode.failure)
        }
    }
}
