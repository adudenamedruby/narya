// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

/// Localization tools for managing XLIFF files and translations.
///
/// Provides commands to import and export localization files between
/// Xcode projects and l10n repositories used by Mozilla's translation platform (Pontoon).
struct L10n: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "l10n",
        abstract: "Localization tools for managing XLIFF files and translations.",
        discussion: """
            Tools for automating localization workflows in Mozilla iOS projects.

            The l10n subcommands will handle:
            - Locale code mapping between Xcode and Pontoon formats
            - Filtering of non-translatable keys (CFBundleName, etc.)
            - Required translation validation (privacy permissions, shortcuts)
            - Comment overrides from l10n_comments.txt
            """,
        subcommands: [
            Export.self,
            Import.self,
            Templates.self
        ]
    )
}
