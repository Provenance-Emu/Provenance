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

    /// The stored value of `externalDisplayBezel` that leaves the choice to the game's system.
    /// It is the default, so a player who never chose gets it.
    public static let automaticBezelID = "auto"

    /// The TV *Automatic* shows when none lists the game's system.
    public static let automaticDefaultBezelID = "living-room-tv"

    /// What the rules decided for one game, and how they got there.
    public struct Resolution: Equatable, Sendable {
        public enum Outcome: Equatable, Sendable {
            case bezel(String)
            /// The player chose None, or pinned the game to none.
            case noneChosen
            /// *Automatic*, and the system has a screen of its own (a handheld).
            case noneForSystem
            /// *Automatic* or a chosen TV, and nothing in the catalogue fits.
            case noneAvailable
        }

        public let outcome: Outcome
        /// *Automatic* produced the answer: no usable pin, no game artwork, and the stored
        /// choice is `automaticBezelID`.
        public let isAutomatic: Bool

        public init(outcome: Outcome, isAutomatic: Bool) {
            self.outcome = outcome
            self.isAutomatic = isAutomatic
        }

        /// The TV to show, or `nil` for the picture alone.
        public var bezelID: String? {
            if case .bezel(let id) = outcome { return id }
            return nil
        }
    }

    /// The TV to show for a game. The first that applies:
    ///
    /// 1. the TV pinned to the game, which may be none;
    /// 2. artwork made for the game;
    /// 3. with *Automatic*: none for a system with a screen of its own, else a TV that lists
    ///    the game's system, else `automaticDefault`;
    /// 4. with a TV chosen and `matchesSystem`, a TV that lists the game's system;
    /// 5. the chosen TV.
    ///
    /// - Parameters:
    ///   - chosen: the stored choice (`noBezelID` for none, `automaticBezelID` for *Automatic*).
    ///   - matchesSystem: with a TV chosen, prefer the TV that lists the game's system.
    ///   - systemSuitsTV: the system was played on a TV or monitor (its screen type is CRT).
    ///   - candidates: every TV on the device, in catalogue order. Among TVs listing a system
    ///     the player's own win, then the first.
    ///   - pinned: the TV pinned to this game: `nil` for none pinned, `noBezelID` for no TV. A
    ///     pin whose TV is gone counts as no pin.
    ///   - gameArt: artwork for this game that is on the device, when the player wants game
    ///     artwork shown. It shows with no TV chosen too.
    public static func resolve(chosen: String,
                               matchesSystem: Bool,
                               systemID: String?,
                               systemSuitsTV: Bool,
                               candidates: [Candidate],
                               pinned: String? = nil,
                               gameArt: String? = nil,
                               automaticDefault: String = automaticDefaultBezelID) -> Resolution {
        let known = { (id: String) in candidates.contains { $0.id == id } }
        let listing = { () -> String? in
            guard let systemID else { return nil }
            let claims = candidates.filter { $0.preferredSystems.contains(systemID) }
            return (claims.first(where: \.isUserAdded) ?? claims.first)?.id
        }
        if let pinned {
            if pinned == noBezelID { return Resolution(outcome: .noneChosen, isAutomatic: false) }
            if known(pinned) { return Resolution(outcome: .bezel(pinned), isAutomatic: false) }
        }
        if let gameArt, known(gameArt) { return Resolution(outcome: .bezel(gameArt), isAutomatic: false) }
        if chosen == noBezelID { return Resolution(outcome: .noneChosen, isAutomatic: false) }
        if chosen == automaticBezelID {
            guard systemSuitsTV else { return Resolution(outcome: .noneForSystem, isAutomatic: true) }
            if let preferred = listing() { return Resolution(outcome: .bezel(preferred), isAutomatic: true) }
            return Resolution(outcome: known(automaticDefault) ? .bezel(automaticDefault) : .noneAvailable,
                              isAutomatic: true)
        }
        // The system's own screen replaces the chosen TV; it does not switch TVs on.
        guard known(chosen) else { return Resolution(outcome: .noneAvailable, isAutomatic: false) }
        if matchesSystem, let preferred = listing() {
            return Resolution(outcome: .bezel(preferred), isAutomatic: false)
        }
        return Resolution(outcome: .bezel(chosen), isAutomatic: false)
    }

    /// `resolve` for a system that suits a TV, reduced to the TV's id.
    public static func bezelID(chosen: String,
                               matchesSystem: Bool,
                               systemID: String?,
                               candidates: [Candidate],
                               pinned: String? = nil,
                               gameArt: String? = nil) -> String? {
        resolve(chosen: chosen, matchesSystem: matchesSystem, systemID: systemID, systemSuitsTV: true,
                candidates: candidates, pinned: pinned, gameArt: gameArt).bezelID
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
