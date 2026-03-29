import XCTest
import PVPrimitives
@testable import PVUIBase

@MainActor
final class DeltaSkinSelectionManagerTests: XCTestCase {
    private let testSystem: SystemIdentifier = .NES
    private let testGameId = "pvui-delta-skin-selection-manager-tests-game"

    /// Restores preferences and session overrides touched by these tests.
    private func cleanupSelectionState() {
        let manager = DeltaSkinSelectionManager.shared
        for orientation in SkinOrientation.allCases {
            manager.setSkin(nil, for: testSystem, gameId: testGameId, orientation: orientation, scope: .session)
            manager.setSkin(nil, for: testSystem, gameId: testGameId, orientation: orientation, scope: .game)
            manager.setSkin(nil, for: testSystem, gameId: nil, orientation: orientation, scope: .system)
        }
    }

    func testGameScopedBuiltInTokenDoesNotFallThroughToSystemPreference() {
        let manager = DeltaSkinSelectionManager.shared
        let prefs = DeltaSkinPreferences.shared
        defer { cleanupSelectionState() }

        prefs.setSelectedSkin("fake-system-only-skin-id", for: testSystem, orientation: .portrait)
        manager.setSkin(
            DeltaSkinSelectionManager.builtInSkinPreferenceToken,
            for: testSystem,
            gameId: testGameId,
            orientation: .portrait,
            scope: .game
        )

        let effective = manager.effectiveGameSkinIdentifier(for: testSystem, gameId: testGameId, orientation: .portrait)
        XCTAssertNil(effective)
    }

    func testSessionBuiltInTokenDoesNotFallThroughToSystemPreference() {
        let manager = DeltaSkinSelectionManager.shared
        let prefs = DeltaSkinPreferences.shared
        defer { cleanupSelectionState() }

        prefs.setSelectedSkin("fake-system-only-skin-id", for: testSystem, orientation: .landscape)
        manager.setSkin(
            DeltaSkinSelectionManager.builtInSkinPreferenceToken,
            for: testSystem,
            gameId: testGameId,
            orientation: .landscape,
            scope: .session
        )

        let effective = manager.effectiveGameSkinIdentifier(for: testSystem, gameId: testGameId, orientation: .landscape)
        XCTAssertNil(effective)
    }
}
