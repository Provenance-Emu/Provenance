//
//  RetroSettingsComponents.swift
//  PVUIBase
//
//  Reusable retrowave-styled components for settings views.
//  Import PVUIBase to get access to these across all settings views.
//
//  Created by Provenance Emu on 2026-03-29.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes

// MARK: - Retrowave Settings Background

/// Standard retrowave background for settings subpages.
/// Use this as the bottom layer of a `ZStack` in any settings view.
public struct RetroSettingsBackground: View {
    public init() {}

    public var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea(.all)
            RetroGrid()
                .ignoresSafeArea(.all)
                .opacity(0.25)
        }
    }
}

// MARK: - Retrowave Section Divider

/// A retroBlue-tinted horizontal separator for use between sections in retrowave settings views.
public struct RetroSettingsDivider: View {
    public init() {}

    public var body: some View {
        Divider()
            .background(Color.retroBlue.opacity(0.3))
    }
}

// MARK: - Retrowave Section Header

/// A retrowave-styled section header: retroPink SF Symbol + uppercase tracking label.
///
/// Matches the visual style used by all settings subpages.
///
/// Example:
/// ```swift
/// Section {
///     // row content
/// } header: {
///     RetroSettingsSectionHeader(icon: "waveform", title: "Audio Engine")
/// }
/// ```
public struct RetroSettingsSectionHeader: View {
    let icon: String
    let title: String

    public init(icon: String, title: String) {
        self.icon = icon
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.retroPink)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.retroPink)
        }
    }
}

// MARK: - tvOS horizontal padding modifier

public extension View {
    /// Applies the standard tvOS side-menu inset (80 pt) on tvOS; no-op on other platforms.
    @ViewBuilder
    func tvOSSettingsHorizontalPadding() -> some View {
        #if os(tvOS)
        self.padding(.horizontal, 80)
        #else
        self
        #endif
    }
}

// MARK: - Retrowave Picker Row

/// A selectable row for use in retrowave-styled picker groups (radio-button-like selection).
///
/// On tvOS, focus is handled via `retroFocusButtonStyle`; on iOS a plain style is used.
///
/// Example:
/// ```swift
/// ForEach(options) { option in
///     RetroSettingsPickerRow(
///         symbolName: option.icon,
///         title: option.name,
///         subtitle: option.description,
///         isSelected: selection == option
///     ) {
///         selection = option
///     }
/// }
/// ```
public struct RetroSettingsPickerRow: View {
    let symbolName: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    public init(
        symbolName: String,
        title: String,
        subtitle: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.symbolName = symbolName
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            rowContent
        }
        #if os(tvOS)
        .retroFocusButtonStyle(focusScale: 1.04, focusBorderWidth: 2.5, cornerRadius: 10)
        #else
        .buttonStyle(PlainButtonStyle())
        #endif
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 18))
                .frame(width: 28)
                .foregroundColor(isSelected ? .retroBlue : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.retroSettingsRowTitle)
                    .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                        ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.retroSettingsRowSubtitle)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.retroBlue)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected
                    ? Color.retroBlue.opacity(0.12)
                    : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            isSelected
                                ? Color.retroBlue.opacity(0.5)
                                : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Retrowave Action Button

/// A full-width retrowave-styled action button for settings pages.
public struct RetroSettingsActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    public init(title: String, icon: String, color: Color = .retroBlue, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(color.opacity(0.6), lineWidth: 1.5)
                    )
            )
        }
        #if os(tvOS)
        .retroFocusButtonStyle(
            focusScale: 1.04,
            focusBorderWidth: 3,
            cornerRadius: 10,
            primaryColor: color,
            secondaryColor: .retroPurple
        )
        #else
        .buttonStyle(PlainButtonStyle())
        #endif
    }
}

// MARK: - Font convenience extensions (settings-specific sizes)

public extension Font {
    /// Settings label / title font — 20pt semibold on tvOS, 14pt on iOS.
    static var retroSettingsLabel: Font {
        #if os(tvOS)
        .system(size: 20, weight: .semibold)
        #else
        .system(size: 14, weight: .semibold)
        #endif
    }

    /// Primary row title font — 18pt medium on tvOS, 15pt on iOS.
    static var retroSettingsRowTitle: Font {
        #if os(tvOS)
        .system(size: 18, weight: .medium)
        #else
        .system(size: 15, weight: .medium)
        #endif
    }

    /// Subtitle / helper text — 15pt on tvOS, 12pt on iOS.
    static var retroSettingsRowSubtitle: Font {
        #if os(tvOS)
        .system(size: 15)
        #else
        .system(size: 12)
        #endif
    }

    /// Monospaced value readout (e.g. "1.0×") — 16pt on tvOS, 13pt on iOS.
    static var retroSettingsValue: Font {
        #if os(tvOS)
        .system(size: 16, weight: .medium, design: .monospaced)
        #else
        .system(size: 13, weight: .medium, design: .monospaced)
        #endif
    }
}

