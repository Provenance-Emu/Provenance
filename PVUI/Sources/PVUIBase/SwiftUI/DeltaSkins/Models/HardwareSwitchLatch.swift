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

/// Remembers the position of each console switch so a skin that
/// has only one input id per switch (Manic `tvType`, `leftDifficulty`...) can
/// still tell the core which position was chosen.
///
/// - A press of a position-less token advances the latched state and emits the id
///   of the new position; the matching release repeats that id.
/// - A press of an explicit position id (`leftdiffa`, `color`...) passes through
///   unchanged and records that position, so mixed skins stay in step.
/// - A press-to-toggle switch advances its display state and forwards its shared id.
public struct HardwareSwitchLatch {
    private let descriptors: [HardwareSwitchDescriptor]
    public private(set) var positionIndexes: [String: Int]
    /// Id emitted by the in-flight press of each position-less token.
    private var pending: [String: String] = [:]

    public init(descriptors: [HardwareSwitchDescriptor]) {
        self.descriptors = descriptors
        positionIndexes = Dictionary(descriptors.map { ($0.id, $0.initialPositionIndex) }, uniquingKeysWith: { first, _ in first })
    }

    /// Returns the button id to forward, or nil for a release whose press was never seen.
    public mutating func resolve(_ token: String, isPressed: Bool) -> String? {
        let key = token.lowercased()

        if let descriptor = descriptors.first(where: {
            !$0.isPressToToggle && ($0.advanceButtonId?.lowercased() == key ||
                                    HardwareSwitchTokens.singleTokenAliases[$0.id]?.contains(key) == true)
        }) {
            guard isPressed else { return pending.removeValue(forKey: key) }
            let emitted = descriptor.positionList[advance(descriptor)].buttonId
            pending[key] = emitted
            return emitted
        }

        if isPressed {
            for descriptor in descriptors {
                guard let index = descriptor.positionList.firstIndex(where: { $0.buttonId.lowercased() == key }) else { continue }
                if descriptor.isPressToToggle {
                    _ = advance(descriptor)
                } else {
                    positionIndexes[descriptor.id] = index
                }
                break
            }
        }
        return key
    }

    private mutating func advance(_ descriptor: HardwareSwitchDescriptor) -> Int {
        let index = descriptor.nextPosition(after: positionIndexes[descriptor.id] ?? descriptor.initialPositionIndex)
        positionIndexes[descriptor.id] = index
        return index
    }
}
