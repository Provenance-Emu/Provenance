// InputLegend.swift
// PVUI
//
// Derivation of the in-game "what does what" input legend shown by
// `KeyboardHUDView`. Pure data + logic, no SwiftUI, so the truthfulness rules
// below can be reasoned about (and unit-tested) on their own.
//
// ── Why this file is so cautious about naming ──────────────────────────────
// A legend that lies is worse than no legend, so every label here is derived
// from data that was traced end-to-end, and anything that could not be traced
// degrades to a generic gamepad name instead of guessing.
//
// The chain a keypress actually travels is:
//
//   physical key
//     → `KeyboardControllerMap` / `KeyboardControllerAction`   (source of truth)
//     → `GCKeyboard.createController()` in PVControllerManager.swift
//     → either the virtual `GCExtendedGamepad` element, or (for
//       `.start`/`.select` only) `controllerViewController.pressStart/pressSelect`
//     → the core.
//
// Two facts from that chain drive the rules below:
//
//  1. `.start` / `.select` never touch the virtual gamepad at all —
//     `createController()` routes them straight to
//     `controllerViewController?.pressStart(forPlayer:)` /`pressSelect(...)`,
//     which is the *same* responder the on-screen Start/Select button uses.
//     So `PVStartButton` / `PVSelectButton`'s `PVControlTitle` from
//     Systems.plist ("Start", "Run", "Mode", …) is exactly right for them,
//     unconditionally.
//
//  2. Face buttons go through the virtual gamepad's `buttonA…buttonY`, and
//     what the *console* calls those is decided per-core, in ObjC bridges,
//     with no shared data model. Most cores follow the positional convention
//     (MFi's bottom button drives the console's bottom button) — verified in
//     `PVThinLibretroCore+Controls.swift` (`RetroJoypad.b ← .buttonA`, and its
//     comment "libretro uses Nintendo layout, MFi uses Xbox") and in
//     snes9x's `PVSNESEmulatorCore.mm` (`PVSNESButtonB ← gamepad.buttonA`).
//     But NOT all: Dolphin's `PVDolphinCore+Controls.mm` maps
//     `buttonA → GameCube BUTTON_A` (identity, not positional), which would
//     make a positional label wrong for GameCube.
//     Hence `faceNamesAreTrustworthy` — the caller only passes `true` for the
//     thin libretro wrapper, where the positional swap is source-verified and
//     uniform across every core it hosts. Everything else shows generic
//     gamepad names, which are true by construction.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import Foundation
import CoreGraphics
import PVPlists
import PVSystems

private typealias LayoutKeys = SystemDictionaryKeys.ControllerLayoutKeys

// MARK: - Legend

/// A derived legend plus the caveat the view needs in order not to overstate it.
public struct InputLegend: Equatable {
    public let rows: [InputLegendRow]

    /// True when at least one face-button row is labelled with the generic
    /// gamepad name because the system's own name couldn't be derived
    /// truthfully. The view surfaces this — "A/B/X/Y are gamepad buttons" —
    /// so nobody reads a gamepad label as a console label.
    public let hasGenericFaceNames: Bool

    public static let empty = InputLegend(rows: [], hasGenericFaceNames: false)

    public init(rows: [InputLegendRow], hasGenericFaceNames: Bool) {
        self.rows = rows
        self.hasGenericFaceNames = hasGenericFaceNames
    }
}

// MARK: - Row

/// One line of the legend: the physical input(s) on the left, what they drive
/// on the right.
public struct InputLegendRow: Identifiable, Equatable {
    /// Stable identity for `ForEach` — the first action's raw value, which is
    /// unique because no action appears in more than one row.
    public var id: String { actions.first?.rawValue ?? controlLabel }

    /// The action(s) this row stands for. More than one for the combined
    /// D-Pad / thumbstick rows, so the row highlights when *any* of them is
    /// held.
    public let actions: [KeyboardControllerAction]

    /// What the user physically presses — key name(s), or a gamepad button
    /// name. Already remap-resolved by the caller.
    public let inputLabel: String

    /// What it drives, in the system's own vocabulary when that could be
    /// derived truthfully, otherwise the generic gamepad control name.
    public let controlLabel: String

    /// The generic gamepad name, shown muted next to `controlLabel` when the
    /// two differ (e.g. `✕ (A)`). `nil` when they're the same, or when the row
    /// isn't a gamepad element at all.
    public let gamepadLabel: String?

    public init(actions: [KeyboardControllerAction], inputLabel: String, controlLabel: String, gamepadLabel: String?) {
        self.actions = actions
        self.inputLabel = inputLabel
        self.controlLabel = controlLabel
        self.gamepadLabel = gamepadLabel
    }
}

// MARK: - Face button geometry

/// Resolves the system's own names for the four face buttons by *position*,
/// using the frames Systems.plist already ships for the on-screen controls.
///
/// This is a derivation, not a per-system table: the same geometric rule runs
/// against every system's layout, and any layout it can't resolve
/// unambiguously yields `nil` so the caller falls back to generic names.
/// PC Engine (two side-by-side buttons), Genesis/Saturn (a 3×2 block), N64
/// (seven buttons) and the arcade layouts (diamond + a "Coin" button) all fail
/// the check and degrade automatically.
enum FaceButtonGeometry {

    /// A face button must be at least this many times further from the group's
    /// centre along its own axis than across it to count as "clearly left" /
    /// "clearly up" etc. Keeps skewed rows (Genesis' stepped 3×2) from being
    /// read as a diamond.
    private static let axisDominanceRatio: CGFloat = 2.0

    /// The number of buttons a diamond has. A group with any other count is
    /// not a diamond and is rejected outright.
    private static let diamondButtonCount = 4

    /// Maps each face action to the system's own button title, or `nil` when
    /// the group isn't an unambiguous four-point diamond.
    ///
    /// The action↔position pairing is the MFi face layout:
    /// `buttonA` bottom, `buttonB` right, `buttonX` left, `buttonY` top.
    static func titles(for buttons: [ControlGroupButton]) -> [KeyboardControllerAction: String]? {
        guard buttons.count == diamondButtonCount else { return nil }

        let points: [(title: String, centre: CGPoint)] = buttons.compactMap {
            guard let centre = centre(ofFrameString: $0.PVControlFrame) else { return nil }
            return ($0.PVControlTitle, centre)
        }
        guard points.count == diamondButtonCount else { return nil }

        let centroid = CGPoint(
            x: points.reduce(0) { $0 + $1.centre.x } / CGFloat(diamondButtonCount),
            y: points.reduce(0) { $0 + $1.centre.y } / CGFloat(diamondButtonCount)
        )

        var resolved: [KeyboardControllerAction: String] = [:]
        for point in points {
            let dx = point.centre.x - centroid.x
            let dy = point.centre.y - centroid.y
            let action: KeyboardControllerAction
            if abs(dx) > abs(dy) * axisDominanceRatio {
                action = dx > 0 ? .buttonB : .buttonX          // right : left
            } else if abs(dy) > abs(dx) * axisDominanceRatio {
                // Layout frames are UIKit coordinates — y grows downward.
                action = dy > 0 ? .buttonA : .buttonY          // bottom : top
            } else {
                return nil                                     // diagonal / ambiguous
            }
            // Two buttons resolving to the same slot means it isn't a diamond.
            guard resolved[action] == nil else { return nil }
            resolved[action] = point.title
        }
        guard resolved.count == diamondButtonCount else { return nil }
        return resolved
    }

    /// Centre point of a `"{{x,y},{w,h}}"` frame string as written in
    /// Systems.plist. `NSCoder.cgRect(for:)` isn't used here so this stays
    /// free of UIKit and testable on any platform.
    static func centre(ofFrameString frame: String) -> CGPoint? {
        let numbers = frame
            .split(whereSeparator: { !"0123456789.-".contains($0) })
            .compactMap { Double($0) }
        guard numbers.count >= 4 else { return nil }
        return CGPoint(x: numbers[0] + numbers[2] / 2, y: numbers[1] + numbers[3] / 2)
    }
}

// MARK: - Builder

/// Builds the legend rows for the running game from the system's shipped
/// control layout plus whatever the caller knows about the physical input.
public enum InputLegendBuilder {

    /// - Parameters:
    ///   - layout: `PVEmulatorConfiguration.controllerLayout(forSystemIdentifier:)`
    ///     for the running game. `nil` (or a system with no layout) still
    ///     produces a usable generic legend.
    ///   - faceNamesAreTrustworthy: whether the running core is known to follow
    ///     the positional MFi↔console face-button convention. See the file
    ///     header — only the thin libretro wrapper qualifies today.
    ///   - inputLabels: the physical input for each action. Actions absent
    ///     from the dictionary have no binding on the current hardware and
    ///     their rows are dropped rather than shown with a placeholder.
    public static func legend(
        layout: [ControlLayoutEntry]?,
        faceNamesAreTrustworthy: Bool,
        inputLabels: [KeyboardControllerAction: String]
    ) -> InputLegend {
        let layout = layout ?? []
        func inputLabel(_ action: KeyboardControllerAction) -> String? { inputLabels[action] }
        let systemNames = systemButtonNames(from: layout, faceNamesAreTrustworthy: faceNamesAreTrustworthy)

        var rows: [InputLegendRow] = []
        /// Set when a face-button row had to fall back to a generic gamepad
        /// name, so the view can say which vocabulary it's speaking.
        var hasGenericFaceRow = false
        /// Whether the system declares face buttons at all. Apple II doesn't,
        /// and inventing four unexplained A/B/X/Y rows for a machine with no
        /// action buttons would be the least useful thing this file could do.
        /// Systems that ship a group but no resolvable diamond (home computers
        /// with a "1"/"2" fire pair, PC Engine, Genesis, …) still get the
        /// generic rows — pressing gamepad A really does do something there —
        /// plus the caveat naming the vocabulary.
        let hasFaceButtonGroup = layout.contains { $0.PVControlType == LayoutKeys.ButtonGroup }

        /// Combined row for a directional control: one line listing every key
        /// bound to the four directions, rather than four near-identical lines.
        func appendDirectional(_ actions: [KeyboardControllerAction], label: String, requiresControlType: String) {
            guard layout.contains(where: { $0.PVControlType == requiresControlType }) else { return }
            let labels = actions.compactMap(inputLabel)
            guard !labels.isEmpty else { return }
            rows.append(InputLegendRow(
                actions: actions,
                inputLabel: labels.joined(separator: " "),
                controlLabel: label,
                gamepadLabel: nil
            ))
        }

        func appendButton(_ action: KeyboardControllerAction) {
            // No system name and no generic fallback means the control isn't
            // part of this system at all (e.g. `.l2` on a one-shoulder
            // console) — drop the row rather than imply a button that isn't
            // there.
            let systemName = systemNames[action]
            let fallback = hasFaceButtonGroup ? genericFallback(for: action) : nil
            guard let controlLabel = systemName ?? fallback else { return }
            guard let input = inputLabel(action) else { return }
            if systemName == nil { hasGenericFaceRow = true }
            let gamepadName = action.displayName
            rows.append(InputLegendRow(
                actions: [action],
                inputLabel: input,
                controlLabel: controlLabel,
                gamepadLabel: controlLabel == gamepadName ? nil : gamepadName
            ))
        }

        appendDirectional([.dpadUp, .dpadDown, .dpadLeft, .dpadRight], label: "D-Pad", requiresControlType: LayoutKeys.DPad)
        appendDirectional([.leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight],
                          label: "Left Stick", requiresControlType: LayoutKeys.JoyPad)
        appendDirectional([.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight],
                          label: "Right Stick", requiresControlType: LayoutKeys.JoyPad2)

        [.buttonA, .buttonB, .buttonX, .buttonY,
         .l1, .r1, .l2, .r2, .l3, .r3,
         .start, .select].forEach(appendButton)

        // `hasGenericFaceRow` can only be set when a group existed, since
        // that's the only case a generic fallback is offered.
        return InputLegend(rows: rows, hasGenericFaceNames: hasGenericFaceRow)
    }

    /// Generic gamepad label used when the system layout doesn't name a
    /// control. `nil` for the controls that only make sense when the system
    /// actually has them — shoulders/triggers/stick-clicks/Start/Select are
    /// dropped rather than invented.
    private static func genericFallback(for action: KeyboardControllerAction) -> String? {
        switch action {
        case .buttonA, .buttonB, .buttonX, .buttonY:
            return action.displayName
        default:
            return nil
        }
    }

    /// The system's own name for each action, harvested from Systems.plist.
    ///
    /// Everything here except the face buttons is a direct, unconditional
    /// reading of a single layout entry — those control types have exactly one
    /// meaning. Face buttons go through `FaceButtonGeometry` and are only
    /// included when the caller vouched for the core's convention.
    static func systemButtonNames(
        from layout: [ControlLayoutEntry],
        faceNamesAreTrustworthy: Bool
    ) -> [KeyboardControllerAction: String] {
        var names: [KeyboardControllerAction: String] = [:]

        /// Shoulder titles pair by array order, not "first match wins":
        /// PlayStation ships two `PVLeftShoulderButton` entries titled L1/L2,
        /// while SNES ships one titled "L" (so `.l2` stays unnamed and its row
        /// is dropped).
        func assignOrdered(controlType: String, to actions: [KeyboardControllerAction]) {
            let titles = layout.filter { $0.PVControlType == controlType }.compactMap { $0.PVControlTitle }
            for (action, title) in zip(actions, titles) {
                names[action] = title
            }
        }

        assignOrdered(controlType: LayoutKeys.LeftShoulderButton, to: [.l1, .l2])
        assignOrdered(controlType: LayoutKeys.RightShoulderButton, to: [.r1, .r2])
        assignOrdered(controlType: LayoutKeys.LeftAnalogButton, to: [.l3])
        assignOrdered(controlType: LayoutKeys.RightAnalogButton, to: [.r3])
        assignOrdered(controlType: LayoutKeys.StartButton, to: [.start])
        assignOrdered(controlType: LayoutKeys.SelectButton, to: [.select])

        if faceNamesAreTrustworthy,
           let group = layout.first(where: { $0.PVControlType == LayoutKeys.ButtonGroup })?.PVGroupedButtons,
           let faceTitles = FaceButtonGeometry.titles(for: group) {
            names.merge(faceTitles) { _, new in new }
        }

        return names
    }
}
#endif // !os(tvOS)
