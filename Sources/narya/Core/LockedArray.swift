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
