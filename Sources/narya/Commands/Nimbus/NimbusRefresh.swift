// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Nimbus {
    struct Refresh: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Refresh the include block in nimbus.fml.yaml with current feature files."
        )

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()

            Herald.declare("Updating nimbus.fml.yaml include block...", isNewCommand: true)
            try NimbusHelpers.updateNimbusFml(repoRoot: repo.root)
            Herald.declare("Successfully updated nimbus.fml.yaml", asConclusion: true)
        }
    }
}
