// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

enum ToolCheckerError: Error, CustomStringConvertible {
    case toolNotFound(String)

    var description: String {
        switch self {
        case .toolNotFound(let tool):
            return "💥💍 \(tool) is not available. Please install \(tool) and try again."
        }
    }
}

enum ToolChecker {
    static func requireGit() throws {
        try checkTool("git", arguments: ["--version"])
    }

    static func requireNode() throws {
        try checkTool("node", arguments: ["--version"])
    }

    static func requireNpm() throws {
        try checkTool("npm", arguments: ["--version"])
    }

    static func requireXcodebuild() throws {
        try checkTool("xcodebuild", arguments: ["-version"])
    }

    static func requireSimctl() throws {
        // simctl doesn't have a --version flag, so we use 'help' instead
        try checkTool("xcrun", arguments: ["simctl", "help"])
    }

    static func checkTool(_ tool: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [tool] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                throw ToolCheckerError.toolNotFound(tool)
            }
        } catch is ToolCheckerError {
            throw ToolCheckerError.toolNotFound(tool)
        } catch {
            throw ToolCheckerError.toolNotFound(tool)
        }
    }
}
