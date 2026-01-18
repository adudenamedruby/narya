// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

/// Creates a temporary directory, runs the operation, and cleans up afterward.
/// - Parameter operation: Closure that receives the temporary directory URL
/// - Returns: The result of the operation
/// - Throws: Any error from the operation
func withL10nTemporaryDirectory<T>(_ operation: (URL) throws -> T) throws -> T {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("L10nTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }
    return try operation(tempDir)
}

/// Creates a test XLIFF XML document with the specified configuration.
/// - Parameters:
///   - sourceLanguage: Source language code (default: "en")
///   - targetLanguage: Target language code (default: "fr")
///   - filePath: The original file path attribute (default: "Client/en.lproj/Strings.strings")
///   - translations: Array of translation tuples (id, source, target?, note?)
/// - Returns: An XMLDocument representing the XLIFF
func createL10nTestXliff(
    sourceLanguage: String = "en",
    targetLanguage: String = "fr",
    filePath: String = "Client/en.lproj/Strings.strings",
    translations: [(id: String, source: String, target: String?, note: String?)]
) -> XMLDocument {
    let xliffNS = "urn:oasis:names:tc:xliff:document:1.2"

    let root = XMLElement(name: "xliff")
    root.addNamespace(XMLNode.namespace(withName: "", stringValue: xliffNS) as! XMLNode)
    root.addAttribute(XMLNode.attribute(withName: "version", stringValue: "1.2") as! XMLNode)

    let fileElement = XMLElement(name: "file")
    fileElement.addAttribute(XMLNode.attribute(withName: "original", stringValue: filePath) as! XMLNode)
    fileElement.addAttribute(XMLNode.attribute(withName: "source-language", stringValue: sourceLanguage) as! XMLNode)
    fileElement.addAttribute(XMLNode.attribute(withName: "target-language", stringValue: targetLanguage) as! XMLNode)

    let body = XMLElement(name: "body")

    for translation in translations {
        let transUnit = XMLElement(name: "trans-unit")
        transUnit.addAttribute(XMLNode.attribute(withName: "id", stringValue: translation.id) as! XMLNode)

        let sourceElement = XMLElement(name: "source", stringValue: translation.source)
        transUnit.addChild(sourceElement)

        if let target = translation.target {
            let targetElement = XMLElement(name: "target", stringValue: target)
            transUnit.addChild(targetElement)
        }

        if let note = translation.note {
            let noteElement = XMLElement(name: "note", stringValue: note)
            transUnit.addChild(noteElement)
        }

        body.addChild(transUnit)
    }

    fileElement.addChild(body)
    root.addChild(fileElement)

    let doc = XMLDocument(rootElement: root)
    doc.characterEncoding = "UTF-8"
    return doc
}

/// Creates an XLIFF document with multiple file nodes.
/// - Parameters:
///   - sourceLanguage: Source language code
///   - targetLanguage: Target language code
///   - files: Array of (filePath, translations) tuples
/// - Returns: An XMLDocument representing the XLIFF
func createL10nMultiFileXliff(
    sourceLanguage: String = "en",
    targetLanguage: String = "fr",
    files: [(path: String, translations: [(id: String, source: String, target: String?, note: String?)])]
) -> XMLDocument {
    let xliffNS = "urn:oasis:names:tc:xliff:document:1.2"

    let root = XMLElement(name: "xliff")
    root.addNamespace(XMLNode.namespace(withName: "", stringValue: xliffNS) as! XMLNode)
    root.addAttribute(XMLNode.attribute(withName: "version", stringValue: "1.2") as! XMLNode)

    for file in files {
        let fileElement = XMLElement(name: "file")
        fileElement.addAttribute(XMLNode.attribute(withName: "original", stringValue: file.path) as! XMLNode)
        fileElement.addAttribute(XMLNode.attribute(withName: "source-language", stringValue: sourceLanguage) as! XMLNode)
        fileElement.addAttribute(XMLNode.attribute(withName: "target-language", stringValue: targetLanguage) as! XMLNode)

        let body = XMLElement(name: "body")

        for translation in file.translations {
            let transUnit = XMLElement(name: "trans-unit")
            transUnit.addAttribute(XMLNode.attribute(withName: "id", stringValue: translation.id) as! XMLNode)

            let sourceElement = XMLElement(name: "source", stringValue: translation.source)
            transUnit.addChild(sourceElement)

            if let target = translation.target {
                let targetElement = XMLElement(name: "target", stringValue: target)
                transUnit.addChild(targetElement)
            }

            if let note = translation.note {
                let noteElement = XMLElement(name: "note", stringValue: note)
                transUnit.addChild(noteElement)
            }

            body.addChild(transUnit)
        }

        fileElement.addChild(body)
        root.addChild(fileElement)
    }

    let doc = XMLDocument(rootElement: root)
    doc.characterEncoding = "UTF-8"
    return doc
}

/// Returns the URL to a test fixture file for L10n tests.
/// - Parameter name: The filename (with extension) of the fixture
/// - Returns: URL to the fixture file, or nil if not found
func l10nFixtureURL(_ name: String) -> URL? {
    // Look relative to the source file location
    let testDir = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent()
    let fixtureURL = testDir.appendingPathComponent("Fixtures").appendingPathComponent("L10n").appendingPathComponent(name)
    if FileManager.default.fileExists(atPath: fixtureURL.path) {
        return fixtureURL
    }
    return nil
}

/// Loads a fixture XLIFF file and returns it as an XMLDocument.
/// - Parameter name: The filename of the XLIFF fixture
/// - Returns: The parsed XMLDocument
/// - Throws: If the file cannot be found, read, or parsed
func loadL10nFixtureXliff(_ name: String) throws -> XMLDocument {
    guard let url = l10nFixtureURL(name) else {
        throw L10nFixtureError.notFound(name)
    }
    return try XMLDocument(contentsOf: url, options: .nodePreserveWhitespace)
}

/// Errors that can occur when loading test fixtures.
enum L10nFixtureError: Error, CustomStringConvertible {
    case notFound(String)

    var description: String {
        switch self {
        case .notFound(let name):
            return "Fixture '\(name)' not found"
        }
    }
}

// MARK: - XPath Helpers for Tests

extension XMLDocument {
    /// Convenience method to query nodes using XPath.
    /// - Parameter xpath: The XPath expression
    /// - Returns: Array of matching nodes
    func l10nQueryNodes(_ xpath: String) throws -> [XMLNode] {
        guard let root = rootElement() else { return [] }
        return try root.nodes(forXPath: xpath)
    }

    /// Counts the number of nodes matching an XPath expression.
    /// - Parameter xpath: The XPath expression
    /// - Returns: Count of matching nodes
    func l10nCountNodes(_ xpath: String) throws -> Int {
        return try l10nQueryNodes(xpath).count
    }
}

extension XMLElement {
    /// Gets the string value of an attribute.
    /// - Parameter name: The attribute name
    /// - Returns: The attribute value, or nil if not present
    func l10nAttributeValue(_ name: String) -> String? {
        return attribute(forName: name)?.stringValue
    }
}
