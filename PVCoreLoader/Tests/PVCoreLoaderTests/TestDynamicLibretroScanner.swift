import XCTest
@testable import PVCoreLoader

/// Tests for PVDynamicLibretroCoreScanner and CoreLoader.mergeDiscoveredLibretroCores.
final class TestDynamicLibretroScanner: XCTestCase {

    // MARK: - Feature flag gate

    /// When the legacy direct UserDefaults key is explicitly `false`, merge must not run
    /// (even if PVRetroArch is absent and auto-scan would otherwise enable).
    func testMergeIsNoOpWhenFeatureFlagDisabled() {
        UserDefaults.standard.set(false, forKey: PVDynamicLibretroCoreScanner.featureFlagKey)
        defer { UserDefaults.standard.removeObject(forKey: PVDynamicLibretroCoreScanner.featureFlagKey) }

        let original = CoreLoader.shared.getCorePlists()
        let merged   = CoreLoader.mergeDiscoveredLibretroCores(into: original)

        XCTAssertEqual(merged.count, original.count,
            "mergeDiscoveredLibretroCores must be a no-op when the direct UserDefaults key is false")
    }

    /// When enabled, a second call to mergeDiscoveredLibretroCores must NOT add a
    /// duplicate "PVThinLibretro" parent (even if no dylibs are found on the simulator).
    func testMergeDoesNotDuplicateParentOnRepeatedCalls() {
        UserDefaults.standard.set(true, forKey: PVDynamicLibretroCoreScanner.featureFlagKey)
        defer { UserDefaults.standard.removeObject(forKey: PVDynamicLibretroCoreScanner.featureFlagKey) }

        let base      = CoreLoader.shared.getCorePlists()
        let firstPass = CoreLoader.mergeDiscoveredLibretroCores(into: base)
        let secondPass = CoreLoader.mergeDiscoveredLibretroCores(into: firstPass)

        // Count occurrences of the synthetic parent identifier in each pass.
        let thinID = "com.provenance.thinlibretro"
        let firstCount  = firstPass.filter { $0.identifier == thinID }.count
        let secondCount = secondPass.filter { $0.identifier == thinID }.count

        // There should be at most one synthetic parent after each merge.
        XCTAssertLessThanOrEqual(firstCount, 1,
            "At most one 'Thin Libretro' parent after the first merge")
        XCTAssertEqual(firstCount, secondCount,
            "A second merge must not add another 'Thin Libretro' parent")
    }

    /// mergeDiscoveredLibretroCores must never remove existing (static) plist entries.
    func testMergePreservesExistingEntries() {
        UserDefaults.standard.set(true, forKey: PVDynamicLibretroCoreScanner.featureFlagKey)
        defer { UserDefaults.standard.removeObject(forKey: PVDynamicLibretroCoreScanner.featureFlagKey) }

        let base   = CoreLoader.shared.getCorePlists()
        let merged = CoreLoader.mergeDiscoveredLibretroCores(into: base)

        // Every identifier that was present before the merge must still be present.
        let mergedIDs = Set(merged.map { $0.identifier })
        for plist in base {
            XCTAssertTrue(mergedIDs.contains(plist.identifier),
                "Static core '\(plist.identifier)' was lost after merge")
        }
    }

    // MARK: - isFeatureEnabled

    func testFeatureFlagDefaultsToFalse() {
        UserDefaults.standard.removeObject(forKey: PVDynamicLibretroCoreScanner.featureFlagKey)
        XCTAssertFalse(PVDynamicLibretroCoreScanner.isFeatureEnabled,
            "Feature flag must default to false")
    }

    func testFeatureFlagCanBeEnabledViaUserDefaults() {
        UserDefaults.standard.set(true, forKey: PVDynamicLibretroCoreScanner.featureFlagKey)
        defer { UserDefaults.standard.removeObject(forKey: PVDynamicLibretroCoreScanner.featureFlagKey) }
        XCTAssertTrue(PVDynamicLibretroCoreScanner.isFeatureEnabled,
            "Feature flag must reflect direct UserDefaults boolean value")
    }

    func testFeatureFlagCanBeEnabledViaDebugOverrides() {
        // Simulate the PVFeatureFlags debug-override UI path (stored as a dict).
        let key = PVDynamicLibretroCoreScanner.featureFlagKey
        UserDefaults.standard.set([key: true], forKey: "PVFeatureFlagsDebugOverrides")
        defer { UserDefaults.standard.removeObject(forKey: "PVFeatureFlagsDebugOverrides") }
        XCTAssertTrue(PVDynamicLibretroCoreScanner.isFeatureEnabled,
            "Feature flag must be enabled via PVFeatureFlagsDebugOverrides dict (feature flag UI path)")
    }

    func testDebugOverrideCanDisableFlag() {
        // Direct key set to true, but debug override says false — override wins.
        let key = PVDynamicLibretroCoreScanner.featureFlagKey
        UserDefaults.standard.set(true, forKey: key)
        UserDefaults.standard.set([key: false], forKey: "PVFeatureFlagsDebugOverrides")
        defer {
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: "PVFeatureFlagsDebugOverrides")
        }
        XCTAssertFalse(PVDynamicLibretroCoreScanner.isFeatureEnabled,
            "Debug override (false) must take priority over the direct UserDefaults key")
    }

    // MARK: - DiscoveredLibretroCore.syntheticIdentifier

    func testHasStaticLibretroSubcoreRegistrationFalseForEmptyPlists() {
        XCTAssertFalse(CoreLoader.hasStaticLibretroSubcoreRegistration(in: []))
    }

    /// With no legacy UserDefaults override, iOS should still enable the merge pipeline when
    /// no plist registers libretro sub-cores (PVRetroArch not embedded), via PVFeatureFlags + auto fallback.
    func testDynamicScanMergeAutoEnablesWhenNoStaticLibretroEntries() {
        UserDefaults.standard.removeObject(forKey: PVDynamicLibretroCoreScanner.featureFlagKey)
        let on = PVDynamicLibretroCoreScanner.isDynamicScanEnabledForMerge(plists: [])
        XCTAssertTrue(on, "Expected auto-enable when plists lack static libretro sub-cores and no UserDefaults override")
    }

    func testSyntheticIdentifierSlugifiesName() {
        // DiscoveredLibretroCore is constructed via the scanner's probe path, but its
        // memberwise init is accessible with @testable import. Verify the computed
        // syntheticIdentifier property directly against known inputs.
        let core = DiscoveredLibretroCore(
            executablePath: URL(fileURLWithPath: "/tmp/fake.dylib"),
            libraryName: "mGBA / Game Boy Advance",
            libraryVersion: "1.0",
            validExtensions: ["gba"],
            needFullPath: false
        )
        XCTAssertEqual(core.syntheticIdentifier,
                       "mgba___game_boy_advance.libretro.framework",
                       "syntheticIdentifier must lower-case and replace spaces/slashes with underscores")
    }
}
