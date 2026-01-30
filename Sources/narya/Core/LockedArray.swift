// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

/// A thread-safe array wrapper for use in concurrent contexts.
final class LockedArray<Element>: @unchecked Sendable {
    private var _values: [Element] = []
    private let lock = NSLock()

    var values: [Element] {
        lock.lock()
        defer { lock.unlock() }
        return _values
    }

    func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        _values.append(element)
    }
}
