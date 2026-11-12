//
//  HeldActionCombiner.swift
//  PVCoreBridge
//
//  One held action from several inputs, such as a touchpad click and a trigger that both fire.
//

import Foundation

/// Combines presses of the same `PointerAction` from several sources.
///
/// The action goes down when the first source presses it and up when the last one lets go,
/// so releasing one input never cuts off another that is still held.
public struct HeldActionCombiner<Source: Hashable & Sendable>: Sendable {
    private var holders: [PointerAction: Set<Source>] = [:]

    public init() {}

    /// Records one source's press or release. Returns the action's new state when it changes, otherwise nil.
    public mutating func set(_ action: PointerAction, isDown: Bool, from source: Source) -> Bool? {
        var sources = holders[action] ?? []
        let wasDown = !sources.isEmpty
        if isDown { sources.insert(source) } else { sources.remove(source) }
        holders[action] = sources.isEmpty ? nil : sources
        let isNowDown = !sources.isEmpty
        return isNowDown == wasDown ? nil : isNowDown
    }

    /// Lets go of everything `source` holds. Returns the actions that went up as a result.
    public mutating func releaseAll(from source: Source) -> [PointerAction] {
        let held = holders.filter { $0.value.contains(source) }.map(\.key)
        return held.filter { set($0, isDown: false, from: source) == false }
            .sorted { $0.rawValue < $1.rawValue }
    }
}
