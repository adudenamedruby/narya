// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

/// Shared utility for processing XLIFF XML files.
///
/// Provides common XML transformation operations used by both import and export tasks:
/// - Filtering excluded translations
/// - Updating locale mappings
/// - Removing empty file nodes
///
/// Each task configures the processor with its specific excluded translations
/// and operation mode (import vs export) for locale mapping direction.
struct L10nXliffProcessor {
    /// The operation mode determines locale mapping direction.
    enum Mode {
        case `import`  // Pontoon → Xcode (e.g., ga-IE → ga)
        case export    // Xcode → Pontoon (e.g., ga → ga-IE)
    }

    /// Translation keys that should be removed from the XLIFF.
    let excludedTranslations: Set<String>

    /// The operation mode for locale mapping direction.
    let mode: Mode

    /// Returns the mapped locale code based on the operation mode.
    private func mappedLocale(for locale: String) -> String? {
        switch mode {
        case .import:
            let mapped = L10nLocaleMapping.toXcode(locale)
            return mapped != locale ? mapped : nil
        case .export:
            let mapped = L10nLocaleMapping.toPontoon(locale)
            return mapped != locale ? mapped : nil
        }
    }

    // MARK: - File Node Helpers

    /// Checks if a file node represents an ActionExtension InfoPlist file.
    /// CFBundleDisplayName is allowed in ActionExtension files as an exception.
    /// - Parameter fileNode: The XML file element to check
    /// - Returns: `true` if this is an ActionExtension InfoPlist file
    func isActionExtensionFile(_ fileNode: XMLElement) -> Bool {
        let fileOriginal = fileNode.attribute(forName: "original")?.stringValue ?? ""
        return fileOriginal.contains("Extensions/ActionExtension") &&
               fileOriginal.contains("InfoPlist.strings")
    }

    /// Updates the target-language attribute of a file node if locale mapping exists.
    /// - Parameters:
    ///   - fileNode: The XML file element to update
    ///   - locale: The current locale code
    func updateTargetLanguage(_ fileNode: XMLElement, locale: String) {
        if let mapped = mappedLocale(for: locale) {
            fileNode.attribute(forName: "target-language")?.setStringValue(mapped, resolvingEntities: false)
        }
    }

    // MARK: - Translation Filtering

    /// Determines if a translation should be excluded.
    /// CFBundleDisplayName is allowed in ActionExtension files as an exception.
    /// - Parameters:
    ///   - translationId: The ID of the translation unit
    ///   - isActionExtension: Whether this translation is in an ActionExtension file
    /// - Returns: `true` if the translation should be excluded
    func shouldExcludeTranslation(id translationId: String?, isActionExtension: Bool) -> Bool {
        if let id = translationId, id == "CFBundleDisplayName" && isActionExtension {
            return false
        }
        return translationId.map(excludedTranslations.contains) == true
    }

    /// Filters out excluded translations from a file node.
    /// - Parameters:
    ///   - fileNode: The XML file element containing translations
    ///   - isActionExtension: Whether this is an ActionExtension file
    /// - Throws: `L10nError.xpathQueryFailed` if XPath query fails
    func filterExcludedTranslations(_ fileNode: XMLElement, isActionExtension: Bool) throws {
        let translations = try queryTranslations(in: fileNode)

        for case let translation as XMLElement in translations {
            let translationId = translation.attribute(forName: "id")?.stringValue
            if shouldExcludeTranslation(id: translationId, isActionExtension: isActionExtension) {
                translation.detach()
            }
        }
    }

    /// Removes a file node if it has no remaining translation units.
    /// - Parameter fileNode: The XML file element to check and potentially remove
    /// - Throws: `L10nError.xpathQueryFailed` if XPath query fails
    func removeIfEmpty(_ fileNode: XMLElement) throws {
        let translations = try queryTranslations(in: fileNode)
        if translations.isEmpty {
            fileNode.detach()
        }
    }

    // MARK: - XPath Helpers

    /// Queries all translation units (trans-unit elements) in a file node.
    /// - Parameter fileNode: The XML file element to query
    /// - Returns: Array of translation unit nodes
    /// - Throws: `L10nError.xpathQueryFailed` if XPath query fails
    func queryTranslations(in fileNode: XMLElement) throws -> [XMLNode] {
        do {
            return try fileNode.nodes(forXPath: "body/trans-unit")
        } catch {
            throw L10nError.xpathQueryFailed(xpath: "body/trans-unit", underlyingError: error)
        }
    }

    /// Queries all file nodes in an XLIFF document root.
    /// - Parameter root: The XML root element
    /// - Returns: Array of file nodes
    /// - Throws: `L10nError.xpathQueryFailed` if XPath query fails
    func queryFileNodes(in root: XMLElement) throws -> [XMLNode] {
        do {
            return try root.nodes(forXPath: "file")
        } catch {
            throw L10nError.xpathQueryFailed(xpath: "file", underlyingError: error)
        }
    }

    // MARK: - Common Processing

    /// Processes all file nodes with standard filtering operations.
    /// - Parameters:
    ///   - fileNodes: Array of file nodes to process
    ///   - locale: The locale code for target-language updates
    ///   - additionalProcessing: Optional closure for task-specific processing per file node
    /// - Throws: `L10nError` if any processing step fails
    func processFileNodes(
        _ fileNodes: [XMLNode],
        locale: String,
        additionalProcessing: ((XMLElement) throws -> Void)? = nil
    ) throws {
        for case let fileNode as XMLElement in fileNodes {
            updateTargetLanguage(fileNode, locale: locale)
            let isActionExtension = isActionExtensionFile(fileNode)
            try filterExcludedTranslations(fileNode, isActionExtension: isActionExtension)
            try additionalProcessing?(fileNode)
            try removeIfEmpty(fileNode)
        }
    }

    // MARK: - High-Level Processing

    /// Processes an XLIFF file with the standard workflow: parse, transform, write.
    ///
    /// This method encapsulates the common pattern used by all tasks:
    /// 1. Parse the XML document
    /// 2. Get root element
    /// 3. Query and process file nodes
    /// 4. Write the transformed XML back to disk
    ///
    /// - Parameters:
    ///   - url: Path to the XLIFF file to process
    ///   - locale: The locale code for target-language updates
    ///   - encoding: Character encoding for writing (default: .utf8)
    ///   - xmlOptions: Options for parsing and writing XML
    ///   - additionalProcessing: Optional closure for task-specific processing per file node
    /// - Throws: `L10nError` if any step fails
    func processXliff(
        at url: URL,
        locale: String,
        encoding: String.Encoding = .utf8,
        xmlOptions: XMLNode.Options = .nodePreserveWhitespace,
        additionalProcessing: ((XMLElement) throws -> Void)? = nil
    ) throws {
        let xml: XMLDocument
        do {
            xml = try XMLDocument(contentsOf: url, options: xmlOptions)
        } catch {
            throw L10nError.xmlParsingFailed(path: url.path, underlyingError: error)
        }

        guard let root = xml.rootElement() else { return }

        let fileNodes = try queryFileNodes(in: root)
        try processFileNodes(fileNodes, locale: locale, additionalProcessing: additionalProcessing)

        do {
            try xml.xmlString.write(to: url, atomically: true, encoding: encoding)
        } catch {
            throw L10nError.fileWriteFailed(path: url.path, underlyingError: error)
        }
    }
}
