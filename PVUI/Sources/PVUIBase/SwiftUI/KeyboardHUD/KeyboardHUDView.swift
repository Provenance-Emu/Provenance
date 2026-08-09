// KeyboardHUDView.swift
// PVUI
//
// Translucent in-game overlay for `KeyboardHUDViewModel` — part of Phase B
// (Keyboard HUD) of the macOS desktop input design. See
// docs/superpowers/specs/2026-08-09-macos-desktop-input-design.md.
//
// Two presentations, both styled with the RetroWave design system
// (`RetroPausePanelBackground`, `Color.retro*`) to match the pause menu /
// virtual keyboard overlay rather than reading as a debug label:
//   - Unpinned (transient): a compact strip of glyphs for whatever actions
//     are currently held, no tap targets. Fades in on the first mapped
//     keypress and auto-fades ~2s after the last one.
//   - Pinned: a full grid of every `KeyboardControllerAction` with its bound
//     key, each tappable to rebind (`KeyboardHUDViewModel.beginCapture`).
//     The rebind affordance intentionally only exists in this mode.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI

public struct KeyboardHUDView: View {
    @ObservedObject private var viewModel: KeyboardHUDViewModel

    private enum Layout {
        static let gridColumnCount = 3
        static let chipSpacing: CGFloat = 6
        /// Fixed (not `.flexible`) column width. The HUD is hosted in a
        /// `UIHostingController` sized only by `sizingOptions = [.intrinsicContentSize]`
        /// with no width constraint from its container (see
        /// `PVEmulatorViewController+KeyboardHUD.swift`) — `.flexible` columns
        /// need a definite width proposal from an ancestor to lay out, which
        /// doesn't exist here. `.fixed` columns compute the grid's own width
        /// bottom-up instead, which is what makes intrinsic sizing work.
        static let chipColumnWidth: CGFloat = 78
        static let glowRadius: CGFloat = 6
    }

    public init(viewModel: KeyboardHUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.isPinned {
                expandedPanel
            } else {
                compactStrip
            }
        }
        .opacity(viewModel.isVisible ? 1 : 0)
        .allowsHitTesting(viewModel.isPinned && viewModel.isVisible)
        .animation(.easeInOut(duration: KeyboardHUDViewModel.fadeAnimationDuration), value: viewModel.isVisible)
        .animation(.easeInOut(duration: KeyboardHUDViewModel.fadeAnimationDuration), value: viewModel.isPinned)
    }

    // MARK: - Compact (unpinned, transient)

    private var compactStrip: some View {
        HStack(spacing: Layout.chipSpacing) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.retroCyan)
            ForEach(displayedInOrder, id: \.rawValue) { action in
                chipLabel(text: Self.shortLabel(for: action), pressed: true, capturing: false)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background { RetroPausePanelBackground(isDark: true) }
    }

    // MARK: - Expanded (pinned, rebind-capable)

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: Layout.chipSpacing) {
                ForEach(KeyboardControllerAction.allCases, id: \.rawValue) { action in
                    rebindChip(for: action)
                }
            }
        }
        .padding(12)
        .background { RetroPausePanelBackground(isDark: true) }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "keyboard.fill")
                .foregroundStyle(Color.retroCyan)
            Text("KEYBOARD")
                .font(.system(size: RetroPauseChrome.sectionTitleFontSize(), weight: .heavy))
                .tracking(RetroPauseChrome.sectionTitleTracking())
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "pin.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.retroPink)
        }
    }

    @ViewBuilder
    private func rebindChip(for action: KeyboardControllerAction) -> some View {
        let isCapturing = viewModel.capturingAction == action
        let isHeld = viewModel.pressedActions.contains(action)
        let text = isCapturing ? "Press a key…" : "\(Self.shortLabel(for: action)) \(viewModel.keyName(for: action))"
        Button {
            viewModel.beginCapture(for: action)
        } label: {
            chipLabel(text: text, pressed: isHeld, capturing: isCapturing)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(action.displayName), bound to \(viewModel.keyName(for: action))")
        .accessibilityHint("Double tap, then press a key to rebind")
    }

    private func chipLabel(text: String, pressed: Bool, capturing: Bool) -> some View {
        let accent = capturing ? Color.retroPink : Color.retroCyan
        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                Capsule().fill((pressed || capturing) ? accent.opacity(0.28) : Color.white.opacity(0.08))
            }
            .overlay {
                Capsule().strokeBorder(
                    (pressed || capturing) ? accent : Color.white.opacity(0.25),
                    lineWidth: (pressed || capturing) ? 1.5 : 1
                )
            }
            .foregroundStyle((pressed || capturing) ? .white : .white.opacity(0.7))
            .shadow(color: accent.opacity((pressed || capturing) ? 0.6 : 0), radius: Layout.glowRadius)
    }

    // MARK: - Helpers

    private var displayedInOrder: [KeyboardControllerAction] {
        KeyboardControllerAction.allCases.filter { viewModel.displayActions.contains($0) }
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(Layout.chipColumnWidth), spacing: Layout.chipSpacing), count: Layout.gridColumnCount)
    }

    /// Compact glyph/abbreviation for the HUD's tight chip layout.
    /// `KeyboardControllerAction.displayName` (full text like "D-Pad Up") is
    /// still used for accessibility labels — this is purely a visual
    /// shorthand, not a duplicate of that API.
    private static func shortLabel(for action: KeyboardControllerAction) -> String {
        switch action {
        case .dpadUp: return "D-Pad ↑"
        case .dpadDown: return "D-Pad ↓"
        case .dpadLeft: return "D-Pad ←"
        case .dpadRight: return "D-Pad →"
        case .leftStickUp: return "LS ↑"
        case .leftStickDown: return "LS ↓"
        case .leftStickLeft: return "LS ←"
        case .leftStickRight: return "LS →"
        case .rightStickUp: return "RS ↑"
        case .rightStickDown: return "RS ↓"
        case .rightStickLeft: return "RS ←"
        case .rightStickRight: return "RS →"
        case .buttonA: return "A"
        case .buttonB: return "B"
        case .buttonX: return "X"
        case .buttonY: return "Y"
        case .l1: return "L1"
        case .l2: return "L2"
        case .r1: return "R1"
        case .r2: return "R2"
        case .l3: return "L3"
        case .r3: return "R3"
        case .menu: return "Menu"
        case .options: return "Opt"
        case .select: return "Sel"
        case .start: return "Start"
        }
    }
}
#endif // !os(tvOS)
