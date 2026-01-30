// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension L10n {
    /// Exports localizable strings from an Xcode project to XLIFF files for translation.
    ///
    /// The export process involves:
    /// 1. Running `xcodebuild -exportLocalizations` to extract strings from the project
    /// 2. Processing the XLIFF XML (locale mapping, filtering excluded keys, applying comment overrides)
    /// 3. Copying the processed XLIFF files to the l10n repository
    struct Export: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export localizable strings from an Xcode project to XLIFF files.",
            discussion: """
                Extracts localizable strings from the specified Xcode project and writes
                them to the l10n repository as XLIFF files.

                You must specify either --product or --project-path:
                - Use --product firefox or --product focus for preset configurations
                - Use --project-path for custom project locations

                The export process:
                1. Runs xcodebuild -exportLocalizations
                2. Filters excluded translation keys (CFBundleName, etc.)
                3. Maps locale codes from Xcode to Pontoon format
                4. Applies comment overrides from l10n_comments.txt
                5. Copies processed files to the l10n repository
                """
        )

        @Option(name: .long, help: "Product preset (firefox or focus). Required unless --project-path is specified.")
        var product: L10nProduct?

        @Option(name: .long, help: "Path to the Xcode project (.xcodeproj). Required unless --product is specified.")
        var projectPath: String?

        @Option(name: .customLong("l10n-project-path"), help: "Path to the l10n repository.")
        var l10nProjectPath: String

        @Option(name: .customLong("locale"), help: "Single locale to export (discovers all if not specified).")
        var localeCode: String?

        @Option(name: .customLong("xliff-name"), help: "XLIFF filename (default from product).")
        var xliffName: String?

        @Option(name: .customLong("export-base-path"), help: "Base path for export temp files (default from product).")
        var exportBasePath: String?

        @Flag(name: .customLong("create-templates"), help: "Create template XLIFF files after export.")
        var createTemplates = false

        mutating func validate() throws {
            if product != nil && projectPath != nil {
                throw ValidationError("Cannot specify both --product and --project-path")
            }
            if product == nil && projectPath == nil {
                throw ValidationError("Must specify either --product or --project-path")
            }
        }

        mutating func run() throws {
            try ToolChecker.requireXcodebuild()

            let repo = try RepoDetector.requireValidRepo()

            // Resolve project path (CLI or product path from repo root)
            let resolvedProjectPath: String
            if let cliPath = projectPath {
                resolvedProjectPath = cliPath
            } else if let prod = product {
                resolvedProjectPath = repo.root.appendingPathComponent(prod.projectPath).path
            } else {
                // Should never reach here due to validate()
                throw ValidationError("Must specify either --product or --project-path")
            }

            // Resolve other values (CLI > product default > hardcoded fallback)
            let resolvedXliffName = xliffName ?? product?.xliffName ?? "firefox-ios.xliff"
            let resolvedExportBasePath = exportBasePath ?? product?.exportBasePath ?? "/tmp/ios-localization"

            let locales: [String]
            if let singleLocale = localeCode {
                locales = [singleLocale]
            } else {
                locales = try L10nExportTask.discoverLocales(at: l10nProjectPath)
            }

            Herald.declare("Exporting \(locales.count) locale(s) from \(resolvedProjectPath)...", isNewCommand: true)

            try L10nExportTask(
                xcodeProjPath: resolvedProjectPath,
                l10nRepoPath: l10nProjectPath,
                locales: locales,
                xliffName: resolvedXliffName,
                exportBasePath: resolvedExportBasePath
            ).run()

            if createTemplates {
                Herald.declare("Creating template XLIFF files...")
                try L10nTemplatesTask(l10nRepoPath: l10nProjectPath, xliffName: resolvedXliffName).run()
            }

            Herald.declare("Export completed successfully!", asConclusion: true)
        }
    }
}

/// Internal task that performs the export operation.
struct L10nExportTask {
    let xcodeProjPath: String
    let l10nRepoPath: String
    let locales: [String]
    let xliffName: String
    let exportBasePath: String

    /// Concurrent queue for parallel processing of multiple locales.
    private let queue = DispatchQueue(label: "l10n.export.backgroundQueue", attributes: .concurrent)
    private let group = DispatchGroup()

    /// Shared XML processor configured for export operations.
    private let xliffProcessor = L10nXliffProcessor(
        excludedTranslations: L10nTranslationKeys.excludedForExport,
        mode: .export
    )

    /// Discovers locale codes from subdirectories in the l10n repository.
    /// - Parameter l10nPath: Path to the l10n repository
    /// - Returns: Sorted array of locale codes, excluding "templates"
    /// - Throws: `L10nError.directoryListingFailed` if directory cannot be read
    static func discoverLocales(at l10nPath: String) throws -> [String] {
        let directoryContent: [URL]
        do {
            directoryContent = try FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: l10nPath),
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
        } catch {
            throw L10nError.directoryListingFailed(path: l10nPath, underlyingError: error)
        }
        return directoryContent
            .filter { $0.hasDirectoryPath }
            .compactMap { $0.pathComponents.last }
            .filter { $0 != "templates" }
            .sorted()
    }

    /// Runs xcodebuild to export localizations for all configured locales.
    private func exportLocales() throws {
        let command = "xcodebuild -exportLocalizations -project \(xcodeProjPath) -localizationPath \(exportBasePath)"
        let exportLanguages = locales.map { "-exportLanguage \($0)" }.joined(separator: " ")

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command + " " + exportLanguages]
        do {
            try task.run()
        } catch {
            throw L10nError.processExecutionFailed(
                command: "xcodebuild -exportLocalizations",
                underlyingError: error
            )
        }
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw L10nError.commandFailed(
                command: "xcodebuild -exportLocalizations",
                exitCode: task.terminationStatus
            )
        }
    }

    /// Applies comment overrides to translations in a file node.
    private func applyCommentOverrides(_ fileNode: XMLElement, overrides: [String: String]) throws {
        let translations = try xliffProcessor.queryTranslations(in: fileNode)

        for case let translation as XMLElement in translations {
            if let comment = translation.attribute(forName: "id")?.stringValue.flatMap({ overrides[$0] }) {
                if let element = try? translation.nodes(forXPath: "note").first {
                    element.setStringValue(comment, resolvingEntities: true)
                }
            }
        }
    }

    /// Processes an exported XLIFF file.
    private func handleXML(
        path: String,
        locale: String,
        commentOverrides: [String: String]
    ) throws {
        let url = URL(fileURLWithPath: path.appending("/\(locale).xcloc/Localized Contents/\(locale).xliff"))

        let xml: XMLDocument
        do {
            xml = try XMLDocument(contentsOf: url, options: [.nodePreserveWhitespace, .nodeCompactEmptyElement])
        } catch {
            throw L10nError.xmlParsingFailed(path: url.path, underlyingError: error)
        }

        guard let root = xml.rootElement() else { return }

        let fileNodes = try xliffProcessor.queryFileNodes(in: root)

        try xliffProcessor.processFileNodes(fileNodes, locale: locale) { fileNode in
            try applyCommentOverrides(fileNode, overrides: commentOverrides)
        }

        do {
            try xml.xmlString.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw L10nError.fileWriteFailed(path: url.path, underlyingError: error)
        }
    }

    /// Copies a processed XLIFF file to the l10n repository.
    private func copyToL10NRepo(locale: String) throws {
        let source = URL(fileURLWithPath: "\(exportBasePath)/\(locale).xcloc/Localized Contents/\(locale).xliff")
        let l10nLocale = L10nLocaleMapping.toPontoon(locale)
        let destination = URL(fileURLWithPath: "\(l10nRepoPath)/\(l10nLocale)/\(xliffName)")
        do {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
        } catch {
            throw L10nError.fileReplaceFailed(path: destination.path, underlyingError: error)
        }
    }

    /// Executes the export task.
    func run() throws {
        try exportLocales()

        let commentOverrideURL = URL(fileURLWithPath: xcodeProjPath)
            .deletingLastPathComponent()
            .appendingPathComponent("l10n_comments.txt")
        let commentOverrides: [String: String] = (try? String(contentsOf: commentOverrideURL))?
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { result, item in
                let items = item.split(separator: "=")
                guard let key = items.first, let value = items.last else { return }
                result[String(key)] = String(value)
            } ?? [:]

        let errors = LockedArray<L10nError>()

        locales.forEach { locale in
            group.enter()
            queue.async {
                defer { group.leave() }
                do {
                    try handleXML(path: exportBasePath, locale: locale, commentOverrides: commentOverrides)
                    try copyToL10NRepo(locale: locale)
                } catch let error as L10nError {
                    errors.append(error)
                } catch {
                    errors.append(.fileWriteFailed(path: locale, underlyingError: error))
                }
            }
        }

        group.wait()

        if !errors.values.isEmpty {
            for error in errors.values {
                Herald.declare(error.description, asError: true)
            }
            throw errors.values.first!
        }
    }
}
