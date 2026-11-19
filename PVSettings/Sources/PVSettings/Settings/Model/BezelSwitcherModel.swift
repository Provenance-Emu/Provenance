//
//  BezelSwitcherModel.swift
//  PVSettings
//
//  The pause menu's TV switcher: what it lists, how it steps and what Keep saves.
//

import Foundation

/// The state of the strip that previews TVs over the paused game.
///
/// Pure: the catalogue and the saved choices are passed in, and `commit` says what to save
/// instead of saving it. Stepping only moves the selection; nothing is stored until Keep.
public struct BezelSwitcherModel: Equatable, Sendable {

    public enum Group: Int, Sendable, CaseIterable {
        /// Off and Automatic.
        case basics
        case builtIn
        case shaderPresets
        /// Bezels the player imported or downloaded.
        case yours
        /// The way into the full library.
        case more
    }

    public struct Item: Equatable, Sendable, Identifiable {
        /// A TV's id, `ExternalDisplayBezelRules.noBezelID` (Off), `automaticBezelID`, or `moreID`.
        public let id: String
        public let group: Group
    }

    /// The id of the last item, which opens the library and is not a choice.
    public static let moreID = "more"

    public private(set) var items: [Item]
    public private(set) var index: Int
    /// Keep saves the choice for the running game alone.
    public var thisGameOnly: Bool
    public var lightsRoom: Bool

    /// - Parameters:
    ///   - current: the choice in effect: the game's pin if it has one, else the saved choice.
    ///     One that is not in the list opens on Automatic.
    ///   - gameHasPin: the running game has a TV pinned, so the strip opens on "this game only".
    public init(builtIn: [String], shaderPresets: [String], yours: [String],
                current: String, gameHasPin: Bool, lightsRoom: Bool) {
        let rules = ExternalDisplayBezelRules.self
        items = [Item(id: rules.noBezelID, group: .basics), Item(id: rules.automaticBezelID, group: .basics)]
            + builtIn.map { Item(id: $0, group: .builtIn) }
            + shaderPresets.map { Item(id: $0, group: .shaderPresets) }
            + yours.map { Item(id: $0, group: .yours) }
            + [Item(id: Self.moreID, group: .more)]
        index = items.firstIndex { $0.id == current && $0.group != .more }
            ?? items.firstIndex { $0.id == rules.automaticBezelID } ?? 0
        thisGameOnly = gameHasPin
        self.lightsRoom = lightsRoom
    }

    public var selection: Item { items[index] }

    /// Moves the selection by `delta` items, stopping at either end.
    public mutating func step(_ delta: Int) {
        index = min(max(index + delta, 0), items.count - 1)
    }

    /// Moves to the first item of the group before (`delta < 0`) or after the selection's,
    /// passing over groups with nothing in them. Stays put at either end.
    public mutating func jumpGroup(_ delta: Int) {
        guard delta != 0 else { return }
        let current = selection.group.rawValue
        let groups = Set(items.map(\.group.rawValue))
        let target = delta > 0 ? groups.filter { $0 > current }.min() : groups.filter { $0 < current }.max()
        guard let target, let first = items.firstIndex(where: { $0.group.rawValue == target }) else { return }
        index = first
    }

    /// Selects the item with `id`; an id that is not listed changes nothing.
    public mutating func select(id: String) {
        guard let found = items.firstIndex(where: { $0.id == id }) else { return }
        index = found
    }

    /// What to do with the running game's pin.
    public enum PinChange: Equatable, Sendable {
        case unchanged
        /// Pin this value (`noBezelID` pins no TV).
        case set(String)
        case remove
    }

    /// What Keep saves.
    public struct Commit: Equatable, Sendable {
        /// The new saved choice for every game; `nil` leaves it alone.
        public let chosen: String?
        public let pin: PinChange
        public let lightsRoom: Bool

        public init(chosen: String?, pin: PinChange, lightsRoom: Bool) {
            self.chosen = chosen
            self.pin = pin
            self.lightsRoom = lightsRoom
        }
    }

    /// What Keep saves for the selection, or `nil` when the selection is More.
    ///
    /// For every game the choice is saved and the game's pin dropped, since a pin would keep
    /// hiding it. For this game alone the choice is pinned; Automatic there means no pin.
    public func commit(gameHasPin: Bool) -> Commit? {
        let item = selection
        guard item.group != .more else { return nil }
        guard thisGameOnly else {
            return Commit(chosen: item.id, pin: gameHasPin ? .remove : .unchanged, lightsRoom: lightsRoom)
        }
        let pin: PinChange = item.id == ExternalDisplayBezelRules.automaticBezelID ? .remove : .set(item.id)
        return Commit(chosen: nil, pin: pin, lightsRoom: lightsRoom)
    }
}
