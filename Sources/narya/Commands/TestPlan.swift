// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import ArgumentParser
import Foundation

// MARK: - Test Plan

enum TestPlan: String, ExpressibleByArgument, CaseIterable {
    case unit
    case smoke
    case accessibility
    case performance
    case full  // Focus/Klar only (FullFunctionalTests)

    init?(argument: String) {
        switch argument.lowercased() {
        case "unit":
            self = .unit
        case "smoke":
            self = .smoke
        case "accessibility", "a11y":
            self = .accessibility
        case "performance", "perf":
            self = .performance
        case "full":
            self = .full
        default:
            return nil
        }
    }

    /// Returns the xctestrun file name prefix for a given product
    func xctestrunPrefix(for product: BuildProduct) -> String? {
        switch (self, product) {
        case (.unit, .firefox):
            return "Fennec_UnitTest"
        case (.unit, .focus):
            return "Focus_UnitTests"
        case (.unit, .klar):
            return "Klar_UnitTests"
        case (.smoke, .firefox):
            return "Fennec_Smoketest"
        case (.smoke, .focus):
            return "Focus_SmokeTest"
        case (.smoke, .klar):
            return "Klar_SmokeTest"
        case (.accessibility, .firefox):
            return "Fennec_AccessibilityTestPlan"
        case (.accessibility, .focus), (.accessibility, .klar):
            return nil  // Not available for Focus/Klar
        case (.performance, .firefox):
            return "Fennec_PerformanceTestPlan"
        case (.performance, .focus), (.performance, .klar):
            return nil  // Not available for Focus/Klar
        case (.full, .focus):
            return "Focus_FullFunctionalTests"
        case (.full, .klar):
            return "Klar_FullFunctionalTests"
        case (.full, .firefox):
            return nil  // Not available for Firefox
        }
    }

    /// Returns the test plan name for xcodebuild -testPlan argument
    func testPlanName(for product: BuildProduct) -> String? {
        switch (self, product) {
        case (.unit, .firefox):
            return "UnitTest"
        case (.unit, .focus):
            return "UnitTests"
        case (.unit, .klar):
            return "UnitTests"
        case (.smoke, .firefox):
            return "Smoketest"
        case (.smoke, .focus):
            return "SmokeTest"
        case (.smoke, .klar):
            return "SmokeTest"
        case (.accessibility, .firefox):
            return "AccessibilityTestPlan"
        case (.accessibility, .focus), (.accessibility, .klar):
            return nil
        case (.performance, .firefox):
            return "PerformanceTestPlan"
        case (.performance, .focus), (.performance, .klar):
            return nil
        case (.full, .focus):
            return "FullFunctionalTests"
        case (.full, .klar):
            return "FullFunctionalTests"
        case (.full, .firefox):
            return nil
        }
    }

    /// Human-readable description
    var displayName: String {
        switch self {
        case .unit: return "Unit Tests"
        case .smoke: return "Smoke Tests"
        case .accessibility: return "Accessibility Tests"
        case .performance: return "Performance Tests"
        case .full: return "Full Functional Tests"
        }
    }
}

// MARK: - Test Errors

enum TestError: Error, CustomStringConvertible {
    case testPlanNotAvailable(plan: TestPlan, product: BuildProduct)
    case testBundleNotFound(path: String)
    case xctestrunNotFound(pattern: String)
    case testsFailed(exitCode: Int32)

    var description: String {
        switch self {
        case .testPlanNotAvailable(let plan, let product):
            return "Test plan '\(plan.rawValue)' is not available for \(product.scheme)."
        case .testBundleNotFound(let path):
            return "Test bundle not found at \(path). Run 'narya test --build-first' to build tests."
        case .xctestrunNotFound(let pattern):
            return "No xctestrun file found matching '\(pattern)'. Run 'narya build --for-testing' first."
        case .testsFailed(let exitCode):
            return "Tests failed with exit code \(exitCode)."
        }
    }
}
