// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

/// Tests for L10nError enum and its error descriptions.
@Suite("L10nError Tests")
struct L10nErrorTests {

    /// A simple underlying error for testing.
    struct TestError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Error Description Tests

    @Test("processExecutionFailed includes command and error details")
    func processExecutionFailedMessage() {
        let underlyingError = TestError(message: "Command not found")
        let error = L10nError.processExecutionFailed(
            command: "xcodebuild -importLocalizations",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("xcodebuild -importLocalizations"))
        #expect(description.contains("Command not found"))
        #expect(description.contains("Failed to execute process"))
    }

    @Test("xmlParsingFailed includes path and error details")
    func xmlParsingFailedMessage() {
        let underlyingError = TestError(message: "Invalid XML structure")
        let error = L10nError.xmlParsingFailed(
            path: "/path/to/file.xliff",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("/path/to/file.xliff"))
        #expect(description.contains("Invalid XML structure"))
        #expect(description.contains("Failed to parse XML"))
    }

    @Test("xpathQueryFailed includes xpath and error details")
    func xpathQueryFailedMessage() {
        let underlyingError = TestError(message: "Invalid expression")
        let error = L10nError.xpathQueryFailed(
            xpath: "body/trans-unit",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("body/trans-unit"))
        #expect(description.contains("Invalid expression"))
        #expect(description.contains("Failed to execute XPath"))
    }

    @Test("fileWriteFailed includes path and error details")
    func fileWriteFailedMessage() {
        let underlyingError = TestError(message: "Permission denied")
        let error = L10nError.fileWriteFailed(
            path: "/path/to/output.xliff",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("/path/to/output.xliff"))
        #expect(description.contains("Permission denied"))
        #expect(description.contains("Failed to write file"))
    }

    @Test("fileReadFailed includes path and error details")
    func fileReadFailedMessage() {
        let underlyingError = TestError(message: "File not found")
        let error = L10nError.fileReadFailed(
            path: "/path/to/missing.xliff",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("/path/to/missing.xliff"))
        #expect(description.contains("File not found"))
        #expect(description.contains("Failed to read file"))
    }

    @Test("fileCopyFailed includes source, destination, and error details")
    func fileCopyFailedMessage() {
        let underlyingError = TestError(message: "Disk full")
        let error = L10nError.fileCopyFailed(
            source: "/source/file.xliff",
            destination: "/dest/file.xliff",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("/source/file.xliff"))
        #expect(description.contains("/dest/file.xliff"))
        #expect(description.contains("Disk full"))
        #expect(description.contains("Failed to copy file"))
    }

    @Test("fileDeleteFailed includes path and error details")
    func fileDeleteFailedMessage() {
        let underlyingError = TestError(message: "File in use")
        let error = L10nError.fileDeleteFailed(
            path: "/path/to/locked.xliff",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("/path/to/locked.xliff"))
        #expect(description.contains("File in use"))
        #expect(description.contains("Failed to delete file"))
    }

    @Test("directoryCreationFailed includes path and error details")
    func directoryCreationFailedMessage() {
        let underlyingError = TestError(message: "Permission denied")
        let error = L10nError.directoryCreationFailed(
            path: "/path/to/new/directory",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("/path/to/new/directory"))
        #expect(description.contains("Permission denied"))
        #expect(description.contains("Failed to create directory"))
    }

    @Test("fileReplaceFailed includes path and error details")
    func fileReplaceFailedMessage() {
        let underlyingError = TestError(message: "Target does not exist")
        let error = L10nError.fileReplaceFailed(
            path: "/path/to/target.xliff",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("/path/to/target.xliff"))
        #expect(description.contains("Target does not exist"))
        #expect(description.contains("Failed to replace file"))
    }

    @Test("invalidXliffStructure includes path and details")
    func invalidXliffStructureMessage() {
        let error = L10nError.invalidXliffStructure(
            path: "/path/to/malformed.xliff",
            details: "Missing root element"
        )

        let description = error.description
        #expect(description.contains("/path/to/malformed.xliff"))
        #expect(description.contains("Missing root element"))
        #expect(description.contains("Invalid XLIFF structure"))
    }

    @Test("directoryListingFailed includes path and error details")
    func directoryListingFailedMessage() {
        let underlyingError = TestError(message: "Not a directory")
        let error = L10nError.directoryListingFailed(
            path: "/path/to/not-a-dir",
            underlyingError: underlyingError
        )

        let description = error.description
        #expect(description.contains("/path/to/not-a-dir"))
        #expect(description.contains("Not a directory"))
        #expect(description.contains("Failed to list directory"))
    }

    // MARK: - Error Protocol Conformance Tests

    @Test("L10nError conforms to Error protocol")
    func errorConformance() {
        let error: Error = L10nError.invalidXliffStructure(
            path: "/test",
            details: "test"
        )
        #expect(error is L10nError)
    }

    @Test("L10nError conforms to CustomStringConvertible")
    func customStringConvertibleConformance() {
        let error: CustomStringConvertible = L10nError.invalidXliffStructure(
            path: "/test",
            details: "test"
        )
        #expect(!error.description.isEmpty)
    }
}
