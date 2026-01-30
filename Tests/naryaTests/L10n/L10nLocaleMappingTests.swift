// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

/// Tests for L10nLocaleMapping functionality.
@Suite("L10nLocaleMapping Tests")
struct L10nLocaleMappingTests {
    // MARK: - Pontoon to Xcode Mapping Tests

    @Suite("Pontoon to Xcode Mapping")
    struct PontoonToXcodeTests {
        @Test("Maps ga-IE to ga")
        func mapsGaIE() {
            #expect(L10nLocaleMapping.toXcode("ga-IE") == "ga")
        }

        @Test("Maps nb-NO to nb")
        func mapsNbNO() {
            #expect(L10nLocaleMapping.toXcode("nb-NO") == "nb")
        }

        @Test("Maps nn-NO to nn")
        func mapsNnNO() {
            #expect(L10nLocaleMapping.toXcode("nn-NO") == "nn")
        }

        @Test("Maps sv-SE to sv")
        func mapsSvSE() {
            #expect(L10nLocaleMapping.toXcode("sv-SE") == "sv")
        }

        @Test("Maps tl to fil")
        func mapsTl() {
            #expect(L10nLocaleMapping.toXcode("tl") == "fil")
        }

        @Test("Maps sat to sat-Olck")
        func mapsSat() {
            #expect(L10nLocaleMapping.toXcode("sat") == "sat-Olck")
        }

        @Test("Maps zgh to tzm")
        func mapsZgh() {
            #expect(L10nLocaleMapping.toXcode("zgh") == "tzm")
        }

        @Test("Preserves unmapped locales")
        func preservesUnmapped() {
            #expect(L10nLocaleMapping.toXcode("fr") == "fr")
            #expect(L10nLocaleMapping.toXcode("de") == "de")
            #expect(L10nLocaleMapping.toXcode("ja") == "ja")
            #expect(L10nLocaleMapping.toXcode("zh-Hans") == "zh-Hans")
        }
    }

    // MARK: - Xcode to Pontoon Mapping Tests

    @Suite("Xcode to Pontoon Mapping")
    struct XcodeToPontoonTests {

        @Test("Maps ga to ga-IE")
        func mapsGa() {
            #expect(L10nLocaleMapping.toPontoon("ga") == "ga-IE")
        }

        @Test("Maps nb to nb-NO")
        func mapsNb() {
            #expect(L10nLocaleMapping.toPontoon("nb") == "nb-NO")
        }

        @Test("Maps nn to nn-NO")
        func mapsNn() {
            #expect(L10nLocaleMapping.toPontoon("nn") == "nn-NO")
        }

        @Test("Maps sv to sv-SE")
        func mapsSv() {
            #expect(L10nLocaleMapping.toPontoon("sv") == "sv-SE")
        }

        @Test("Maps fil to tl")
        func mapsFil() {
            #expect(L10nLocaleMapping.toPontoon("fil") == "tl")
        }

        @Test("Maps sat-Olck to sat")
        func mapsSatOlck() {
            #expect(L10nLocaleMapping.toPontoon("sat-Olck") == "sat")
        }

        @Test("Maps en to en-US")
        func mapsEn() {
            #expect(L10nLocaleMapping.toPontoon("en") == "en-US")
        }

        @Test("Preserves unmapped locales")
        func preservesUnmapped() {
            #expect(L10nLocaleMapping.toPontoon("fr") == "fr")
            #expect(L10nLocaleMapping.toPontoon("de") == "de")
            #expect(L10nLocaleMapping.toPontoon("ja") == "ja")
        }
    }

    // MARK: - Bidirectional Mapping Tests

    @Suite("Bidirectional Mapping")
    struct BidirectionalTests {

        @Test("Mappings are inverses for standard cases")
        func mappingsAreInverses() {
            let pairs: [(pontoon: String, xcode: String)] = [
                ("ga-IE", "ga"),
                ("nb-NO", "nb"),
                ("nn-NO", "nn"),
                ("sv-SE", "sv"),
                ("tl", "fil"),
                ("sat", "sat-Olck"),
            ]

            for pair in pairs {
                let xcodeResult = L10nLocaleMapping.toXcode(pair.pontoon)
                #expect(xcodeResult == pair.xcode, "toXcode(\(pair.pontoon)) should be \(pair.xcode)")

                let pontoonResult = L10nLocaleMapping.toPontoon(pair.xcode)
                #expect(pontoonResult == pair.pontoon, "toPontoon(\(pair.xcode)) should be \(pair.pontoon)")
            }
        }
    }

    // MARK: - Static Mapping Dictionary Tests

    @Suite("Static Mapping Dictionaries")
    struct StaticDictionaryTests {

        @Test("pontoonToXcode has correct count")
        func pontoonToXcodeCount() {
            #expect(L10nLocaleMapping.pontoonToXcode.count == 7)
        }

        @Test("xcodeToPontoon has correct count")
        func xcodeToPontoonCount() {
            // 7 mappings (inverse of pontoonToXcode, but zgh->tzm is not invertible the same way)
            #expect(L10nLocaleMapping.xcodeToPontoon.count == 7)
        }

        @Test("pontoonToXcode contains expected keys")
        func pontoonToXcodeContainsExpectedKeys() {
            let expectedKeys = ["ga-IE", "nb-NO", "nn-NO", "sv-SE", "tl", "sat", "zgh"]
            for key in expectedKeys {
                #expect(L10nLocaleMapping.pontoonToXcode.keys.contains(key))
            }
        }
    }
}
