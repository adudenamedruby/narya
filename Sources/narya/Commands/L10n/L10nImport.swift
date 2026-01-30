// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

extension L10n {
    /// Imports translated XLIFF files from the l10n repository into an Xcode project.
    ///
    /// The import process involves:
    /// 1. Creating .xcloc bundles (Apple's localization catalog format) from XLIFF files
    /// 2. Validating and transforming the XML (locale mapping, filtering, required translations)
    /// 3. Running `xcodebuild -importLocalizations` to apply translations to the project
    struct Import: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "import",
            abstract: "Import translated XLIFF files into an Xcode project.",
            discussion: """
                Imports translated XLIFF files from the l10n repository into
                the specified Xcode project.

                You must specify either --product or --project-path:
                - Use --product firefox or --product focus for preset configurations
                - Use --project-path for custom project locations

                The import process:
                1. Creates .xcloc bundles from XLIFF files
                2. Maps locale codes from Pontoon to Xcode format
                3. Filters excluded translation keys
                4. Adds fallback targets for required translations
                5. Runs xcodebuild -importLocalizations
                """
        )

        @Option(name: .long, help: "Product preset (firefox or focus). Required unless --project-path is specified.")
        var product: L10nProduct?

        @Option(name: .long, help: "Path to the Xcode project (.xcodeproj). Required unless --product is specified.")
        var projectPath: String?

        @Option(name: .customLong("l10n-project-path"), help: "Path to the l10n repository.")
        var l10nProjectPath: String

        @Option(name: .customLong("locale"), help: "Single locale to import (discovers all if not specified).")
        var localeCode: String?

        @Option(name: .customLong("xliff-name"), help: "XLIFF filename (default from product).")
        var xliffName: String?

        @Option(name: .customLong("development-region"), help: "Development region for xcloc manifest (default from product).")
        var developmentRegion: String?

        @Option(name: .customLong("project-name"), help: "Project name for xcloc manifest (default from product).")
        var projectName: String?

        @Flag(name: .customLong("skip-widget-kit"), inversion: .prefixedNo, help: "Exclude WidgetKit strings from required translations (default from product).")
        var skipWidgetKit: Bool?

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
            let resolvedDevelopmentRegion = developmentRegion ?? product?.developmentRegion ?? "en-US"
            let resolvedProjectName = projectName ?? product?.projectName ?? "Client.xcodeproj"
            let resolvedSkipWidgetKit = skipWidgetKit ?? product?.skipWidgetKit ?? false

            let locales: [String]
            if let singleLocale = localeCode {
                locales = [singleLocale]
            } else {
                locales = try L10nExportTask.discoverLocales(at: l10nProjectPath)
            }

            Herald.declare("Importing \(locales.count) locale(s) into \(resolvedProjectPath)...", isNewCommand: true)

            try L10nImportTask(
                xcodeProjPath: resolvedProjectPath,
                l10nRepoPath: l10nProjectPath,
                locales: locales,
                xliffName: resolvedXliffName,
                developmentRegion: resolvedDevelopmentRegion,
                projectName: resolvedProjectName,
                skipWidgetKit: resolvedSkipWidgetKit
            ).run()

            Herald.declare("Import completed successfully!", asConclusion: true)
        }
    }
}

/// Internal task that performs the import operation.
struct L10nImportTask {
    let xcodeProjPath: String
    let l10nRepoPath: String
    let locales: [String]
    let xliffName: String
    let developmentRegion: String
    let projectName: String
    let skipWidgetKit: Bool

    private let temporaryDir = FileManager.default.temporaryDirectory.appendingPathComponent("narya_l10n_import")

    /// Shared XML processor configured for import operations.
    private let xliffProcessor = L10nXliffProcessor(
        excludedTranslations: L10nTranslationKeys.excludedForImport,
        mode: .import
    )

    /// Computed property that returns all required translations based on configuration.
    private var requiredTranslations: Set<String> {
        L10nTranslationKeys.required(includeWidgetKit: !skipWidgetKit)
    }

    /// Generates the contents.json manifest required inside an .xcloc bundle.
    private func generateManifest(targetLocale: String, developmentRegion: String, projectName: String) -> String {
        return """
            {
              "developmentRegion" : "\(developmentRegion)",
              "project" : "\(projectName)",
              "targetLocale" : "\(targetLocale)",
              "toolInfo" : {
                "toolBuildNumber" : "13A233",
                "toolID" : "com.apple.dt.xcode",
                "toolName" : "Xcode",
                "toolVersion" : "13.0"
              },
              "version" : "1.0"
            }
        """
    }

    /// Adds fallback target elements for required translations that are missing targets.
    private func addFallbackTargets(_ fileNode: XMLElement) throws {
        let translations = try xliffProcessor.queryTranslations(in: fileNode)

        for case let translation as XMLElement in translations {
            let translationId = translation.attribute(forName: "id")?.stringValue
            if translationId.map(requiredTranslations.contains) == true {
                let nodes = (try? translation.nodes(forXPath: "target")) ?? []
                let source = ((try? translation.nodes(forXPath: "source").first)?.stringValue) ?? ""
                if nodes.isEmpty {
                    guard let element = XMLNode.element(
                        withName: "target",
                        stringValue: source
                    ) as? XMLNode else { continue }
                    translation.insertChild(element, at: 1)
                }
            }
        }
    }

    /// Creates the .xcloc directory structure.
    private func setupXclocDirectories(localizedContents: URL, sourceContents: URL) throws {
        try L10nFileOperations.createDirectoryIfNeeded(at: localizedContents)
        try L10nFileOperations.createDirectoryIfNeeded(at: sourceContents)
    }

    /// Writes the xcloc manifest file.
    private func writeManifest(to url: URL, locale: String) throws {
        let manifest = generateManifest(targetLocale: locale, developmentRegion: developmentRegion, projectName: projectName)
        do {
            try manifest.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw L10nError.fileWriteFailed(path: url.path, underlyingError: error)
        }
    }

    /// Creates an .xcloc bundle from an XLIFF file in the l10n repository.
    func createXcloc(locale: String) throws -> URL {
        let source = URL(fileURLWithPath: "\(l10nRepoPath)/\(locale)/\(xliffName)")
        let mappedLocale = L10nLocaleMapping.toXcode(locale)
        let xliffDestination = temporaryDir.appendingPathComponent("\(mappedLocale).xcloc/Localized Contents/\(mappedLocale).xliff")
        let sourceContentsDir = temporaryDir.appendingPathComponent("\(mappedLocale).xcloc/Source Contents")
        let manifestDestination = temporaryDir.appendingPathComponent("\(mappedLocale).xcloc/contents.json")

        try setupXclocDirectories(
            localizedContents: xliffDestination.deletingLastPathComponent(),
            sourceContents: sourceContentsDir
        )
        try writeManifest(to: manifestDestination, locale: mappedLocale)

        return try L10nFileOperations.copyWithReplace(from: source, to: xliffDestination)
    }

    /// Validates and transforms the XLIFF XML before import.
    func validateXml(fileUrl: URL, locale: String) throws {
        let xml: XMLDocument
        do {
            xml = try XMLDocument(contentsOf: fileUrl, options: .nodePreserveWhitespace)
        } catch {
            throw L10nError.xmlParsingFailed(path: fileUrl.path, underlyingError: error)
        }

        guard let root = xml.rootElement() else { return }

        let fileNodes = try xliffProcessor.queryFileNodes(in: root)

        try xliffProcessor.processFileNodes(fileNodes, locale: locale) { fileNode in
            try addFallbackTargets(fileNode)
        }

        do {
            try xml.xmlString(options: .nodePrettyPrint).write(to: fileUrl, atomically: true, encoding: .utf16)
        } catch {
            throw L10nError.fileWriteFailed(path: fileUrl.path, underlyingError: error)
        }
    }

    /// Runs xcodebuild to import the .xcloc bundle into the Xcode project.
    private func importLocale(xclocPath: URL) throws {
        let command = "xcodebuild -importLocalizations -project \(xcodeProjPath) -localizationPath \(xclocPath.path)"

        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        do {
            try task.run()
        } catch {
            throw L10nError.processExecutionFailed(command: "xcodebuild -importLocalizations", underlyingError: error)
        }
        task.waitUntilExit()

        if task.terminationStatus != 0 {
            throw L10nError.commandFailed(
                command: "xcodebuild -importLocalizations",
                exitCode: task.terminationStatus
            )
        }
    }

    /// Processes a single locale.
    private func prepareLocale(locale: String) throws {
        let xliffUrl = try createXcloc(locale: locale)
        try validateXml(fileUrl: xliffUrl, locale: locale)
        try importLocale(xclocPath: xliffUrl.deletingLastPathComponent().deletingLastPathComponent())
    }

    /// Executes the import task for all configured locales.
    func run() throws {
        for (index, locale) in locales.enumerated() {
            Herald.declare("[\(index + 1)/\(locales.count)] Importing \(locale)...")
            try prepareLocale(locale: locale)
        }
    }
}
