// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

/// Shared file operation utilities used across localization tasks.
///
/// Provides common file operations with proper error handling and
/// temporary file management.
enum L10nFileOperations {
    /// Copies a file to a destination, replacing any existing file.
    ///
    /// Uses a two-step process for safe replacement:
    /// 1. Copy source to a temporary file
    /// 2. Atomically replace destination with the temporary file
    ///
    /// This approach ensures the destination is either fully replaced or
    /// left unchanged if an error occurs.
    ///
    /// - Parameters:
    ///   - source: URL of the source file to copy
    ///   - destination: URL where the file should be placed
    /// - Returns: URL of the resulting file (may differ from destination due to replacement)
    /// - Throws: `L10nError.fileCopyFailed` or `L10nError.fileReplaceFailed`
    @discardableResult
    static func copyWithReplace(from source: URL, to destination: URL) throws -> URL {
        let tempFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("l10n-temp-\(UUID().uuidString)")
            .appendingPathExtension(source.pathExtension)

        // Clean up any existing temp file (shouldn't exist with UUID, but be safe)
        try? FileManager.default.removeItem(at: tempFile)

        do {
            try FileManager.default.copyItem(at: source, to: tempFile)
        } catch {
            throw L10nError.fileCopyFailed(
                source: source.path,
                destination: tempFile.path,
                underlyingError: error
            )
        }

        do {
            guard let result = try FileManager.default.replaceItemAt(destination, withItemAt: tempFile) else {
                throw L10nError.fileReplaceFailed(
                    path: destination.path,
                    underlyingError: NSError(
                        domain: "narya.l10n",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "replaceItemAt returned nil"]
                    )
                )
            }
            return result
        } catch let error as L10nError {
            throw error
        } catch {
            throw L10nError.fileReplaceFailed(path: destination.path, underlyingError: error)
        }
    }

    /// Removes a file if it exists, ignoring errors if it doesn't.
    ///
    /// - Parameter url: URL of the file to remove
    /// - Throws: `L10nError.fileDeleteFailed` if file exists but cannot be deleted
    static func removeIfExists(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw L10nError.fileDeleteFailed(path: url.path, underlyingError: error)
        }
    }

    /// Creates a directory and any intermediate directories if they don't exist.
    ///
    /// - Parameter url: URL of the directory to create
    /// - Throws: `L10nError.directoryCreationFailed` if creation fails
    static func createDirectoryIfNeeded(at url: URL) throws {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            throw L10nError.directoryCreationFailed(path: url.path, underlyingError: error)
        }
    }
}
