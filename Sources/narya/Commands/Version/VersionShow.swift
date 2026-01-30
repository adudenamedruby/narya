// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension Version {
    struct Show: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Display the current version number."
        )

        mutating func run() throws {
            let repo = try RepoDetector.requireValidRepo()
            let version = try Version.readVersion(repoRoot: repo.root)
            let gitSha = getGitSha(repoRoot: repo.root)

            if let sha = gitSha {
                Herald.declare("\(version) (\(sha))", isNewCommand: true)
            } else {
                Herald.declare(version, isNewCommand: true)
            }
        }

        private func getGitSha(repoRoot: URL) -> String? {
            do {
                let output = try ShellRunner.runAndCapture(
                    "git",
                    arguments: ["rev-parse", "--short", "HEAD"],
                    workingDirectory: repoRoot
                )
                let sha = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return sha.isEmpty ? nil : sha
            } catch {
                return nil
            }
        }
    }
}
