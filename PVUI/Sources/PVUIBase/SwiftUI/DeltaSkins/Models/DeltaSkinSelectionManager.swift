import Foundation
import Combine
import SwiftUI
import PVLogging

/// Centralized manager for all skin selection logic
/// Handles session, game, and system preferences in one place
public final class DeltaSkinSelectionManager: ObservableObject {
    /// Shared singleton instance
    public static let shared = DeltaSkinSelectionManager()

    /// Notification name for when skin selection changes
    public static let selectionChangedNotification = NSNotification.Name("DeltaSkinSelectionChanged")

    // MARK: - Private Storage

    /// Session-specific skin selections (temporary, cleared on app restart)
    /// Structure: [systemId.rawValue: [orientation.rawValue: skinIdentifier]]
    /// For game-specific: ["systemId_gameId": [orientation.rawValue: skinIdentifier]]
    private var sessionSkins: [String: [String: String]] = [:]

    /// Persistent preferences (stored in UserDefaults via DeltaSkinPreferences)
    private let preferences = DeltaSkinPreferences.shared

    /// Queue for thread-safe operations
    private let queue = DispatchQueue(label: "com.provenance.deltaskin.selection-manager")

    // MARK: - Initialization

    private init() {
        ILOG("skins: Initializing DeltaSkinSelectionManager")
    }

    // MARK: - Public API: Setting Skins

    /// Set a skin for a specific scope
    /// - Parameters:
    ///   - skinIdentifier: The skin identifier to set (nil to clear)
    ///   - systemId: The system identifier
    ///   - gameId: Optional game identifier
    ///   - orientation: The orientation (portrait or landscape)
    ///   - scope: The scope (session, game, or system)
    /// - Note: When setting Game or System scope, session skin is ALWAYS also set for immediate application
    @MainActor
    public func setSkin(
        _ skinIdentifier: String?,
        for systemId: SystemIdentifier,
        gameId: String? = nil,
        orientation: SkinOrientation,
        scope: SkinScope
    ) {
        queue.sync {
            switch scope {
            case .session:
                // Session scope: Only set session skin (temporary)
                setSessionSkin(skinIdentifier, for: systemId, gameId: gameId, orientation: orientation)

            case .game:
                guard let gameId = gameId else {
                    ELOG("skins: Cannot set game scope without gameId")
                    return
                }
                // Game scope: Set preference AND session skin (for immediate application)
                preferences.setSelectedSkin(skinIdentifier, for: gameId, orientation: orientation)
                setSessionSkin(skinIdentifier, for: systemId, gameId: gameId, orientation: orientation)
                ILOG("skins: Set game preference + session skin: \(skinIdentifier ?? "nil") for game \(gameId)")

            case .system:
                // System scope: Set preference AND session skin (for immediate application)
                preferences.setSelectedSkin(skinIdentifier, for: systemId, orientation: orientation)
                setSessionSkin(skinIdentifier, for: systemId, gameId: gameId, orientation: orientation)
                ILOG("skins: Set system preference + session skin: \(skinIdentifier ?? "nil") for system \(systemId.rawValue)")
            }
        }

        // Post notification for view updates
        NotificationCenter.default.post(
            name: DeltaSkinSelectionManager.selectionChangedNotification,
            object: nil,
            userInfo: [
                "skinIdentifier": skinIdentifier ?? NSNull(),
                "systemId": systemId.rawValue,
                "gameId": gameId ?? NSNull(),
                "orientation": orientation.rawValue,
                "scope": scope.rawValue
            ]
        )
    }

    // MARK: - Public API: Getting Effective Skin

    /// Get the effective skin identifier for a system/game combination
    /// Priority order: Session (game-specific) > Session (system) > Game preference > System preference
    /// - Parameters:
    ///   - systemId: The system identifier
    ///   - gameId: Optional game identifier
    ///   - orientation: The orientation
    /// - Returns: The effective skin identifier, or nil if none set
    public func effectiveSkinIdentifier(
        for systemId: SystemIdentifier,
        gameId: String? = nil,
        orientation: SkinOrientation
    ) -> String? {
        return queue.sync {
            // Priority 1: Game-specific session skin
            if let gameId = gameId {
                if let gameSessionSkin = getSessionSkin(for: systemId, gameId: gameId, orientation: orientation) {
                    return gameSessionSkin
                }
            }

            // Priority 2: System-level session skin
            if let systemSessionSkin = getSessionSkin(for: systemId, gameId: nil, orientation: orientation) {
                return systemSessionSkin
            }

            // Priority 3: Game preference
            if let gameId = gameId {
                if let gamePref = preferences.selectedSkinIdentifier(for: gameId, orientation: orientation) {
                    return gamePref
                }
            }

            // Priority 4: System preference
            return preferences.selectedSkinIdentifier(for: systemId, orientation: orientation)
        }
    }

    /// Get the effective skin identifier for a game (convenience method)
    public func effectiveGameSkinIdentifier(
        for systemId: SystemIdentifier,
        gameId: String,
        orientation: SkinOrientation
    ) -> String? {
        return effectiveSkinIdentifier(for: systemId, gameId: gameId, orientation: orientation)
    }

    // MARK: - Private: Session Skin Management

    private func setSessionSkin(
        _ skinIdentifier: String?,
        for systemId: SystemIdentifier,
        gameId: String?,
        orientation: SkinOrientation
    ) {
        let key: String
        if let gameId = gameId {
            key = "\(systemId.rawValue)_\(gameId)"
        } else {
            key = systemId.rawValue
        }

        if sessionSkins[key] == nil {
            sessionSkins[key] = [:]
        }

        if let skinIdentifier = skinIdentifier {
            sessionSkins[key]?[orientation.rawValue] = skinIdentifier
            ILOG("skins: Set session skin \(skinIdentifier) for key \(key), orientation \(orientation.rawValue)")
        } else {
            sessionSkins[key]?[orientation.rawValue] = nil

            // Clean up empty entries
            if sessionSkins[key]?.isEmpty ?? true {
                sessionSkins.removeValue(forKey: key)
            }
            ILOG("skins: Cleared session skin for key \(key), orientation \(orientation.rawValue)")
        }
    }

    private func getSessionSkin(
        for systemId: SystemIdentifier,
        gameId: String?,
        orientation: SkinOrientation
    ) -> String? {
        let key: String
        if let gameId = gameId {
            key = "\(systemId.rawValue)_\(gameId)"
        } else {
            key = systemId.rawValue
        }

        return sessionSkins[key]?[orientation.rawValue]
    }

    // MARK: - Public: Direct Preference Access (for compatibility)

    /// Get game preference directly (bypasses session)
    public func gamePreference(for gameId: String, orientation: SkinOrientation) -> String? {
        return preferences.selectedSkinIdentifier(for: gameId, orientation: orientation)
    }

    /// Get system preference directly (bypasses session)
    public func systemPreference(for systemId: SystemIdentifier, orientation: SkinOrientation) -> String? {
        return preferences.selectedSkinIdentifier(for: systemId, orientation: orientation)
    }
}

/// Scope for skin selection
public enum SkinScope: String, CaseIterable, Identifiable {
    case session = "Session"
    case game = "Game"
    case system = "System"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .session: return "Apply for this session only"
        case .game: return "Save as default for this game"
        case .system: return "Save as default for all games on this system"
        }
    }
}
