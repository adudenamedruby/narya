// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

/// Handles formatted output for narya commands.
/// The first line of output uses 💍, subsequent lines use ▒
enum Herald {
    // This is a CLI tool that runs single-threaded, so mutable global state is safe
    nonisolated(unsafe) private static var isFirstLine = true

    /// Declares a message with the appropriate prefix (💍 for first line, ▌ for subsequent)
    static func declare(_ message: String) {
        let prefix = isFirstLine ? "💍" : "▒"
        isFirstLine = false
        Swift.print("\(prefix) \(message)")
    }

    /// Warns with a warning/error message using 💥💍 prefix.
    /// Multi-line messages use ▒ for subsequent lines.
    static func warn(_ message: String) {
        let lines = message.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let prefix = index == 0 ? "💥💍" : "▒"
            Swift.print("\(prefix) \(line)")
        }
    }

    /// Resets the output state for a new command execution
    static func reset() {
        isFirstLine = true
    }
}
