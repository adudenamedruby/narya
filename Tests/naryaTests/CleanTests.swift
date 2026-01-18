// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation
import Testing
@testable import narya

@Suite("Clean Tests", .serialized)
struct CleanTests {
    @Test("Command has correct name")
    func commandHasCorrectName() {
        #expect(Clean.configuration.commandName == "clean")
    }

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = Clean.configuration.abstract
        #expect(!abstract.isEmpty)
    }

    @Test("run with --packages throws when not in firefox-ios repo")
    func runThrowsWhenNotInRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        // Save current directory
        let originalDir = FileManager.default.currentDirectoryPath

        // Change to temp directory without marker file
        FileManager.default.changeCurrentDirectoryPath(tempDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }

        var command = try Clean.parse(["--packages"])
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }
}
