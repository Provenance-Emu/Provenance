import XCTest
import PVPrimitives
@testable import PVUIBase

@MainActor
final class DeltaSkinSelectionManagerTests: XCTestCase {
    private let testSystem: SystemIdentifier = .NES
    private let testGameId = "pvui-delta-skin-selection-manager-tests-game"
    /// Second key for the same game (pickers store games under `PVGame.id` or `md5Hash`).
    private let testGameAltId = "pvui-delta-skin-selection-manager-tests-game-md5"

    /// Restores preferences and session overrides touched by these tests.
    private func cleanupSelectionState() {
        let manager = DeltaSkinSelectionManager.shared
        for orientation in SkinOrientation.allCases {
            for gameId in [testGameId, testGameAltId] {
                manager.setSkin(nil, for: testSystem, gameId: gameId, orientation: orientation, scope: .session)
                manager.setSkin(nil, for: testSystem, gameId: gameId, orientation: orientation, scope: .game)
            }
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

    func testPrefersBuiltInWhenGamePreferenceIsToken() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        manager.setSkin(
            DeltaSkinSelectionManager.builtInSkinPreferenceToken,
            for: testSystem,
            gameId: testGameId,
            orientation: .portrait,
            scope: .game
        )
        XCTAssertTrue(manager.prefersBuiltInControllerSkin(for: testSystem, gameId: testGameId, orientation: .portrait))
    }

    func testPrefersBuiltInFalseWhenSessionOverridesWithRealSkin() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        manager.setSkin(
            DeltaSkinSelectionManager.builtInSkinPreferenceToken,
            for: testSystem,
            gameId: testGameId,
            orientation: .portrait,
            scope: .game
        )
        manager.setSkin("com.example.real-skin", for: testSystem, gameId: testGameId, orientation: .portrait, scope: .session)
        XCTAssertFalse(manager.prefersBuiltInControllerSkin(for: testSystem, gameId: testGameId, orientation: .portrait))
    }

    func testPrefersBuiltInFalseWhenNoToken() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        XCTAssertFalse(manager.prefersBuiltInControllerSkin(for: testSystem, gameId: testGameId, orientation: .portrait))
    }

    // MARK: - hasExplicitPackagedSkinSelection

    func testExplicitSelectionFalseWithoutAnySelection() {
        defer { cleanupSelectionState() }
        let gameIds = [testGameId, testGameAltId]
        XCTAssertFalse(DeltaSkinSelectionManager.shared.hasExplicitPackagedSkinSelection(for: testSystem, gameIds: gameIds))
    }

    func testExplicitSelectionTrueForGameSkinInEitherOrientationOrKey() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        // Landscape-only pick, stored under the second game key.
        manager.setSkin("com.example.gc-skin", for: testSystem, gameId: testGameAltId, orientation: .landscape, scope: .game)
        XCTAssertTrue(manager.hasExplicitPackagedSkinSelection(for: testSystem, gameIds: [testGameId, testGameAltId]))
        XCTAssertFalse(manager.hasExplicitPackagedSkinSelection(for: testSystem, gameIds: [testGameId]))
    }

    func testExplicitSelectionTrueForSystemSkin() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        manager.setSkin("com.example.gc-skin", for: testSystem, gameId: nil, orientation: .portrait, scope: .system)
        XCTAssertTrue(manager.hasExplicitPackagedSkinSelection(for: testSystem, gameIds: [testGameId]))
    }

    func testExplicitSelectionFalseForBuiltInToken() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        for orientation in SkinOrientation.allCases {
            manager.setSkin(DeltaSkinSelectionManager.builtInSkinPreferenceToken, for: testSystem, gameId: testGameId, orientation: orientation, scope: .game)
        }
        XCTAssertFalse(manager.hasExplicitPackagedSkinSelection(for: testSystem, gameIds: [testGameId]))
    }

    func testGameBuiltInTokenMasksSystemSkin() {
        let manager = DeltaSkinSelectionManager.shared
        let prefs = DeltaSkinPreferences.shared
        defer { cleanupSelectionState() }

        for orientation in SkinOrientation.allCases {
            prefs.setSelectedSkin("com.example.gc-skin", for: testSystem, orientation: orientation)
            manager.setSkin(DeltaSkinSelectionManager.builtInSkinPreferenceToken, for: testSystem, gameId: testGameId, orientation: orientation, scope: .game)
        }
        XCTAssertFalse(manager.hasExplicitPackagedSkinSelection(for: testSystem, gameIds: [testGameAltId, testGameId]))
    }

    func testCaseCompanionSessionSkinIsNotAnExplicitSelection() throws {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        let caseSkinId = try XCTUnwrap(CaseControllerDetector.knownLayouts.first?.knownSkinIdentifiers.first)
        // What CaseControllerSkinCoordinator writes when a case is detected.
        manager.setSkin(caseSkinId, for: testSystem, gameId: nil, orientation: .portrait, scope: .session)
        XCTAssertFalse(manager.hasExplicitPackagedSkinSelection(for: testSystem, gameIds: [testGameId]))
    }

    func testSystemPickAfterGameSessionPickBecomesEffective() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        manager.setSkin("com.example.game-session", for: testSystem, gameId: testGameId, orientation: .portrait, scope: .session)
        manager.setSkin("com.example.system-pick", for: testSystem, gameId: nil, orientation: .portrait, scope: .system)
        manager.setSkin(nil, for: testSystem, gameId: testGameId, orientation: .portrait, scope: .session)

        XCTAssertEqual(manager.effectiveSkinIdentifier(for: testSystem, gameId: nil, orientation: .portrait), "com.example.system-pick")
    }

    func testSystemPickClearsGameSessionOverride() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        manager.setSkin("com.example.game-session", for: testSystem, gameId: testGameId, orientation: .portrait, scope: .session)
        manager.setSkin("com.example.system-pick", for: testSystem, gameId: testGameId, orientation: .portrait, scope: .system)

        XCTAssertEqual(manager.effectiveSkinIdentifier(for: testSystem, gameId: testGameId, orientation: .portrait), "com.example.system-pick")
    }

    func testGamePickClearsItsGameSession() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        manager.setSkin("com.example.game-session", for: testSystem, gameId: testGameId, orientation: .landscape, scope: .session)
        manager.setSkin("com.example.game-pick", for: testSystem, gameId: testGameId, orientation: .landscape, scope: .game)

        XCTAssertEqual(manager.effectiveSkinIdentifier(for: testSystem, gameId: testGameId, orientation: .landscape), "com.example.game-pick")
    }

    func testSessionPickStillWinsWhilePresent() {
        let manager = DeltaSkinSelectionManager.shared
        defer { cleanupSelectionState() }

        manager.setSkin("com.example.game-pick", for: testSystem, gameId: testGameId, orientation: .portrait, scope: .game)
        manager.setSkin("com.example.session-pick", for: testSystem, gameId: testGameId, orientation: .portrait, scope: .session)

        XCTAssertEqual(manager.effectiveSkinIdentifier(for: testSystem, gameId: testGameId, orientation: .portrait), "com.example.session-pick")
    }
}
