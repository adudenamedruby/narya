// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
@testable import narya

// MARK: - Temporary Directory Helpers

/// Creates a temporary directory with a unique name.
/// - Returns: URL to the created temporary directory
/// - Throws: If directory creation fails
func createTempDirectory() throws -> URL {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
}

/// Creates a temporary directory initialized as a git repository.
/// - Returns: URL to the created git repository root
/// - Throws: If directory creation or git init fails
func createTempGitRepo() throws -> URL {
    let tempDir = try createTempDirectory()
    try ShellRunner.run("git", arguments: ["init"], workingDirectory: tempDir)
    return tempDir
}

/// Removes a file or directory at the specified URL.
/// Silently ignores errors if the item doesn't exist or can't be removed.
/// - Parameter url: The URL of the item to remove
func cleanup(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

/// Creates a temporary directory, runs the operation, and cleans up afterward.
/// - Parameter operation: Closure that receives the temporary directory URL
/// - Returns: The result of the operation
/// - Throws: Any error from the operation
func withTemporaryDirectory<T>(_ operation: (URL) throws -> T) throws -> T {
    let tempDir = try createTempDirectory()
    defer { cleanup(tempDir) }
    return try operation(tempDir)
}

/// Creates a temporary git repository, runs the operation, and cleans up afterward.
/// - Parameter operation: Closure that receives the git repository root URL
/// - Returns: The result of the operation
/// - Throws: Any error from the operation
func withTemporaryGitRepo<T>(_ operation: (URL) throws -> T) throws -> T {
    let repoDir = try createTempGitRepo()
    defer { cleanup(repoDir) }
    return try operation(repoDir)
}

// MARK: - Working Directory Helpers

/// Runs an operation in a specific directory, then restores the original working directory.
/// - Parameters:
///   - directory: The directory to change to
///   - operation: The operation to run
/// - Returns: The result of the operation
/// - Throws: Any error from the operation
func inDirectory<T>(_ directory: URL, operation: () throws -> T) rethrows -> T {
    let originalDir = FileManager.default.currentDirectoryPath
    FileManager.default.changeCurrentDirectoryPath(directory.path)
    defer { FileManager.default.changeCurrentDirectoryPath(originalDir) }
    return try operation()
}
