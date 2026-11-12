//
//  ExternalDisplayBezelRules.swift
//  PVSettings
//
//  Which TV surrounds the picture on an external display, and which filter runs inside it.
//

import Foundation

/// The rules behind the TV setting of an external display.
///
/// Pure: the catalogue of TVs and every setting are passed in, so the rules are testable
/// without a display, a catalogue file or a shader library.
public enum ExternalDisplayBezelRules {

    /// The stored value of `externalDisplayBezel` that means no TV.
    public static let noBezelID = ""

    /// What the rules need to know about one TV.
    public struct Candidate: Equatable, Sendable {
        public let id: String
        /// System identifiers this TV is the natural screen for.
        public let preferredSystems: Set<String>
        /// The player added this one (imported or saved). Their TVs come before the built-in
        /// ones when several list a system.
        public let isUserAdded: Bool

        public init(id: String, preferredSystems: Set<String> = [], isUserAdded: Bool = false) {
            self.id = id
            self.preferredSystems = preferredSystems
            self.isUserAdded = isUserAdded
        }
    }

    /// The TV to show for a game, or `nil` for the picture alone. The first that applies:
    ///
    /// 1. the TV pinned to the game, which may be none;
    /// 2. artwork made for the game;
    /// 3. with a TV chosen and `matchesSystem`, a TV that lists the game's system;
    /// 4. the chosen TV.
    ///
    /// - Parameters:
    ///   - chosen: the stored choice (`noBezelID` for none).
    ///   - matchesSystem: prefer the TV that lists the game's system, when one does.
    ///   - candidates: every TV on the device, in catalogue order. Among TVs listing a system
    ///     the player's own win, then the first.
    ///   - pinned: the TV pinned to this game: `nil` for automatic, `noBezelID` for none. A pin
    ///     whose TV is gone counts as no pin.
    ///   - gameArt: artwork for this game that is on the device, when the player wants game
    ///     artwork shown. It shows with no TV chosen too.
    public static func bezelID(chosen: String,
                               matchesSystem: Bool,
                               systemID: String?,
                               candidates: [Candidate],
                               pinned: String? = nil,
                               gameArt: String? = nil) -> String? {
        let known = { (id: String) in candidates.contains { $0.id == id } }
        if let pinned {
            if pinned == noBezelID { return nil }
            if known(pinned) { return pinned }
        }
        if let gameArt, known(gameArt) { return gameArt }
        // The system's own screen replaces the chosen TV; it does not switch TVs on.
        guard chosen != noBezelID, known(chosen) else { return nil }
        if matchesSystem, let systemID {
            let listing = candidates.filter { $0.preferredSystems.contains(systemID) }
            if let preferred = listing.first(where: \.isUserAdded) ?? listing.first {
                return preferred.id
            }
        }
        return chosen
    }

    /// What draws the tube look inside a TV's glass.
    public enum TubeFilter: Equatable, Sendable {
        /// The look the TV suggests.
        case tvOwn
        /// The filter the user picked for the external display.
        case user
        /// Clean pixels behind the glass.
        case off
    }

    /// - Parameters:
    ///   - hasUserSelection: the external display has a filter selection of its own.
    ///   - userSelectionIsOff: that selection resolves to no filter.
    ///   - userSelectionIsBezel: that selection is a filter that draws a frame of its own,
    ///     which cannot go inside another.
    public static func tubeFilter(hasUserSelection: Bool,
                                  userSelectionIsOff: Bool,
                                  userSelectionIsBezel: Bool) -> TubeFilter {
        guard hasUserSelection else { return .tvOwn }
        return userSelectionIsOff || userSelectionIsBezel ? .off : .user
    }
}
