//
//  LayoutEditorRouting.swift
//  PVUIBase
//
//  Which touch-control editor the emulator opens, how it is reached from the game
//  screen, and which controller the pause menu's "Remap Controller" edits.
//

import Foundation

/// The layout editor that applies to the controls on screen.
///
/// Both editors answer `.overlayEditLayoutRequested`; each one only acts when it is
/// the one mounted, so the pause menu and the game-screen gesture post the same request.
enum LayoutEditorKind: Equatable, Sendable {
    /// The programmatic overlay's live editor (`OverlayEditorView`).
    case overlay
    /// The packaged DeltaSkin button-offset editor (`DeltaSkinEditModeOverlay`).
    case deltaSkin

    /// - Parameters:
    ///   - skinLayerEnabled: the skin layer (packaged skin or overlay) is installed.
    ///   - overlayMounted: the programmatic overlay is on screen.
    ///   - skinLoaded: the skin layer reported its controls on screen.
    /// - Returns: `nil` when no editable controls are on screen.
    ///
    /// The overlay wins: it stands in for a selected packaged skin that does not support
    /// the current orientation, so that skin is not what the player sees.
    static func resolve(skinLayerEnabled: Bool, overlayMounted: Bool, skinLoaded: Bool) -> LayoutEditorKind? {
        guard skinLayerEnabled else { return nil }
        if overlayMounted { return .overlay }
        return skinLoaded ? .deltaSkin : nil
    }
}

/// The game-screen gesture that opens the layout editor: a three-finger hold, long
/// enough that normal play (even pressing three buttons at once) rarely completes it.
enum LayoutEditorGesture {
    static let touchCount = 3
    static let minimumPressDuration: TimeInterval = 1.5
}

/// Picks the controller the pause menu's "Remap Controller" opens.
enum RemapControllerResolver {
    /// Player 1's controller, else the lowest-numbered assigned player's, else the first
    /// connected one. Only controllers `isRemappable` accepts are considered.
    static func controller<Controller>(assigned: [Int: Controller],
                                       connected: [Controller],
                                       isRemappable: (Controller) -> Bool) -> Controller? {
        for player in assigned.keys.sorted() {
            if let candidate = assigned[player], isRemappable(candidate) { return candidate }
        }
        return connected.first(where: isRemappable)
    }
}
