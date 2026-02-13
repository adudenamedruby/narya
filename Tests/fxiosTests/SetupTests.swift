// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import fxios

@Suite("Setup Tests")
struct SetupTests {
    @Test("SetupError.failedToChangeDirectory has correct description")
    func failedToChangeDirectoryDescription() {
        let error = SetupError.failedToChangeDirectory("/some/path")
        #expect(error.description.contains("/some/path"))
        #expect(error.description.contains("Failed to change directory"))
    }

    @Test("SetupError.failedToAddUpstreamRemote has correct description")
    func failedToAddUpstreamRemoteDescription() {
        let error = SetupError.failedToAddUpstreamRemote
        #expect(error.description.contains("upstream"))
        #expect(error.description.contains("Failed to add"))
    }
}

@Suite("ToolChecker Tests")
struct ToolCheckerTests {
    @Test("ToolCheckerError.toolNotFound has correct description")
    func toolNotFoundDescription() {
        let error = ToolCheckerError.toolNotFound(tool: "git", underlyingError: nil)
        #expect(error.description.contains("git"))
        #expect(error.description.contains("not available"))
    }

    @Test("ToolCheckerError includes underlying error in description")
    func toolNotFoundWithUnderlyingError() {
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "Test underlying error" }
        }
        let underlying = TestError()
        let error = ToolCheckerError.toolNotFound(tool: "node", underlyingError: underlying)
        #expect(error.description.contains("node"))
        #expect(error.description.contains("Test underlying error"))
    }

    @Test("requireGit succeeds when git is available")
    func requireGitSucceeds() throws {
        // git should be available on any dev machine
        try ToolChecker.requireGit()
    }

    @Test("checkTool throws for nonexistent tool")
    func checkToolThrowsForNonexistent() {
        #expect(throws: ToolCheckerError.self) {
            try ToolChecker.checkTool("nonexistent-tool-xyz-12345", arguments: ["--version"])
        }
    }
}

@Suite("ShellRunner Tests")
struct ShellRunnerTests {
    @Test("ShellRunnerError.commandFailed has correct description")
    func commandFailedDescription() {
        let error = ShellRunnerError.commandFailed(command: "git", exitCode: 128)
        #expect(error.description.contains("git"))
        #expect(error.description.contains("128"))
        #expect(error.description.contains("failed"))
    }

    @Test("ShellRunnerError.executionFailed has correct description")
    func executionFailedDescription() {
        let error = ShellRunnerError.executionFailed(command: "git", reason: "not found")
        #expect(error.description.contains("git"))
        #expect(error.description.contains("not found"))
    }

    @Test("run succeeds for valid command")
    func runSucceeds() throws {
        try ShellRunner.run("echo", arguments: ["hello"])
    }

    @Test("run throws for failing command")
    func runThrowsForFailure() {
        #expect(throws: ShellRunnerError.self) {
            try ShellRunner.run("false")
        }
    }

    @Test("runAndCapture returns output")
    func runAndCaptureReturnsOutput() throws {
        let output = try ShellRunner.runAndCapture("echo", arguments: ["hello"])
        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }
}
