// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

@Suite("FixPackages Tests", .serialized)
struct FixPackagesTests {
    let fileManager = FileManager.default

    func createTempDirectory() throws -> URL {
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    func cleanup(_ url: URL) {
        try? fileManager.removeItem(at: url)
    }

    @Test("Command has correct name")
    func commandHasCorrectName() {
        #expect(FixPackages.configuration.commandName == "fix-packages")
    }

    @Test("Command has non-empty abstract")
    func commandHasAbstract() {
        let abstract = FixPackages.configuration.abstract
        #expect(!abstract.isEmpty)
        #expect(abstract.contains("Swift packages"))
    }

    @Test("Command has discussion text")
    func commandHasDiscussion() {
        let discussion = FixPackages.configuration.discussion
        #expect(!discussion.isEmpty)
        #expect(discussion.contains("swift package reset"))
        #expect(discussion.contains("swift package resolve"))
    }

    @Test("run throws when not in firefox-ios repo")
    func runThrowsWhenNotInRepo() throws {
        let tempDir = try createTempDirectory()
        defer { cleanup(tempDir) }

        // Save current directory
        let originalDir = fileManager.currentDirectoryPath

        // Change to temp directory without marker file
        fileManager.changeCurrentDirectoryPath(tempDir.path)
        defer { fileManager.changeCurrentDirectoryPath(originalDir) }

        var command = FixPackages()
        #expect(throws: RepoDetectorError.self) {
            try command.run()
        }
    }
}
