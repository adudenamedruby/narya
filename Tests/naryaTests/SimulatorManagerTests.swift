// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Testing
@testable import narya

@Suite("SimulatorManager Tests", .serialized)
struct SimulatorManagerTests {
    // MARK: - isPreferredSimulator Tests

    @Test("iPhone 16 is preferred")
    func iphone16IsPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 16") == true)
    }

    @Test("iPhone 15 is preferred")
    func iphone15IsPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 15") == true)
    }

    @Test("iPhone 14 is preferred")
    func iphone14IsPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 14") == true)
    }

    @Test("iPhone 16 Pro is not preferred")
    func iphone16ProNotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 16 Pro") == false)
    }

    @Test("iPhone 16 Pro Max is not preferred")
    func iphone16ProMaxNotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 16 Pro Max") == false)
    }

    @Test("iPhone 16 Plus is not preferred")
    func iphone16PlusNotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 16 Plus") == false)
    }

    @Test("iPhone 15 Pro is not preferred")
    func iphone15ProNotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 15 Pro") == false)
    }

    @Test("iPhone 15 Pro Max is not preferred")
    func iphone15ProMaxNotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 15 Pro Max") == false)
    }

    @Test("iPhone 15 Plus is not preferred")
    func iphone15PlusNotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 15 Plus") == false)
    }

    @Test("iPhone SE is not preferred")
    func iphoneSENotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone SE (3rd generation)") == false)
    }

    @Test("iPhone 13 mini is not preferred")
    func iphone13MiniNotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPhone 13 mini") == false)
    }

    @Test("iPad is not preferred")
    func iPadNotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("iPad Pro (12.9-inch)") == false)
    }

    @Test("Apple Watch is not preferred")
    func appleWatchNotPreferred() {
        #expect(SimulatorManager.isPreferredSimulator("Apple Watch Series 9") == false)
    }

    // MARK: - Simulator Model Tests

    @Test("Simulator model correctly identifies booted state")
    func simulatorBootedState() {
        let bootedSim = Simulator(udid: "123", name: "iPhone 16", state: "Booted", isAvailable: true)
        let shutdownSim = Simulator(udid: "456", name: "iPhone 15", state: "Shutdown", isAvailable: true)

        #expect(bootedSim.isBooted == true)
        #expect(shutdownSim.isBooted == false)
    }

    // MARK: - SimulatorSelection Model Tests

    @Test("SimulatorSelection contains correct data")
    func simulatorSelectionData() {
        let sim = Simulator(
            udid: "test-udid",
            name: "iPhone 16",
            state: "Shutdown",
            isAvailable: true
        )
        let runtime = SimulatorRuntime(
            identifier: "com.apple.CoreSimulator.iOS-18-2",
            name: "iOS 18.2",
            version: "18.2",
            isAvailable: true
        )
        let selection = SimulatorSelection(simulator: sim, runtime: runtime)

        #expect(selection.simulator.name == "iPhone 16")
        #expect(selection.runtime.version == "18.2")
    }

    // MARK: - Error Description Tests

    /// A simple test error for testing error chaining.
    struct TestUnderlyingError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @Test("SimulatorManagerError descriptions are correct")
    func errorDescriptions() {
        let simctlError = SimulatorManagerError.simctlFailed(reason: "test reason", underlyingError: nil)
        #expect(simctlError.description.contains("simctl"))
        #expect(simctlError.description.contains("test reason"))

        let noSimsError = SimulatorManagerError.noSimulatorsFound
        #expect(noSimsError.description.contains("No iOS simulators"))

        let notFoundError = SimulatorManagerError.simulatorNotFound("iPhone 99")
        #expect(notFoundError.description.contains("iPhone 99"))

        let parseError = SimulatorManagerError.parseError(reason: "invalid json", underlyingError: nil)
        #expect(parseError.description.contains("parse"))
        #expect(parseError.description.contains("invalid json"))

        let bootError = SimulatorManagerError.bootFailed(reason: "boot reason", underlyingError: nil)
        #expect(bootError.description.contains("boot"))

        let installError = SimulatorManagerError.installFailed(reason: "install reason", underlyingError: nil)
        #expect(installError.description.contains("install"))

        let launchError = SimulatorManagerError.launchFailed(reason: "launch reason", underlyingError: nil)
        #expect(launchError.description.contains("launch"))
    }

    @Test("SimulatorManagerError includes underlying error in description")
    func errorChainingDescriptions() {
        let underlying = TestUnderlyingError(message: "Connection refused")

        let simctlError = SimulatorManagerError.simctlFailed(reason: "network issue", underlyingError: underlying)
        #expect(simctlError.description.contains("network issue"))
        #expect(simctlError.description.contains("Connection refused"))

        let parseError = SimulatorManagerError.parseError(reason: "JSON decoding failed", underlyingError: underlying)
        #expect(parseError.description.contains("JSON decoding failed"))
        #expect(parseError.description.contains("Connection refused"))

        let bootError = SimulatorManagerError.bootFailed(reason: "simctl boot failed", underlyingError: underlying)
        #expect(bootError.description.contains("simctl boot failed"))
        #expect(bootError.description.contains("Connection refused"))

        let installError = SimulatorManagerError.installFailed(reason: "simctl install failed", underlyingError: underlying)
        #expect(installError.description.contains("simctl install failed"))
        #expect(installError.description.contains("Connection refused"))

        let launchError = SimulatorManagerError.launchFailed(reason: "simctl launch failed", underlyingError: underlying)
        #expect(launchError.description.contains("simctl launch failed"))
        #expect(launchError.description.contains("Connection refused"))
    }

    // MARK: - Integration Tests (require Xcode/simctl)

    @Test("listSimulators returns results when simctl available")
    func listSimulatorsIntegration() throws {
        // This test requires simctl to be available
        // Skip if not on macOS with Xcode
        #if !os(macOS)
        throw XCTSkip("Simulator tests only run on macOS")
        #endif

        do {
            let simulators = try SimulatorManager.listSimulators()
            // We expect at least some simulators to be available if Xcode is installed
            // But we don't fail if there are none, as this could run in a CI without simulators
            if !simulators.isEmpty {
                // Verify structure
                let (runtime, devices) = simulators[0]
                #expect(!runtime.name.isEmpty)
                #expect(!runtime.version.isEmpty)
                #expect(!devices.isEmpty)
            }
        } catch SimulatorManagerError.simctlFailed {
            // simctl not available, skip this test
        }
    }

    @Test("findDefaultSimulator returns a simulator when available")
    func findDefaultSimulatorIntegration() throws {
        #if !os(macOS)
        throw XCTSkip("Simulator tests only run on macOS")
        #endif

        do {
            let selection = try SimulatorManager.findDefaultSimulator()
            #expect(selection.simulator.name.hasPrefix("iPhone"))
            #expect(!selection.runtime.version.isEmpty)
        } catch SimulatorManagerError.simctlFailed {
            // simctl not available, skip this test
        } catch SimulatorManagerError.noSimulatorsFound {
            // No simulators installed, skip this test
        }
    }
}
