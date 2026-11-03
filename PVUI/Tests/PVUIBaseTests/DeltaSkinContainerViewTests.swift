import Testing
import UIKit
import PVEmulatorCore
import PVLibrary
import SkinKitManager
import PVSystems
@testable import PVUIBase

/// Supplies identity without an emulator bridge for this view-hierarchy-only fixture.
private final class SkinContainerCore: PVEmulatorCore {
    override var systemIdentifier: String? {
        get { nil }
        set { }
    }
}

@Suite("Live skin container")
@MainActor
struct DeltaSkinContainerViewTests {
    @Test("A system pick supersedes legacy hash preferences and survives relaunch")
    func systemPickReplacesLegacyGameKeys() throws {
        let suite = "AzaharSkinSelection-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = DeltaSkinPreferences(defaults: defaults)
        let manager = DeltaSkinSelectionManager(preferences: preferences)
        manager.setSkin("old", for: ._3DS, gameId: "rom-md5", orientation: .portrait, scope: .game)
        manager.setSkin("last-picked", for: ._3DS, gameId: "game-uuid", otherGameKeys: ["rom-md5", "rom-crc"],
                        orientation: .portrait, scope: .system)
        let relaunched = DeltaSkinSelectionManager(preferences: DeltaSkinPreferences(defaults: defaults))
        #expect(relaunched.effectiveSkinIdentifier(for: ._3DS, gameIds: ["game-uuid", "rom-md5", "rom-crc"],
                                                  orientation: .portrait) == "last-picked")

        manager.setSkin(DeltaSkinSelectionManager.builtInSkinPreferenceToken, for: ._3DS,
                        gameId: "game-uuid", otherGameKeys: ["rom-md5", "rom-crc"], orientation: .portrait, scope: .system)
        let builtInRelaunch = DeltaSkinSelectionManager(preferences: DeltaSkinPreferences(defaults: defaults))
        #expect(builtInRelaunch.prefersBuiltInControllerSkin(for: ._3DS, gameIds: ["game-uuid", "rom-md5", "rom-crc"],
                                                            orientation: .portrait))
    }

    @Test("Changing skins keeps the mounted hosting view and native render sibling")
    func swapKeepsRenderHierarchy() throws {
        let core = SkinContainerCore()
        let container = DeltaSkinContainerView.create(
            game: PVGame(), core: core, inputHandler: DeltaSkinInputHandler(emulatorCore: core),
            preselectedSkinIdentifier: "first", onSkinLoaded: {}, onRefreshRequested: {})
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let renderView = UIView(frame: host.bounds)
        host.addSubview(renderView)
        host.addSubview(container)
        let hostingView = try #require(container.subviews.first)

        container.updateSkinIdentifier("second")
        #expect(container.skinIdentifier == "second")
        #expect(container.subviews.first === hostingView)
        #expect(renderView.superview === host)
        #expect(host.subviews.first === renderView)

        // The view may have loaded another orientation since the previous request.
        container.updateSkinIdentifier("second")
        #expect(container.skinRequestRevision == 2)
        #expect(container.subviews.first === hostingView)

        container.updateSkinIdentifier(nil)
        #expect(container.skinIdentifier == DeltaSkinSelectionManager.builtInSkinPreferenceToken)
        #expect(container.subviews.first === hostingView)
        #expect(renderView.superview === host)
    }
}
