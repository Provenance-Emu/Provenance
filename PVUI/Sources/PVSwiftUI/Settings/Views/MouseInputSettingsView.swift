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

// MARK: - MouseSection (for use inside CollapsibleSection)

/// Embeddable settings content for the Mouse Input section.
/// Drop inside a `CollapsibleSection(title: "Mouse Input")` in the Controller tab.
struct MouseSection: View {
    @Default(.mouseInputSource) private var inputSource
    @Default(.mouseSensitivity) private var sensitivity
    @Default(.gyroMouseSensitivity) private var gyroSensitivity
    @Default(.gyroMouseDeadZone) private var gyroDeadZone
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Input source picker
            inputSourcePicker

            Divider()
                .background(Color.retroBlue.opacity(0.3))

            // Global sensitivity
            sensitivitySlider(
                title: "Mouse Sensitivity",
                subtitle: "Multiplier for all mouse delta events",
                value: $sensitivity
            )

            // Gyro-specific controls (only relevant when gyro or auto)
            if inputSource == .gyro || inputSource == .auto {
                Divider()
                    .background(Color.retroBlue.opacity(0.3))

                sensitivitySlider(
                    title: "Gyro Sensitivity",
                    subtitle: "Multiplier for gyroscope mouse movement",
                    value: $gyroSensitivity
                )

                deadZoneSlider
            }
        }
    }

    // MARK: - Input Source Picker

    private var inputSourcePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Input Source", systemImage: "computermouse")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                    ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)

            ForEach(MouseInputSource.allCases, id: \.rawValue) { source in
                Button(action: { inputSource = source }) {
                    HStack(spacing: 12) {
                        Image(systemName: source.symbolName)
                            .font(.system(size: 16))
                            .frame(width: 24)
                            .foregroundColor(inputSource == source ? .retroBlue : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                                    ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            Text(source.subtitle)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if inputSource == source {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.retroBlue)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(inputSource == source
                                ? Color.retroBlue.opacity(0.12)
                                : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        inputSource == source
                                            ? Color.retroBlue.opacity(0.5)
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Sensitivity Slider

    private func sensitivitySlider(title: String, subtitle: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                        ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                Spacer()
                Text(String(format: "%.1f×", value.wrappedValue))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.retroBlue)
            }
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Slider(value: value, in: 0.1...5.0, step: 0.1)
                .accentColor(.retroBlue)
        }
    }

    // MARK: - Dead Zone Slider

    private var deadZoneSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Gyro Dead Zone", systemImage: "gyroscope")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(themeManager.currentPalette.settingsCellText?.swiftUIColor
                        ?? themeManager.currentPalette.gameLibraryText.swiftUIColor)
                Spacer()
                Text(String(format: "%.2f", gyroDeadZone))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.retroBlue)
            }
            Text("Minimum rotation (rad/s) to register as movement")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Slider(value: $gyroDeadZone, in: 0.0...0.5, step: 0.01)
                .accentColor(.retroBlue)
        }
    }
}

