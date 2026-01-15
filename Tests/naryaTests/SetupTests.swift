// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Testing
@testable import narya

@Suite("ToolChecker Tests")
struct ToolCheckerTests {
    @Test("ToolCheckerError.toolNotFound has correct description")
    func toolNotFoundDescription() {
        let error = ToolCheckerError.toolNotFound("git")
        #expect(error.description.contains("git"))
        #expect(error.description.contains("not available"))
    }

    @Test("requireGit succeeds when git is available")
    func requireGitSucceeds() throws {
        // git should be available on any dev machine
        try ToolChecker.requireGit()
    }

    @Test("requireTool throws for nonexistent tool")
    func requireToolThrowsForNonexistent() {
        #expect(throws: ToolCheckerError.self) {
            try ToolChecker.requireTool("nonexistent-tool-xyz-12345")
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
