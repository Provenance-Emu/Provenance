// KeyboardHUDView.swift
// PVUI
//
// The in-game input legend — "what does what" for the system being played.
// Part of Phase B (Keyboard HUD) of the macOS desktop input design; see
// docs/superpowers/specs/2026-08-09-macos-desktop-input-design.md.
//
// ── Read-only, always ──────────────────────────────────────────────────────
// `.allowsHitTesting(false)` is applied unconditionally: this view sits over a
// running game and its entire job is to INFORM. An earlier revision rendered
// the pinned state as a grid of tappable capsules that rebound keys, which
// read as a control panel floating on the console image and swallowed touches
// aimed at the game. Rebinding now lives only in Settings › Controller ›
// Keyboard Mapping (`KeyboardMappingView`) — a complete implementation of the
// same feature, linked from the legend's footer.
//
// ── Placement ──────────────────────────────────────────────────────────────
// Bottom-centre, inside the safe area, translucent, auto-fading:
//   * The full legend is a dozen rows. A corner can't hold that without
//     covering picture; the bottom band can, and on every configuration that
//     shows this overlay the bottom band is empty — the legend only appears
//     when a keyboard or gamepad is attached, and both of those hide the
//     on-screen touch controls (`HideTouchControls`) that would otherwise live
//     there. In desktop input mode the skin is suppressed entirely.
//   * Bottom-centre is also where players already expect transient control
//     hints, so it reads as chrome rather than as UI to be operated.
//   * Both presentations share the anchor so the thing doesn't appear to jump
//     around the screen between launch and play.
//
// Styling reuses the RetroWave pause chrome (`RetroPausePanelBackground`,
// `RetroPauseChrome`, `Color.retro*`) so it matches the pause menu instead of
// looking like a debug label.
//
// Copyright © 2026 Provenance Emu. All rights reserved.

#if !os(tvOS)
import SwiftUI

public struct KeyboardHUDView: View {
    @ObservedObject private var viewModel: KeyboardHUDViewModel

    private enum Layout {
        static let panelPadding: CGFloat = 12
        static let rowSpacing: CGFloat = 3
        static let stripSpacing: CGFloat = 6
        static let panelOpacity: Double = 0.92
        /// Keeps the panel from stretching edge-to-edge on a Mac window or iPad
        /// landscape, where a full-width strip of text is hard to scan.
        static let maxPanelWidth: CGFloat = 460
        static let keycapMinWidth: CGFloat = 62
        static let rowFontSize: CGFloat = 11
        static let stripFontSize: CGFloat = 10
        static let footnoteFontSize: CGFloat = 9
        static let glowRadius: CGFloat = 6
    }

    public init(viewModel: KeyboardHUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            if viewModel.isShowingFullLegend {
                legendPanel
            } else {
                compactStrip
            }
        }
        .opacity(viewModel.isVisible ? Layout.panelOpacity : 0)
        // Unconditional: the legend never takes input. Untouched areas — and
        // the whole overlay — fall through to the game below.
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: KeyboardHUDViewModel.fadeAnimationDuration), value: viewModel.isVisible)
        .animation(.easeInOut(duration: KeyboardHUDViewModel.fadeAnimationDuration), value: viewModel.isShowingFullLegend)
    }

    // MARK: - Full legend (at launch, and while pinned)

    private var legendPanel: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            header
            ForEach(viewModel.legend.rows) { row in
                legendRow(row)
            }
            if viewModel.legend.hasGenericFaceNames {
                footnote("A/B/X/Y are gamepad buttons — this core doesn't publish its console names.")
            }
            footnote("Remap in Settings › Controller › Keyboard Mapping")
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: Layout.maxPanelWidth)
        .background { RetroPausePanelBackground(isDark: true) }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: headerSymbol)
                .font(.system(size: Layout.rowFontSize, weight: .semibold))
                .foregroundStyle(Color.retroCyan)
            Text(headerTitle)
                .retroPauseSectionHeaderTypography()
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.bottom, 2)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: Layout.footnoteFontSize, weight: .medium))
            .foregroundStyle(.white.opacity(RetroPauseChrome.sectionTitleMutedOpacity))
            .padding(.top, 4)
    }

    private func legendRow(_ row: InputLegendRow) -> some View {
        let isHeld = !viewModel.pressedActions.isDisjoint(with: row.actions)
        return HStack(spacing: 8) {
            keycap(row.inputLabel, highlighted: isHeld)
            Text(row.controlLabel)
                .font(.system(size: Layout.rowFontSize, weight: .semibold))
                .foregroundStyle(isHeld ? Color.retroCyan : .white)
            if let gamepadLabel = row.gamepadLabel {
                Text(gamepadLabel)
                    .font(.system(size: Layout.footnoteFontSize, weight: .medium))
                    .foregroundStyle(.white.opacity(RetroPauseChrome.sectionTitleMutedOpacity))
            }
            Spacer(minLength: 0)
        }
    }

    private func keycap(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.system(size: Layout.rowFontSize, weight: .heavy, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(minWidth: Layout.keycapMinWidth, alignment: .center)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: RetroPauseChrome.radiusXS)
                    .fill(highlighted ? Color.retroPink.opacity(0.3) : Color.white.opacity(0.08))
            }
            .overlay {
                RoundedRectangle(cornerRadius: RetroPauseChrome.radiusXS)
                    .strokeBorder(highlighted ? Color.retroPink : Color.white.opacity(0.25),
                                  lineWidth: highlighted ? 1.5 : 1)
            }
            .foregroundStyle(highlighted ? .white : .white.opacity(0.75))
            .shadow(color: Color.retroPink.opacity(highlighted ? 0.6 : 0), radius: Layout.glowRadius)
    }

    // MARK: - Transient strip (what was just pressed)

    private var compactStrip: some View {
        HStack(spacing: Layout.stripSpacing) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: Layout.stripFontSize, weight: .semibold))
                .foregroundStyle(Color.retroCyan)
            ForEach(heldRows) { row in
                Text(row.controlLabel)
                    .font(.system(size: Layout.stripFontSize, weight: .heavy))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background { Capsule().fill(Color.retroCyan.opacity(0.28)) }
                    .overlay { Capsule().strokeBorder(Color.retroCyan, lineWidth: 1.5) }
                    .foregroundStyle(.white)
                    .shadow(color: Color.retroCyan.opacity(0.6), radius: Layout.glowRadius)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background { RetroPausePanelBackground(isDark: true) }
    }

    // MARK: - Helpers

    /// Legend rows for whatever is currently held, in legend order so the strip
    /// doesn't reshuffle while keys are added and released.
    private var heldRows: [InputLegendRow] {
        viewModel.legend.rows.filter { !viewModel.displayActions.isDisjoint(with: $0.actions) }
    }

    private var headerTitle: String {
        guard let systemName = viewModel.systemName, !systemName.isEmpty else { return "CONTROLS" }
        return "CONTROLS · \(systemName.uppercased())"
    }

    private var headerSymbol: String {
        viewModel.isPinned ? "pin.fill" : "keyboard.fill"
    }
}
#endif // !os(tvOS)
