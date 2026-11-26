//
//  AppDistributionTests.swift
//  PVJITTests
//
//  The distribution decision and the JIT UI gate, with injected inputs.
//

import XCTest
import JITManager

final class AppDistributionTests: XCTestCase {

    private let official = "org.provenance-emu.provenance"

    private func inputs(simulator: Bool = false,
                        bundleID: String? = "org.provenance-emu.provenance",
                        profile: Bool = false,
                        getTaskAllow: Bool = false,
                        receipt: String? = "receipt",
                        jailbreak: Bool = false) -> AppDistributionInputs {
        AppDistributionInputs(isSimulator: simulator,
                              bundleIdentifier: bundleID,
                              hasEmbeddedProvisioningProfile: profile,
                              profileAllowsDebugging: getTaskAllow,
                              receiptFileName: receipt,
                              hasJailbreakMarkers: jailbreak)
    }

    // MARK: - Distribution

    func testTestFlightInstall() {
        // No embedded profile, sandbox receipt, get-task-allow false.
        XCTAssertEqual(AppDistribution.resolve(inputs(receipt: "sandboxReceipt")), .testFlight)
    }

    func testAppStoreInstall() {
        XCTAssertEqual(AppDistribution.resolve(inputs(receipt: "receipt")), .appStore)
        XCTAssertEqual(AppDistribution.resolve(inputs(receipt: nil)), .appStore)
    }

    func testOfficialVariantsAreStoreInstalls() {
        for suffix in ["", ".alpha", ".lite"] {
            XCTAssertEqual(AppDistribution.resolve(inputs(bundleID: official + suffix, receipt: "sandboxReceipt")),
                           .testFlight, suffix)
        }
    }

    func testDevelopmentBuild() {
        // Xcode and AltStore/SideStore sign with a development profile; the receipt
        // path is also `sandboxReceipt` there, so the profile must win.
        XCTAssertEqual(AppDistribution.resolve(inputs(profile: true, getTaskAllow: true, receipt: "sandboxReceipt")),
                       .development)
    }

    func testResignedBuildKeepingTheBundleID() {
        // An ad hoc or enterprise re-sign of the store build with the same bundle id.
        XCTAssertEqual(AppDistribution.resolve(inputs(profile: true, getTaskAllow: false)), .sideloaded)
    }

    func testChangedBundleID() {
        XCTAssertEqual(AppDistribution.resolve(inputs(bundleID: "com.someone.provenance", receipt: "sandboxReceipt")),
                       .sideloaded)
        XCTAssertEqual(AppDistribution.resolve(inputs(bundleID: nil)), .sideloaded)
    }

    func testStoreBuildOnJailbrokenDevice() {
        XCTAssertEqual(AppDistribution.resolve(inputs(receipt: "receipt", jailbreak: true)), .jailbroken)
        XCTAssertEqual(AppDistribution.resolve(inputs(receipt: "sandboxReceipt", jailbreak: true)), .jailbroken)
    }

    func testSimulatorWinsOverEverything() {
        XCTAssertEqual(AppDistribution.resolve(inputs(simulator: true, receipt: "sandboxReceipt")), .simulator)
    }

    func testOnlyTestFlightAndAppStoreAreStoreInstalls() {
        let store = AppDistribution.allCases.filter(\.isStoreInstall)
        XCTAssertEqual(Set(store), [.testFlight, .appStore])
    }

    // MARK: - JIT UI gate

    func testStoreInstallsShowNoJITUI() {
        for distribution in [AppDistribution.testFlight, .appStore] {
            for wx in [true, false] {
                let policy = JITUIPolicy(distribution: distribution, jitAcquired: false, isWXEnforced: wx)
                XCTAssertFalse(policy.showsJITUI, "\(distribution)")
                XCTAssertFalse(policy.offersJITEnable, "\(distribution)")
                XCTAssertFalse(policy.mayNameSideloadingTools, "\(distribution)")
            }
        }
    }

    func testStoreInstallWithJITActuallyOnShowsStatusButNoTools() {
        // The owner attaching a debugger to a TestFlight build: JIT is real.
        let policy = JITUIPolicy(distribution: .testFlight, jitAcquired: true, isWXEnforced: true)
        XCTAssertTrue(policy.showsJITUI)
        XCTAssertFalse(policy.offersJITEnable)
        XCTAssertFalse(policy.mayNameSideloadingTools)
    }

    func testNonStoreInstallsKeepJITUI() {
        for distribution in [AppDistribution.simulator, .development, .sideloaded, .jailbroken] {
            let policy = JITUIPolicy(distribution: distribution, jitAcquired: false, isWXEnforced: false)
            XCTAssertTrue(policy.showsJITUI, "\(distribution)")
            XCTAssertTrue(policy.offersJITEnable, "\(distribution)")
            XCTAssertTrue(policy.mayNameSideloadingTools, "\(distribution)")
        }
    }

    func testEnableIsNotOfferedWhenItCannotWork() {
        XCTAssertFalse(JITUIPolicy(distribution: .sideloaded, jitAcquired: false, isWXEnforced: true).offersJITEnable)
        XCTAssertFalse(JITUIPolicy(distribution: .sideloaded, jitAcquired: true, isWXEnforced: false).offersJITEnable)
    }
}
