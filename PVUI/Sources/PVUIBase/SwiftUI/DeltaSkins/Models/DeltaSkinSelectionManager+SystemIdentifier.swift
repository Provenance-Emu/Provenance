import Foundation
import PVPrimitives
import SkinKitManager

/// `SystemIdentifier` overloads of SkinKitManager's selection API, which keys systems by `SkinSystemID`
/// (the same raw value, so stored picks carry over).
public extension DeltaSkinSelectionManager {
    @MainActor
    func setSkin(
        _ skinIdentifier: String?,
        for systemId: SystemIdentifier,
        gameId: String? = nil,
        otherGameKeys: [String] = [],
        orientation: SkinOrientation,
        scope: SkinScope
    ) {
        setSkin(skinIdentifier, for: systemId.skinSystemID, gameId: gameId, otherGameKeys: otherGameKeys,
                orientation: orientation, scope: scope)
    }

    func effectiveSkinIdentifier(for systemId: SystemIdentifier, gameId: String? = nil, orientation: SkinOrientation) -> String? {
        effectiveSkinIdentifier(for: systemId.skinSystemID, gameId: gameId, orientation: orientation)
    }

    func effectiveSkinIdentifier(for systemId: SystemIdentifier, gameIds: [String], orientation: SkinOrientation) -> String? {
        effectiveSkinIdentifier(for: systemId.skinSystemID, gameIds: gameIds, orientation: orientation)
    }

    func effectiveGameSkinIdentifier(for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) -> String? {
        effectiveGameSkinIdentifier(for: systemId.skinSystemID, gameId: gameId, orientation: orientation)
    }

    func prefersBuiltInControllerSkin(for systemId: SystemIdentifier, gameIds: [String], orientation: SkinOrientation) -> Bool {
        prefersBuiltInControllerSkin(for: systemId.skinSystemID, gameIds: gameIds, orientation: orientation)
    }

    func prefersBuiltInControllerSkin(for systemId: SystemIdentifier, gameId: String?, orientation: SkinOrientation) -> Bool {
        prefersBuiltInControllerSkin(for: systemId.skinSystemID, gameId: gameId, orientation: orientation)
    }

    func hasExplicitPackagedSkinSelection(for systemId: SystemIdentifier, gameIds: [String]) -> Bool {
        hasExplicitPackagedSkinSelection(for: systemId.skinSystemID, gameIds: gameIds)
    }
}

public extension DeltaSkinPreferences {
    func effectiveSkinIdentifier(for gameId: String, system: SystemIdentifier, orientation: SkinOrientation = .portrait) -> String? {
        effectiveSkinIdentifier(for: gameId, system: system.skinSystemID, orientation: orientation)
    }
}
