// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

@Suite("DeviceShorthand Tests", .serialized)
struct DeviceShorthandTests {
    // MARK: - iPhone Shorthand Derivation Tests

    @Test("iPhone base model derives shorthand")
    func iphoneBaseModel() {
        #expect(DeviceShorthand.shorthand(for: "iPhone 17") == "17")
        #expect(DeviceShorthand.shorthand(for: "iPhone 16") == "16")
        #expect(DeviceShorthand.shorthand(for: "iPhone 15") == "15")
    }

    @Test("iPhone Pro derives shorthand")
    func iphonePro() {
        #expect(DeviceShorthand.shorthand(for: "iPhone 17 Pro") == "17pro")
        #expect(DeviceShorthand.shorthand(for: "iPhone 16 Pro") == "16pro")
    }

    @Test("iPhone Pro Max derives shorthand")
    func iphoneProMax() {
        #expect(DeviceShorthand.shorthand(for: "iPhone 17 Pro Max") == "17max")
        #expect(DeviceShorthand.shorthand(for: "iPhone 16 Pro Max") == "16max")
    }

    @Test("iPhone Plus derives shorthand")
    func iphonePlus() {
        #expect(DeviceShorthand.shorthand(for: "iPhone 17 Plus") == "17plus")
        #expect(DeviceShorthand.shorthand(for: "iPhone 16 Plus") == "16plus")
    }

    @Test("iPhone e variant derives shorthand")
    func iphoneEVariant() {
        #expect(DeviceShorthand.shorthand(for: "iPhone 16e") == "16e")
    }

    @Test("iPhone SE derives shorthand")
    func iphoneSE() {
        #expect(DeviceShorthand.shorthand(for: "iPhone SE") == "se")
        #expect(DeviceShorthand.shorthand(for: "iPhone SE (3rd generation)") == "se")
    }

    @Test("iPhone Air derives shorthand")
    func iphoneAir() {
        #expect(DeviceShorthand.shorthand(for: "iPhone Air") == "air")
    }

    // MARK: - iPad Air/Pro Shorthand Derivation Tests

    @Test("iPad Air with whole inch size derives shorthand")
    func ipadAirWholeInch() {
        #expect(DeviceShorthand.shorthand(for: "iPad Air 11-inch") == "air11")
        #expect(DeviceShorthand.shorthand(for: "iPad Air 13-inch") == "air13")
        #expect(DeviceShorthand.shorthand(for: "iPad Air 11-inch (M2)") == "air11")
    }

    @Test("iPad Pro with whole inch size derives shorthand")
    func ipadProWholeInch() {
        #expect(DeviceShorthand.shorthand(for: "iPad Pro 11-inch") == "pro11")
        #expect(DeviceShorthand.shorthand(for: "iPad Pro 13-inch") == "pro13")
        #expect(DeviceShorthand.shorthand(for: "iPad Pro 11-inch (M4)") == "pro11")
    }

    @Test("iPad Pro 12.9-inch derives guessable shorthand")
    func ipadPro129Inch() {
        // 12.9-inch should derive to guessable "13"
        #expect(DeviceShorthand.shorthand(for: "iPad Pro 12.9-inch") == "pro13")
        #expect(DeviceShorthand.shorthand(for: "iPad Pro 12.9-inch (6th generation)") == "pro13")
    }

    @Test("iPad with 10.x-inch sizes derives guessable shorthand")
    func ipadTenInchVariants() {
        // All 10.x sizes should derive to guessable "10"
        #expect(DeviceShorthand.shorthand(for: "iPad Air 10.9-inch") == "air10")
        #expect(DeviceShorthand.shorthand(for: "iPad Pro 10.5-inch") == "pro10")
    }

    // MARK: - iPad mini Shorthand Derivation Tests

    @Test("iPad mini without suffix derives shorthand")
    func ipadMiniPlain() {
        #expect(DeviceShorthand.shorthand(for: "iPad mini") == "mini")
    }

    @Test("iPad mini with generation derives shorthand")
    func ipadMiniGeneration() {
        #expect(DeviceShorthand.shorthand(for: "iPad mini (6th generation)") == "mini6g")
        #expect(DeviceShorthand.shorthand(for: "iPad mini (7th generation)") == "mini7g")
        // Test ordinal handling
        #expect(DeviceShorthand.shorthand(for: "iPad mini (1st generation)") == "mini1g")
        #expect(DeviceShorthand.shorthand(for: "iPad mini (2nd generation)") == "mini2g")
        #expect(DeviceShorthand.shorthand(for: "iPad mini (3rd generation)") == "mini3g")
    }

    @Test("iPad mini with chip derives shorthand")
    func ipadMiniChip() {
        #expect(DeviceShorthand.shorthand(for: "iPad mini (A17 Pro)") == "miniA17")
        #expect(DeviceShorthand.shorthand(for: "iPad mini (A15)") == "miniA15")
    }

    // MARK: - iPad Generation Shorthand Derivation Tests

    @Test("iPad with generation derives shorthand")
    func ipadGeneration() {
        #expect(DeviceShorthand.shorthand(for: "iPad (10th generation)") == "pad10g")
        #expect(DeviceShorthand.shorthand(for: "iPad (9th generation)") == "pad9g")
        // Test ordinal handling
        #expect(DeviceShorthand.shorthand(for: "iPad (1st generation)") == "pad1g")
        #expect(DeviceShorthand.shorthand(for: "iPad (2nd generation)") == "pad2g")
        #expect(DeviceShorthand.shorthand(for: "iPad (3rd generation)") == "pad3g")
    }

    @Test("iPad with chip derives shorthand")
    func ipadChip() {
        #expect(DeviceShorthand.shorthand(for: "iPad (A16)") == "padA16")
        #expect(DeviceShorthand.shorthand(for: "iPad (A14)") == "padA14")
    }

    // MARK: - Devices Without Shorthands

    @Test("Devices that don't fit patterns return nil")
    func devicesWithoutShorthands() {
        // Old iPad naming with parens around size
        #expect(DeviceShorthand.shorthand(for: "iPad Pro (11-inch) (4th generation)") == nil)
        // Apple Watch
        #expect(DeviceShorthand.shorthand(for: "Apple Watch Series 9") == nil)
        // Apple TV
        #expect(DeviceShorthand.shorthand(for: "Apple TV 4K") == nil)
    }

    // MARK: - Error Description Tests

    @Test("Invalid shorthand error includes examples")
    func invalidShorthandError() {
        let error = DeviceShorthandError.invalidShorthand(shorthand: "xyz")
        let description = error.description
        #expect(description.contains("xyz"))
        #expect(description.contains("17pro"))
        #expect(description.contains("mini6g"))
        #expect(description.contains("pro13"))
    }

    @Test("Simulator not found error includes available simulators")
    func simulatorNotFoundError() {
        let error = DeviceShorthandError.simulatorNotFound(
            shorthand: "99pro",
            type: .phone,
            available: ["iPhone 17 (iOS 18.2)", "iPhone 16 (iOS 18.2)"]
        )
        let description = error.description
        #expect(description.contains("99pro"))
        #expect(description.contains("iPhone 17"))
    }

    // MARK: - Guessable Size Tests

    @Test("deriveGuessableSize converts fractional to whole")
    func deriveGuessableSizeConversion() {
        // Test via full device name derivation
        #expect(DeviceShorthand.shorthand(for: "iPad Pro 12.9-inch") == "pro13")
        #expect(DeviceShorthand.shorthand(for: "iPad Air 10.9-inch") == "air10")
        #expect(DeviceShorthand.shorthand(for: "iPad Pro 10.5-inch") == "pro10")
    }

    // MARK: - Shorthand Pattern Validation Tests (Reverse Lookup)
    //
    // These tests verify that shorthand patterns are correctly recognized.
    // A valid pattern will throw simulatorNotFound (pattern parsed, no match).
    // An invalid pattern will throw invalidShorthand.

    @Test("Valid iPhone shorthands are recognized as valid patterns")
    func validIphonePatternsRecognized() {
        // Test various valid iPhone patterns - they should NOT throw invalidShorthand
        let validShorthands = ["17", "16", "15", "17pro", "16pro", "17max", "16max",
                               "17plus", "16plus", "16e", "se", "air"]

        for shorthand in validShorthands {
            do {
                _ = try DeviceShorthand.findSimulator(shorthand: shorthand, osVersion: nil)
                // If we get here, a simulator was found (unexpected but valid)
            } catch let error as DeviceShorthandError {
                switch error {
                case .simulatorNotFound:
                    // This is expected - pattern was valid but no simulator matched
                    break
                case .invalidShorthand:
                    Issue.record("Shorthand '\(shorthand)' should be valid but was rejected as invalid")
                }
            } catch {
                Issue.record("Unexpected error for shorthand '\(shorthand)': \(error)")
            }
        }
    }

    @Test("Valid iPad shorthands are recognized as valid patterns")
    func validIpadPatternsRecognized() {
        // Test various valid iPad patterns - they should NOT throw invalidShorthand
        let validShorthands = ["air11", "air13", "air10", "pro11", "pro13", "pro10",
                               "pro129", "pro105", "pro102", "pro109",
                               "mini", "mini6g", "mini7g", "mini1g", "mini2g", "mini3g",
                               "miniA17", "miniA15",
                               "pad10g", "pad9g", "pad1g", "pad2g", "pad3g",
                               "padA16", "padA14"]

        for shorthand in validShorthands {
            do {
                _ = try DeviceShorthand.findSimulator(shorthand: shorthand, osVersion: nil)
                // If we get here, a simulator was found (unexpected but valid)
            } catch let error as DeviceShorthandError {
                switch error {
                case .simulatorNotFound:
                    // This is expected - pattern was valid but no simulator matched
                    break
                case .invalidShorthand:
                    Issue.record("Shorthand '\(shorthand)' should be valid but was rejected as invalid")
                }
            } catch {
                Issue.record("Unexpected error for shorthand '\(shorthand)': \(error)")
            }
        }
    }

    @Test("Invalid shorthands are rejected")
    func invalidShorthandsRejected() {
        // Test various invalid patterns - they should throw invalidShorthand
        let invalidShorthands = ["xyz", "abc123", "phone", "ipad", "watch",
                                 "promax", "maxpro", "iphone17", "17 pro",
                                 "air", // "air" is a valid iPhone pattern, not iPad
                                 "minimax", "padpro"]

        for shorthand in invalidShorthands {
            // Skip "air" since it's actually valid for iPhone
            if shorthand == "air" { continue }

            do {
                _ = try DeviceShorthand.findSimulator(shorthand: shorthand, osVersion: nil)
                // If we get here, a simulator was found (unexpected)
                Issue.record("Shorthand '\(shorthand)' unexpectedly found a simulator")
            } catch let error as DeviceShorthandError {
                switch error {
                case .invalidShorthand:
                    // This is expected - pattern was invalid
                    break
                case .simulatorNotFound:
                    Issue.record("Shorthand '\(shorthand)' should be invalid but was parsed as valid pattern")
                }
            } catch {
                Issue.record("Unexpected error for shorthand '\(shorthand)': \(error)")
            }
        }
    }

    @Test("Case insensitive shorthand parsing")
    func caseInsensitiveShorthands() {
        // Shorthands should work regardless of case
        let casePairs = [("17PRO", "17pro"), ("17Pro", "17pro"),
                         ("AIR11", "air11"), ("Air11", "air11"),
                         ("MINI6G", "mini6g"), ("Mini6G", "mini6g"),
                         ("SE", "se"), ("Se", "se")]

        for (upperCase, _) in casePairs {
            do {
                _ = try DeviceShorthand.findSimulator(shorthand: upperCase, osVersion: nil)
            } catch let error as DeviceShorthandError {
                switch error {
                case .simulatorNotFound:
                    // Expected - pattern was valid but no simulator matched
                    break
                case .invalidShorthand:
                    Issue.record("Shorthand '\(upperCase)' should be valid (case insensitive) but was rejected")
                }
            } catch {
                Issue.record("Unexpected error for shorthand '\(upperCase)': \(error)")
            }
        }
    }

    // MARK: - Precise vs Guessable Size Pattern Tests

    @Test("Precise size patterns are recognized")
    func preciseSizePatternsRecognized() {
        // These precise patterns should be valid
        let precisePatterns = ["pro129", "pro105", "pro102", "pro109", "air109"]

        for shorthand in precisePatterns {
            do {
                _ = try DeviceShorthand.findSimulator(shorthand: shorthand, osVersion: nil)
            } catch let error as DeviceShorthandError {
                switch error {
                case .simulatorNotFound:
                    // Expected - pattern was valid
                    break
                case .invalidShorthand:
                    Issue.record("Precise size shorthand '\(shorthand)' should be valid")
                }
            } catch {
                Issue.record("Unexpected error for shorthand '\(shorthand)': \(error)")
            }
        }
    }

    // MARK: - DeviceType Tests

    @Test("DeviceType displayName is correct")
    func deviceTypeDisplayNames() {
        #expect(DeviceType.phone.displayName == "iPhone")
        #expect(DeviceType.ipad.displayName == "iPad")
    }

    @Test("DeviceType raw values are correct")
    func deviceTypeRawValues() {
        #expect(DeviceType.phone.rawValue == "phone")
        #expect(DeviceType.ipad.rawValue == "ipad")
    }

    // MARK: - Error Message Content Tests

    @Test("Simulator not found error with empty available list")
    func simulatorNotFoundEmptyList() {
        let error = DeviceShorthandError.simulatorNotFound(
            shorthand: "99pro",
            type: .phone,
            available: []
        )
        let description = error.description
        #expect(description.contains("99pro"))
        #expect(description.contains("(none installed)"))
    }

    @Test("Simulator not found error truncates long list")
    func simulatorNotFoundLongList() {
        let manySimulators = (1...15).map { "iPhone \($0) (iOS 18.0)" }
        let error = DeviceShorthandError.simulatorNotFound(
            shorthand: "99pro",
            type: .phone,
            available: manySimulators
        )
        let description = error.description
        #expect(description.contains("... and 5 more"))
    }

    // MARK: - Bidirectional Consistency Tests

    @Test("Shorthand derivation and lookup are consistent for iPhones")
    func bidirectionalConsistencyIphones() {
        // Test that deriving a shorthand and looking it up should work
        let devices = [
            "iPhone 17", "iPhone 17 Pro", "iPhone 17 Pro Max", "iPhone 17 Plus",
            "iPhone 16", "iPhone 16 Pro", "iPhone 16 Pro Max", "iPhone 16 Plus",
            "iPhone 16e", "iPhone SE", "iPhone Air"
        ]

        for device in devices {
            guard let shorthand = DeviceShorthand.shorthand(for: device) else {
                Issue.record("Failed to derive shorthand for '\(device)'")
                continue
            }

            // The derived shorthand should be a valid pattern
            do {
                _ = try DeviceShorthand.findSimulator(shorthand: shorthand, osVersion: nil)
            } catch let error as DeviceShorthandError {
                switch error {
                case .simulatorNotFound:
                    // Expected - shorthand is valid
                    break
                case .invalidShorthand:
                    Issue.record("Derived shorthand '\(shorthand)' for '\(device)' is not a valid pattern")
                }
            } catch {
                Issue.record("Unexpected error for device '\(device)': \(error)")
            }
        }
    }

    @Test("Shorthand derivation and lookup are consistent for iPads")
    func bidirectionalConsistencyIpads() {
        let devices = [
            "iPad Air 11-inch", "iPad Air 13-inch",
            "iPad Pro 11-inch", "iPad Pro 13-inch", "iPad Pro 12.9-inch",
            "iPad mini", "iPad mini (6th generation)", "iPad mini (A17 Pro)",
            "iPad (10th generation)", "iPad (A16)"
        ]

        for device in devices {
            guard let shorthand = DeviceShorthand.shorthand(for: device) else {
                Issue.record("Failed to derive shorthand for '\(device)'")
                continue
            }

            // The derived shorthand should be a valid pattern
            do {
                _ = try DeviceShorthand.findSimulator(shorthand: shorthand, osVersion: nil)
            } catch let error as DeviceShorthandError {
                switch error {
                case .simulatorNotFound:
                    // Expected - shorthand is valid
                    break
                case .invalidShorthand:
                    Issue.record("Derived shorthand '\(shorthand)' for '\(device)' is not a valid pattern")
                }
            } catch {
                Issue.record("Unexpected error for device '\(device)': \(error)")
            }
        }
    }
}
