//
//  GameplayBezelPlacement.swift
//  PVSettings
//
//  Whether the device may draw a TV around the game.
//

import Foundation

/// Where a TV may surround the game picture on the device itself.
///
/// Pure: every input is passed in, so the rules are testable without a device.
public enum GameplayBezelPlacement {

    /// What supplies the on-screen controls.
    public enum Controls: Equatable, Sendable {
        /// The generated touch controls: buttons only, which can float over a TV.
        case generated
        /// A real or built-in skin, which frames the picture itself.
        case skin
        /// A hardware controller hid the on-screen controls.
        case hiddenByController
        /// Nothing on screen and no controller. (Never name a case `none`: passed as an
        /// optional it silently becomes `Optional.none`.)
        case bare
    }

    public struct Inputs: Equatable, Sendable {
        public var isAppleTV: Bool
        /// The window is wider than it is tall.
        public var isLandscape: Bool
        public var controls: Controls
        /// One screen, filters apply, the host GPU view draws the game and the presenter
        /// presents the core's frames.
        public var layoutSupportsTV: Bool
        /// `ExternalDisplayBezelRules.Resolution.isAutomatic` of the TV that would show.
        public var choiceIsAutomatic: Bool
        /// The layout editor is open: buttons are placed against the bare picture.
        public var editingLayout: Bool
        /// The GPU could not draw a TV this game. Trying again risks a GPU hang, after which
        /// the system refuses every frame the app draws.
        public var droppedForSession: Bool

        public init(isAppleTV: Bool, isLandscape: Bool, controls: Controls, layoutSupportsTV: Bool,
                    choiceIsAutomatic: Bool, editingLayout: Bool = false, droppedForSession: Bool = false) {
            self.isAppleTV = isAppleTV
            self.isLandscape = isLandscape
            self.controls = controls
            self.layoutSupportsTV = layoutSupportsTV
            self.choiceIsAutomatic = choiceIsAutomatic
            self.editingLayout = editingLayout
            self.droppedForSession = droppedForSession
        }
    }

    /// Whether the TV the rules resolved may be drawn.
    ///
    /// Apple TV always; elsewhere in landscape unless a skin is on screen. In portrait only a
    /// TV the player chose, and only when a controller hid the on-screen controls.
    public static func showsTV(_ inputs: Inputs) -> Bool {
        guard inputs.layoutSupportsTV, !inputs.editingLayout, !inputs.droppedForSession else { return false }
        if inputs.isAppleTV { return true }
        guard inputs.controls != .skin else { return false }
        if inputs.isLandscape { return true }
        return inputs.controls == .hiddenByController && !inputs.choiceIsAutomatic
    }

    /// Whether the pause menu offers the TV switcher: a TV the player chose could show now.
    public static func offersSwitcher(_ inputs: Inputs) -> Bool {
        var explicit = inputs
        explicit.choiceIsAutomatic = false
        return showsTV(explicit)
    }
}
