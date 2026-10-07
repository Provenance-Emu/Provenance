//
//  HardwareSwitchLatch.swift
//  PVUIBase
//

import Foundation
import PVCoreBridge

/// How long a console switch / momentary button is held down before release.
public enum HardwareSwitchTiming {
    /// Press-to-release delay. Level-sampled cores (Stella, thin libretro) read the
    /// pad each frame, so the core must run at least one frame inside this window.
    public static let pressDuration: TimeInterval = 0.05
    /// Press-to-release delay for the arcade coin slot, which needs longer to register.
    public static let coinPressDuration: TimeInterval = 0.15
    /// How long the pause menu keeps a paused core running so it samples a press.
    /// Longer than `pressDuration` to cover wake-up latency plus a few frames.
    public static let pausedMenuSampleWindow: TimeInterval = 0.25
}

/// Spelling variants skins use for the colour / black-and-white TV switch.
public enum HardwareSwitchTokens {
    private static let colorTokens: Set<String> = ["color", "clr", "colour"]
    private static let blackAndWhiteTokens: Set<String> = ["colorbw", "bw", "blackwhite", "b&w"]

    /// Maps a position-specific TV type token to the canonical button id:
    /// `color` for the colour position, `colorbw` for black and white.
    /// Returns `nil` for anything else, including the position-less `tvtype`,
    /// which only `HardwareSwitchLatch` can resolve.
    public static func canonicalTVType(_ token: String) -> String? {
        let s = token.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if colorTokens.contains(s) { return "color" }
        if blackAndWhiteTokens.contains(s) { return "colorbw" }
        return nil
    }

    /// Position-less token skins use for each switch, keyed by descriptor id.
    /// Manic skins declare one input id per switch rather than one per position.
    fileprivate static let singleTokenAliases: [String: Set<String>] = [
        "left_diff": ["leftdifficulty", "leftdiff"],
        "right_diff": ["rightdifficulty", "rightdiff"],
        "color_bw": ["tvtype"]
    ]
}

/// Remembers the position of each two-position console switch so a skin that
/// has only one input id per switch (Manic `tvType`, `leftDifficulty`...) can
/// still tell the core which position was chosen.
///
/// - A press of a position-less token flips the latched state and emits the id
///   of the new position; the matching release repeats that id.
/// - A press of an explicit position id (`leftdiffa`, `color`...) passes through
///   unchanged and records that position, so mixed skins stay in step.
/// - Press-to-toggle switches (both positions share one id) and every other
///   button pass through untouched.
public struct HardwareSwitchLatch {
    private struct Entry {
        let descriptor: HardwareSwitchDescriptor
        var isOn: Bool
    }

    private var entries: [Entry]
    /// Id emitted by the in-flight press of each position-less token.
    private var pending: [String: String] = [:]

    public init(descriptors: [HardwareSwitchDescriptor]) {
        entries = descriptors.filter { !$0.isPressToToggle }
            .map { Entry(descriptor: $0, isOn: $0.defaultState) }
    }

    /// Returns the button id to forward, or `nil` when the event must be dropped.
    public mutating func resolve(_ token: String, isPressed: Bool) -> String? {
        let key = token.lowercased()

        if let index = entries.firstIndex(where: { Self.isSingleToken(key, for: $0.descriptor) }) {
            if isPressed {
                entries[index].isOn.toggle()
                let descriptor = entries[index].descriptor
                let emitted = entries[index].isOn ? descriptor.positions.on.buttonId : descriptor.positions.off.buttonId
                pending[key] = emitted
                return emitted
            }
            return pending.removeValue(forKey: key)
        }

        if isPressed, let index = entries.firstIndex(where: { Self.position(of: key, in: $0.descriptor) != nil }),
           let isOn = Self.position(of: key, in: entries[index].descriptor) {
            entries[index].isOn = isOn
        }
        return key
    }

    private static func isSingleToken(_ key: String, for descriptor: HardwareSwitchDescriptor) -> Bool {
        HardwareSwitchTokens.singleTokenAliases[descriptor.id]?.contains(key) ?? false
    }

    /// `true`/`false` when `key` is the on/off position id of `descriptor`.
    private static func position(of key: String, in descriptor: HardwareSwitchDescriptor) -> Bool? {
        if key == descriptor.positions.on.buttonId { return true }
        if key == descriptor.positions.off.buttonId { return false }
        return nil
    }
}
