//
//  MouseInputSettingsView.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-22.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Settings section for mouse input configuration.
//  Displayed in Settings → Controller → Mouse Input.
//

import SwiftUI
import PVSettings
import Defaults
import PVThemes
import PVUIBase

// MARK: - MouseInputSettingsView (full-page navigation target)

/// Full-page settings view for mouse input, suitable as a `NavigationLink` destination.
struct MouseInputSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            MouseSection()
                #if os(tvOS)
                // Leading padding accounts for the tvOS side-menu bar; trailing
                // keeps symmetry. 80 pt matches other settings subpages.
                .padding(.horizontal, 80)
                .padding(.vertical, 24)
                #else
                .padding()
                #endif
        }
        .navigationTitle("Mouse Input")
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
    }
}

// MARK: - MouseSection (for use inside CollapsibleSection)

/// Embeddable settings content for the Mouse Input section.
/// Drop inside a `CollapsibleSection(title: "Mouse Input")` in the Controller tab.
struct MouseSection: View {
    @Default(.mouseInputSource) private var inputSource
    @Default(.mouseSensitivity) private var sensitivity
    @Default(.gyroMouseEnabled) private var gyroMouseEnabled
    @Default(.gyroMouseSensitivity) private var gyroSensitivity
    @Default(.gyroMouseDeadZone) private var gyroDeadZone
    @Default(.lightGunCrosshairStyle) private var crosshairStyle
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Input source picker
            inputSourcePicker

            retroDivider

            // Light gun crosshair style
            crosshairStylePicker

            retroDivider

            // Global sensitivity
            sensitivitySlider(
                title: "Mouse Sensitivity",
                subtitle: "Multiplier for all mouse delta events",
                value: $sensitivity
            )

            // Gyro-specific controls (only relevant when gyro or auto)
            if inputSource == .gyro || inputSource == .auto {
                retroDivider

                Toggle(isOn: $gyroMouseEnabled) {
                    Label("Enable Gyro Mouse", systemImage: "gyroscope")
                        .font(.retroSettingsLabel)
                        .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                            ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                }
                .tint(.retroBlue)
                #if os(tvOS)
                .retroThemedFocus()
                #endif

                if gyroMouseEnabled {
                    sensitivitySlider(
                        title: "Gyro Sensitivity",
                        subtitle: "Multiplier for gyroscope mouse movement",
                        value: $gyroSensitivity
                    )

                    deadZoneSlider
                }

                Text("Note: Gyro mouse settings are stored but not yet applied during gameplay in this build.")
                    .font(.retroSettingsRowSubtitle)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Retrowave divider

    private var retroDivider: some View {
        Divider()
            .background(Color.retroBlue.opacity(0.3))
    }

    // MARK: - Input Source Picker

    private var inputSourcePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Input Source", systemImage: "computermouse")
                .font(.retroSettingsLabel)
                .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                    ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)

            ForEach(MouseInputSource.allCases.filter { source in
                #if os(tvOS)
                return source != .touchscreen
                #else
                return true
                #endif
            }, id: \.rawValue) { source in
                RetroSettingsPickerRow(
                    symbolName: source.symbolName,
                    title: source.displayName,
                    subtitle: source.subtitle,
                    isSelected: inputSource == source
                ) {
                    inputSource = source
                }
            }
        }
    }

    // MARK: - Crosshair Style Picker

    private var crosshairStylePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Light Gun Crosshair", systemImage: "scope")
                .font(.retroSettingsLabel)
                .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                    ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)

            Text("Shown when playing light-gun games")
                .font(.retroSettingsRowSubtitle)
                .foregroundColor(.secondary)

            ForEach(LightGunCrosshairStyle.allCases, id: \.rawValue) { style in
                RetroSettingsPickerRow(
                    symbolName: style.symbolName,
                    title: style.displayName,
                    subtitle: style.subtitle,
                    isSelected: crosshairStyle == style
                ) {
                    crosshairStyle = style
                }
            }
        }
    }

    // MARK: - Sensitivity Slider

    private func sensitivitySlider(title: String, subtitle: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: "slider.horizontal.3")
                    .font(.retroSettingsLabel)
                    .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                        ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                Spacer()
                Text(String(format: "%.1f×", value.wrappedValue))
                    .font(.retroSettingsValue)
                    .foregroundColor(.retroBlue)
            }
            Text(subtitle)
                .font(.retroSettingsRowSubtitle)
                .foregroundColor(.secondary)
            RetroWaveSlider(value: value, in: 0.1...5.0, step: 0.1)
                .accentColor(.retroBlue)
                #if os(tvOS)
                .padding(.bottom, 8)
                #endif
        }
    }

    // MARK: - Dead Zone Slider

    private var deadZoneSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Gyro Dead Zone", systemImage: "gyroscope")
                    .font(.retroSettingsLabel)
                    .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                        ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                Spacer()
                Text(String(format: "%.2f", gyroDeadZone))
                    .font(.retroSettingsValue)
                    .foregroundColor(.retroBlue)
            }
            Text("Minimum rotation (rad/s) to register as movement")
                .font(.retroSettingsRowSubtitle)
                .foregroundColor(.secondary)
            RetroWaveSlider(value: $gyroDeadZone,
                            in: 0.0...0.5,
                            step: 0.01)
                .accentColor(.retroBlue)
                #if os(tvOS)
                .padding(.bottom, 8)
                #endif
        }
    }
}
