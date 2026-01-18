// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension L10n {
    /// Creates template XLIFF files for localization teams to use as a starting point.
    ///
    /// Templates are based on the en-US XLIFF but with target translations and
    /// target-language attributes removed.
    struct Templates: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "templates",
            abstract: "Create template XLIFF files from en-US source.",
            discussion: """
                Creates template XLIFF files in the l10n repository's templates directory.

                Templates are generated from the en-US XLIFF file with:
                - All target-language attributes removed
                - All <target> elements removed
                - Source strings and notes preserved

                This provides translators with a clean starting point.
                """
        )

        @Option(name: .customLong("l10n-project-path"), help: "Path to the l10n repository.")
        var l10nProjectPath: String

        @Option(name: .customLong("xliff-name"), help: "XLIFF filename.")
        var xliffName: String = "firefox-ios.xliff"

        mutating func run() throws {
            Herald.reset()
            Herald.declare("Creating template XLIFF files...")

            try L10nTemplatesTask(l10nRepoPath: l10nProjectPath, xliffName: xliffName).run()

            Herald.declare("Templates created successfully!")
        }
    }
}

/// Internal task that creates template XLIFF files.
struct L10nTemplatesTask {
    let l10nRepoPath: String
    let xliffName: String

    /// Processor used for querying file nodes (mode doesn't matter for templates).
    private let xliffProcessor = L10nXliffProcessor(excludedTranslations: [], mode: .export)

    /// Copies the en-US XLIFF file to the templates directory.
    private func copyEnLocaleToTemplates() throws {
        let source = URL(fileURLWithPath: "\(l10nRepoPath)/en-US/\(xliffName)")
        let destination = URL(fileURLWithPath: "\(l10nRepoPath)/templates/\(xliffName)")
        try L10nFileOperations.copyWithReplace(from: source, to: destination)
    }

    /// Removes target-language attributes and target elements from the template XLIFF.
    private func handleXML() throws {
        let url = URL(fileURLWithPath: "\(l10nRepoPath)/templates/\(xliffName)")

        let xml: XMLDocument
        do {
            xml = try XMLDocument(contentsOf: url, options: .nodePreserveWhitespace)
        } catch {
            throw L10nError.xmlParsingFailed(path: url.path, underlyingError: error)
        }

        guard let root = xml.rootElement() else { return }

        let fileNodes = try xliffProcessor.queryFileNodes(in: root)
        for case let fileNode as XMLElement in fileNodes {
            fileNode.removeAttribute(forName: "target-language")

            // Remove all target elements from translation units
            let translations = try xliffProcessor.queryTranslations(in: fileNode)
            for case let transUnit as XMLElement in translations {
                if let targetNode = try? transUnit.nodes(forXPath: "target").first {
                    targetNode.detach()
                }
            }
        }

        do {
            try xml.xmlString.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw L10nError.fileWriteFailed(path: url.path, underlyingError: error)
        }
    }

    /// Executes the template creation task.
    func run() throws {
        try copyEnLocaleToTemplates()
        try handleXML()
    }
}
