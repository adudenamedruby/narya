// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

// Narya - CLI tool for firefox-ios development
//
// Commands validate they're run within a valid firefox-ios repo via RepoDetector,
// which looks for .narya.yaml at the repository root.

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
            Doctor.self,
            L10n.self,
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
            do {
                try command.run()
            } catch {
                // Check if this is an ArgumentParser internal error (help, version, etc.)
                let errorDescription = String(describing: error)
                if errorDescription.contains("ArgumentParser") || error is CleanExit {
                    Self.exit(withError: error)
                }

                // Runtime errors go through Herald
                Herald.warn(String(describing: error))
                Self.exit(withError: ExitCode.failure)
            }
        } catch {
            // Parsing errors go to ArgumentParser
            Self.exit(withError: error)
        }
    }
}
