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

        public init(id: String, preferredSystems: Set<String> = []) {
            self.id = id
            self.preferredSystems = preferredSystems
        }
    }

    /// The TV to show for a game, or `nil` for the picture alone.
    ///
    /// A TV has to be chosen for any TV to show: the system's own screen replaces the chosen
    /// one, it does not switch the feature on.
    ///
    /// - Parameters:
    ///   - chosen: the stored choice (`noBezelID` for none).
    ///   - matchesSystem: prefer the TV that lists the game's system, when one does.
    ///   - candidates: the catalogue, in its own order. The first TV listing a system wins.
    public static func bezelID(chosen: String,
                               matchesSystem: Bool,
                               systemID: String?,
                               candidates: [Candidate]) -> String? {
        guard chosen != noBezelID, candidates.contains(where: { $0.id == chosen }) else { return nil }
        if matchesSystem, let systemID,
           let preferred = candidates.first(where: { $0.preferredSystems.contains(systemID) }) {
            return preferred.id
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
