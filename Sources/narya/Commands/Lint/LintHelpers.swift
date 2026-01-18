// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

enum LintHelpers {
    static func requireSwiftlint() throws {
        do {
            _ = try ShellRunner.runAndCapture("which", arguments: ["swiftlint"])
        } catch {
            throw LintError.swiftlintNotFound
        }
    }

    static func getChangedSwiftFiles(repoRoot: URL) throws -> [String] {
        let mergeBase = try ShellRunner.runAndCapture(
            "git",
            arguments: ["merge-base", "HEAD", "main"],
            workingDirectory: repoRoot
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let output = try ShellRunner.runAndCapture(
            "git",
            arguments: ["diff", "--name-only", "--diff-filter=ACMR", "\(mergeBase)...HEAD"],
            workingDirectory: repoRoot
        )

        let fileManager = FileManager.default
        let files = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.hasSuffix(".swift") }
            .map { repoRoot.appendingPathComponent($0).path }
            .filter { fileManager.fileExists(atPath: $0) }

        return files
    }
}
