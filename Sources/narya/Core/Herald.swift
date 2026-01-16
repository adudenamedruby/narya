// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

/// Handles formatted output for narya commands.
/// The first line of output uses 💍, subsequent lines use ▌
enum Herald {
    // This is a CLI tool that runs single-threaded, so mutable global state is safe
    nonisolated(unsafe) private static var isFirstLine = true

    /// Declares a message with the appropriate prefix (💍 for first line, ▌ for subsequent)
    static func declare(_ message: String) {
        let prefix = isFirstLine ? "💍" : "▌"
        isFirstLine = false
        Swift.print("\(prefix) \(message)")
    }

    /// Warns with an error/warning message using 💥💍 prefix
    static func warn(_ message: String) {
        Swift.print("💥💍 \(message)")
    }

    /// Resets the output state for a new command execution
    static func reset() {
        isFirstLine = true
    }
}
