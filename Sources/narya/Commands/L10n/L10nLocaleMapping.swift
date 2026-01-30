// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

/// Centralized locale code mappings between Pontoon (l10n repository) and Xcode.
///
/// Different systems use different locale codes for the same language:
/// - Pontoon (Mozilla's translation platform) uses codes like "ga-IE", "nb-NO"
/// - Xcode uses codes like "ga", "nb", "fil"
///
/// This module provides a single source of truth for these mappings.
enum L10nLocaleMapping {
    /// Maps Pontoon locale codes to Xcode locale codes.
    /// Used during import when converting l10n repository files for Xcode.
    static let pontoonToXcode: [String: String] = [
        "ga-IE": "ga",
        "nb-NO": "nb",
        "nn-NO": "nn",
        "sv-SE": "sv",
        "tl": "fil",
        "sat": "sat-Olck",
        "zgh": "tzm"
    ]

    /// Maps Xcode locale codes to Pontoon locale codes.
    /// Used during export when copying files to the l10n repository.
    /// Computed as the inverse of `pontoonToXcode`.
    static let xcodeToPontoon: [String: String] = {
        var inverse: [String: String] = [:]
        for (pontoon, xcode) in pontoonToXcode {
            inverse[xcode] = pontoon
        }
        return inverse
    }()

    /// Converts a Pontoon locale code to its Xcode equivalent.
    /// Returns the original code if no mapping exists.
    static func toXcode(_ pontoonLocale: String) -> String {
        pontoonToXcode[pontoonLocale] ?? pontoonLocale
    }

    /// Converts an Xcode locale code to its Pontoon equivalent.
    /// Returns the original code if no mapping exists.
    /// Special case: "en" maps to "en-US" for the l10n repository.
    static func toPontoon(_ xcodeLocale: String) -> String {
        if xcodeLocale == "en" {
            return "en-US"
        }
        return xcodeToPontoon[xcodeLocale] ?? xcodeLocale
    }
}
