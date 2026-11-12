//
//  PauseMenuChrome.swift
//  PVUI
//
//  The pause panel's own controls: exit buttons, save row, page bar, shortcut legend, info pill.
//

import PVThemes
import SwiftUI

/// Colours of the pause panel, taken from the app theme.
///
/// The panel sets its colour scheme from the theme, so text drawn with `.primary` and
/// `.secondary` and the panel's material follow a light or a dark theme. Cells keep one
/// colour per function on every theme, so a control is recognised by it.
struct PauseMenuTheme {
    let isDark: Bool
    /// The theme's tint: titles, the selected page, the primary action, the cursor ring.
    let accent: Color
    /// The theme's menu background, laid over the panel's material.
    let panelTint: Color

    /// How much of `panelTint` covers the material: enough for labels over a bright game.
    static let panelTintOpacity: Double = 0.55
    static let borderOpacity: Double = 0.28
    static let dividerOpacity: Double = 0.1

    init(palette: any UXThemePalette) {
        isDark = palette.dark
        accent = Color(palette.defaultTintColor)
        panelTint = Color(palette.menuBackground)
    }

    var colorScheme: ColorScheme { isDark ? .dark : .light }
    var border: Color { accent.opacity(Self.borderOpacity) }
    var divider: Color { Color.primary.opacity(Self.dividerOpacity) }
    /// Leaving without saving.
    var destructive: Color { .retroPink }
}

/// Sizes shared by the panel's controls.
enum PauseMenuChromeMetrics {
    #if os(tvOS)
    static let fontSize: CGFloat = 18
    static let detailSize: CGFloat = 14
    static let controlHeight: CGFloat = 50
    static let tabHeight: CGFloat = 52
    static let keySize: CGFloat = 26
    #else
    static let fontSize: CGFloat = 12.5
    static let detailSize: CGFloat = 10.5
    static let controlHeight: CGFloat = 34
    static let tabHeight: CGFloat = 36
    static let keySize: CGFloat = 18
    #endif
    /// The exit buttons on the phone sheet are full thumb targets.
    static let sheetActionHeight: CGFloat = 44
    static let railWidth: CGFloat = 64
    static let cornerRadius: CGFloat = 10
    static let cursorLineWidth: CGFloat = 2
    static let focusScale: CGFloat = 1.06
}

/// A tinted button in the panel's chrome: an exit button or a save-row control.
struct PauseChromeButton: View {
    let title: String
    var symbol: String?
    /// Small text after the title: the age of the newest save, a count.
    var detail: String?
    let tint: Color
    /// Filled with the tint (the primary action) instead of washed with it.
    var prominent = false
    /// Shows the glyph alone and keeps `title` for VoiceOver.
    var iconOnly = false
    /// Takes all the width its row offers.
    var expands = false
    var height: CGFloat = PauseMenuChromeMetrics.controlHeight
    var isEnabled = true
    /// The controller cursor is on it.
    var isCursor = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                }
                if !iconOnly || symbol == nil {
                    Text(title).lineLimit(1)
                }
                if let detail, !iconOnly {
                    Text(detail)
                        .font(.system(size: PauseMenuChromeMetrics.detailSize))
                        .opacity(0.7)
                        .lineLimit(1)
                }
            }
            .font(.system(size: PauseMenuChromeMetrics.fontSize, weight: .semibold))
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .frame(maxWidth: expands ? .infinity : nil)
            .frame(height: height)
        }
        .buttonStyle(PauseChromeButtonStyle(tint: tint, prominent: prominent, isCursor: isCursor))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .accessibilityLabel(title)
    }
}

/// Wash, rim and cursor ring of a chrome control. On tvOS the focus engine supplies the cursor.
struct PauseChromeButtonStyle: ButtonStyle {
    let tint: Color
    var prominent = false
    var isCursor = false

    func makeBody(configuration: Configuration) -> some View {
        Face(configuration: configuration, tint: tint, prominent: prominent, isCursor: isCursor)
    }

    private struct Face: View {
        let configuration: Configuration
        let tint: Color
        let prominent: Bool
        let isCursor: Bool
        @Environment(\.isFocused) private var isFocused
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            let highlighted = isCursor || isFocused
            let shape = RoundedRectangle(cornerRadius: PauseMenuChromeMetrics.cornerRadius)
            configuration.label
                .foregroundStyle(prominent ? (colorScheme == .dark ? Color.black : Color.white) : tint)
                .background {
                    shape.fill(tint.opacity(prominent ? 1 : (highlighted
                        ? RetroPauseChrome.menuCellFillOpacityFocused : RetroPauseChrome.menuCellFillOpacityUnfocused + 0.04)))
                }
                .overlay {
                    if highlighted {
                        shape.strokeBorder(prominent ? Color.primary : tint, lineWidth: PauseMenuChromeMetrics.cursorLineWidth)
                    }
                }
                .scaleEffect(highlighted ? PauseMenuChromeMetrics.focusScale : 1)
                .opacity(configuration.isPressed ? 0.7 : 1)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.15), value: highlighted)
        }
    }
}

/// The page bar: along the top of a panel, the bottom of a phone sheet, or as a rail on a phone on its side.
struct PauseMenuTabBar: View {
    enum Style { case labels, stacked, rail }

    let selection: PauseMenuTab
    let style: Style
    let theme: PauseMenuTheme
    /// Shows L1 and R1 at the ends when a controller can switch pages.
    var showsShoulderKeys = false
    let select: (PauseMenuTab) -> Void

    var body: some View {
        switch style {
        case .rail:
            VStack(spacing: 2) { tabs }
                .frame(width: PauseMenuChromeMetrics.railWidth)
                .frame(maxHeight: .infinity)
        case .labels, .stacked:
            HStack(spacing: 4) {
                if showsShoulderKeys { PauseMenuKey(label: "L1", theme: theme) }
                tabs
                if showsShoulderKeys { PauseMenuKey(label: "R1", theme: theme) }
            }
        }
    }

    @ViewBuilder private var tabs: some View {
        ForEach(PauseMenuTab.allCases) { tab in
            Button { select(tab) } label: { label(for: tab) }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(tab == selection ? .isSelected : [])
        }
    }

    private func label(for tab: PauseMenuTab) -> some View {
        let isSelected = tab == selection
        return Group {
            if style == .labels {
                Text(tab.title).lineLimit(1)
            } else {
                VStack(spacing: 2) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: PauseMenuChromeMetrics.fontSize + 3))
                    Text(tab.title)
                        .font(.system(size: PauseMenuChromeMetrics.detailSize))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .font(.system(size: PauseMenuChromeMetrics.fontSize, weight: isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? theme.accent : Color.secondary)
        .frame(maxWidth: .infinity)
        .frame(height: style == .labels ? PauseMenuChromeMetrics.tabHeight - 6 : PauseMenuChromeMetrics.tabHeight + 6)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: PauseMenuChromeMetrics.cornerRadius - 2)
                    .fill(theme.accent.opacity(RetroPauseChrome.menuCellFillOpacityUnfocused + 0.06))
            }
        }
        .contentShape(Rectangle())
    }
}

/// A controller button drawn as a key cap.
struct PauseMenuKey: View {
    let label: String
    let theme: PauseMenuTheme

    var body: some View {
        Text(label)
            .font(.system(size: PauseMenuChromeMetrics.detailSize, weight: .bold))
            .foregroundStyle(Color.primary.opacity(0.85))
            .padding(.horizontal, 5)
            .frame(minWidth: PauseMenuChromeMetrics.keySize, minHeight: PauseMenuChromeMetrics.keySize)
            .overlay {
                Capsule().strokeBorder(Color.secondary.opacity(0.6))
            }
            .accessibilityHidden(true)
    }
}

/// What each controller button does in the menu, at the foot of the panel.
struct PauseMenuLegend: View {
    struct Entry: Identifiable {
        let keys: [String]
        let action: String
        var id: String { keys.joined() + action }
    }

    let entries: [Entry]
    let theme: PauseMenuTheme

    var body: some View {
        HStack(spacing: 14) {
            ForEach(entries) { entry in
                HStack(spacing: 4) {
                    ForEach(entry.keys, id: \.self) { PauseMenuKey(label: $0, theme: theme) }
                    Text(entry.action)
                        .font(.system(size: PauseMenuChromeMetrics.detailSize + 1))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .overlay(alignment: .top) { theme.divider.frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

/// The description of the control under the cursor. It floats beside the panel and takes no room in it.
struct PauseMenuInfoPill: View {
    let text: String
    let theme: PauseMenuTheme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "info.circle")
                .foregroundStyle(theme.accent)
            Text(text)
                .foregroundStyle(Color.primary.opacity(0.9))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .font(.system(size: PauseMenuChromeMetrics.fontSize))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule().fill(.regularMaterial)
                .overlay { Capsule().strokeBorder(theme.border) }
        }
        .environment(\.colorScheme, theme.colorScheme)
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
