// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Lint {
    struct Info: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "info",
            abstract: "Show SwiftLint information and rules."
        )

        mutating func run() throws {
            try LintHelpers.requireSwiftlint()

            Herald.declare("SwiftLint Version:", isNewCommand: true)
            try ShellRunner.run("swiftlint", arguments: ["version"])

            Herald.declare("")

            Herald.declare("Available Rules:")
            try ShellRunner.run("swiftlint", arguments: ["rules"])
        }
    }
}
