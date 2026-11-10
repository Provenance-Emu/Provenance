import Foundation
import PVSystems
import SkinKitCore
import SkinKitManager

// MARK: - Session Skin Management

/// `SystemIdentifier` overloads of SkinKitManager's session-skin pass-throughs.
extension DeltaSkinManager {
    /// Set or clear the session skin for a system
    public func setSessionSkin(_ skinIdentifier: String?, for systemId: SystemIdentifier, orientation: SkinOrientation) {
        setSessionSkin(skinIdentifier, for: systemId.skinSystemID, orientation: orientation)
    }

    /// Set or clear the session skin for a specific game
    public func setSessionSkin(_ skinIdentifier: String?, for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) {
        setSessionSkin(skinIdentifier, for: systemId.skinSystemID, gameId: gameId, orientation: orientation)
    }

    /// Get the session skin identifier for a specific game
    public func sessionSkinIdentifier(for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) -> String? {
        sessionSkinIdentifier(for: systemId.skinSystemID, gameId: gameId, orientation: orientation)
    }

    /// Get the effective skin identifier for a game, checking game-specific session skins first,
    /// then system session skins, then game preferences, and finally system preferences
    public func effectiveGameSkinIdentifier(for systemId: SystemIdentifier, gameId: String, orientation: SkinOrientation) -> String? {
        effectiveGameSkinIdentifier(for: systemId.skinSystemID, gameId: gameId, orientation: orientation)
    }
}
