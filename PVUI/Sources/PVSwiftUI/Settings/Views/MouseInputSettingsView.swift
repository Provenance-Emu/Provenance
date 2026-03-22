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

// MARK: - Standalone full-page view

/// A full-page settings view for Mouse Input configuration.
/// Used as a navigation destination from the Controller settings tab.
public struct MouseInputSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("MOUSE INPUT")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .shadow(color: .retroPink.opacity(0.5), radius: 10, x: 0, y: 0)

                CollapsibleSection(title: "Mouse Input") {
                    MouseSection()
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .navigationTitle("Mouse Input")
        .background(Color(themeManager.currentPalette.gameLibraryBackground).ignoresSafeArea())
    }
}

// MARK: - Pause menu inline mouse picker

/// Compact picker + sliders for use inside the pause menu Options tab.
/// Shows only the input source picker and global sensitivity slider inline.
struct PauseMenuMouseSection: View {
    @Default(.mouseInputSource) private var inputSource
    @Default(.mouseSensitivity) private var sensitivity
    @ObservedObject private var themeManager = ThemeManager.shared

    private var palette: UXThemePalette { themeManager.currentPalette }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text("MOUSE INPUT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor
                    ?? palette.gameLibraryText.swiftUIColor).opacity(0.7))

            // Input source picker (compact)
            compactSourcePicker

            // Sensitivity
            HStack {
                Label("Sensitivity", systemImage: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(palette.settingsCellText?.swiftUIColor
                        ?? palette.gameLibraryText.swiftUIColor)
                Spacer()
                Text(String(format: "%.1f×", sensitivity))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(palette.defaultTintColor.swiftUIColor)
            }
            Slider(value: $sensitivity, in: 0.1...5.0, step: 0.1)
                .accentColor(palette.defaultTintColor.swiftUIColor)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    (palette.settingsCellBackground?.swiftUIColor
                        ?? Color(palette.gameLibraryBackground))
                        .opacity(palette.dark ? 0.6 : 0.9)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(palette.defaultTintColor.swiftUIColor, lineWidth: 1)
                )
        )
    }

    private var compactSourcePicker: some View {
        Picker("Input Source", selection: $inputSource) {
            ForEach(MouseInputSource.allCases, id: \.rawValue) { source in
                Label(source.displayName, systemImage: source.symbolName)
                    .tag(source)
            }
        }
        #if !os(tvOS)
        .pickerStyle(.menu)
        #else
        .pickerStyle(.segmented)
        #endif
        .foregroundColor(palette.settingsCellText?.swiftUIColor
            ?? palette.gameLibraryText.swiftUIColor)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    (palette.settingsCellBackground?.swiftUIColor
                        ?? Color(palette.gameLibraryBackground))
                        .opacity(0.8)
                )
        )
    }
}
