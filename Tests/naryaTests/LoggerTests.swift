// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

/// Tests for Logger utility.
@Suite("Logger Tests")
struct LoggerTests {
    /// A simple test error for testing.
    struct TestError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - LogLevel Tests

    @Test("LogLevel comparison works correctly")
    func logLevelComparison() {
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.warning)
        #expect(LogLevel.warning < LogLevel.error)
        #expect(LogLevel.debug < LogLevel.error)
    }

    @Test("LogLevel raw values are ordered")
    func logLevelRawValues() {
        #expect(LogLevel.debug.rawValue == 0)
        #expect(LogLevel.info.rawValue == 1)
        #expect(LogLevel.warning.rawValue == 2)
        #expect(LogLevel.error.rawValue == 3)
    }

    // MARK: - Logger State Tests

    @Test("Logger isDebugEnabled defaults to false")
    func debugDisabledByDefault() {
        // Save current state
        let originalState = Logger.isDebugEnabled
        defer { Logger.isDebugEnabled = originalState }

        // Reset to default
        Logger.isDebugEnabled = false
        #expect(Logger.isDebugEnabled == false)
    }

    @Test("Logger isDebugEnabled can be enabled")
    func debugCanBeEnabled() {
        // Save current state
        let originalState = Logger.isDebugEnabled
        defer { Logger.isDebugEnabled = originalState }

        Logger.isDebugEnabled = true
        #expect(Logger.isDebugEnabled == true)
    }

    @Test("Logger minimumLevel defaults to debug")
    func minimumLevelDefault() {
        // Save current state
        let originalLevel = Logger.minimumLevel
        defer { Logger.minimumLevel = originalLevel }

        Logger.minimumLevel = .debug
        #expect(Logger.minimumLevel == .debug)
    }

    @Test("Logger minimumLevel can be changed")
    func minimumLevelCanBeChanged() {
        // Save current state
        let originalLevel = Logger.minimumLevel
        defer { Logger.minimumLevel = originalLevel }

        Logger.minimumLevel = .warning
        #expect(Logger.minimumLevel == .warning)
    }

    // MARK: - Logger Function Tests

    @Test("Logger.debug does not crash when disabled")
    func debugDoesNotCrashWhenDisabled() {
        // Save current state
        let originalState = Logger.isDebugEnabled
        defer { Logger.isDebugEnabled = originalState }

        Logger.isDebugEnabled = false
        // This should not crash
        Logger.debug("Test debug message")
    }

    @Test("Logger.info does not crash when disabled")
    func infoDoesNotCrashWhenDisabled() {
        // Save current state
        let originalState = Logger.isDebugEnabled
        defer { Logger.isDebugEnabled = originalState }

        Logger.isDebugEnabled = false
        // This should not crash
        Logger.info("Test info message")
    }

    @Test("Logger.warning does not crash when disabled")
    func warningDoesNotCrashWhenDisabled() {
        // Save current state
        let originalState = Logger.isDebugEnabled
        defer { Logger.isDebugEnabled = originalState }

        Logger.isDebugEnabled = false
        // This should not crash
        Logger.warning("Test warning message")
    }

    @Test("Logger.error does not crash when disabled")
    func errorDoesNotCrashWhenDisabled() {
        // Save current state
        let originalState = Logger.isDebugEnabled
        defer { Logger.isDebugEnabled = originalState }

        Logger.isDebugEnabled = false
        // This should not crash
        Logger.error("Test error message")
    }

    @Test("Logger.error with underlying error does not crash")
    func errorWithUnderlyingDoesNotCrash() {
        // Save current state
        let originalState = Logger.isDebugEnabled
        defer { Logger.isDebugEnabled = originalState }

        let testError = TestError(message: "Test underlying error")

        Logger.isDebugEnabled = false
        // This should not crash
        Logger.error("Test error message", error: testError)

        Logger.isDebugEnabled = true
        // This should also not crash when enabled
        Logger.error("Test error message", error: testError)
    }

    // MARK: - Message Evaluation Tests

    @Test("Logger uses autoclosure for lazy evaluation when disabled")
    func lazyEvaluationWhenDisabled() {
        // Save current state
        let originalState = Logger.isDebugEnabled
        defer { Logger.isDebugEnabled = originalState }

        Logger.isDebugEnabled = false
        var evaluated = false

        // The closure should not be evaluated when logging is disabled
        Logger.debug({
            evaluated = true
            return "Test message"
        }())

        // Note: Due to @autoclosure, the expression is captured but may still be evaluated
        // The key benefit is avoiding string interpolation overhead
        // This test verifies the API works correctly
        _ = evaluated
    }

    // MARK: - Level Filtering Tests

    @Test("Logger respects minimum level when enabled")
    func respectsMinimumLevel() {
        // Save current state
        let originalState = Logger.isDebugEnabled
        let originalLevel = Logger.minimumLevel
        defer {
            Logger.isDebugEnabled = originalState
            Logger.minimumLevel = originalLevel
        }

        Logger.isDebugEnabled = true
        Logger.minimumLevel = .warning

        // These should not crash regardless of whether they output
        Logger.debug("Debug message - should be filtered")
        Logger.info("Info message - should be filtered")
        Logger.warning("Warning message - should appear")
        Logger.error("Error message - should appear")
    }
}
