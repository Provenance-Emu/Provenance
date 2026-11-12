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
import PVCoreBridge

// MARK: - MouseInputSettingsView (full-page navigation target)

/// Full-page settings view for mouse input, suitable as a `NavigationLink` destination.
struct MouseInputSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            #if os(tvOS)
            RetroSettingsBackground()
            #endif

            ScrollView {
                MouseSection()
                    .tvOSSettingsHorizontalPadding()
                    #if os(tvOS)
                    .padding(.vertical, 24)
                    #else
                    .padding()
                    #endif
            }
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
    /// The controller pointer's own global values, kept in `ControllerPointerSettingsStore`.
    @State private var pointer = ControllerPointerSettingsStore.shared.settings(for: .global)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Input source picker
            inputSourcePicker

            RetroSettingsDivider()

            // Light gun crosshair style
            crosshairStylePicker

            RetroSettingsDivider()

            // Global sensitivity
            sensitivitySlider(
                title: "Mouse Sensitivity",
                subtitle: "Multiplier for all mouse delta events",
                value: $sensitivity
            )

            accelerationSlider

            RetroSettingsDivider()

            // A controller's gyro moves the same pointer as its touchpad, in every pointer role.
            toggle("Aim with Controller Gyro", systemImage: "gyroscope", isOn: $gyroMouseEnabled)

            if gyroMouseEnabled {
                sensitivitySlider(
                    title: "Gyro Sensitivity",
                    subtitle: "How far the pointer moves when you turn the controller",
                    value: $gyroSensitivity
                )

                deadZoneSlider

                toggle("Invert Gyro Left–Right", systemImage: "arrow.left.and.right",
                       isOn: pointerBinding(\.gyroInvertX))
                toggle("Invert Gyro Up–Down", systemImage: "arrow.up.and.down",
                       isOn: pointerBinding(\.gyroInvertY))
            }

            RetroSettingsDivider()

            toggle("Shake Controller to Shake Wii Remote", systemImage: "iphone.radiowaves.left.and.right",
                   isOn: pointerBinding(\.shake, default: true))
            Picker("Wii Remote Tilt", selection: Binding(
                get: { pointer.wiiTilt ?? WiiTiltMode.off },
                set: { mode in
                    ControllerPointerSettingsStore.shared.update(.global) { $0.wiiTilt = mode }
                    pointer = ControllerPointerSettingsStore.shared.settings(for: .global)
                }
            )) {
                Text("Off").tag(WiiTiltMode.off)
                Text("Upright").tag(WiiTiltMode.upright)
                Text("Sideways").tag(WiiTiltMode.sideways)
            }
            Text("Hold the controller face up for neutral tilt.")
                .font(.retroSettingsRowSubtitle)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Controller pointer values

    /// A switch over one of the pointer store's global values. Off means "not set" so the default holds.
    private func pointerBinding(_ field: WritableKeyPath<ControllerPointerSettings, Bool?>,
                                default fallback: Bool = false) -> Binding<Bool> {
        Binding(
            get: { pointer[keyPath: field] ?? fallback },
            set: { isOn in
                let stored: Bool? = isOn == fallback ? nil : isOn
                ControllerPointerSettingsStore.shared.update(.global) { $0[keyPath: field] = stored }
                pointer = ControllerPointerSettingsStore.shared.settings(for: .global)
            })
    }

    private var accelerationBinding: Binding<Double> {
        Binding(
            get: { pointer.acceleration ?? PointerSpeedCurve().acceleration },
            set: { value in
                ControllerPointerSettingsStore.shared.update(.global) { $0.acceleration = value }
                pointer = ControllerPointerSettingsStore.shared.settings(for: .global)
            })
    }

    private var accelerationSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Touchpad Acceleration", systemImage: "hand.draw")
                    .font(.retroSettingsLabel)
                    .foregroundColor(labelColor)
                Spacer()
                Text(String(format: "%.0f%%", accelerationBinding.wrappedValue * 100))
                    .font(.retroSettingsValue)
                    .foregroundColor(.retroBlue)
            }
            Text("Fast swipes on a controller touchpad travel further. Slide two fingers to change speed in game.")
                .font(.retroSettingsRowSubtitle)
                .foregroundColor(.secondary)
            RetroWaveSlider(value: accelerationBinding, in: PointerSpeedCurve.accelerationRange, step: 0.05)
                .accentColor(.retroBlue)
                #if os(tvOS)
                .padding(.bottom, 8)
                #endif
        }
    }

    private func toggle(_ title: LocalizedStringKey, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: systemImage)
                .font(.retroSettingsLabel)
                .foregroundColor(labelColor)
        }
        .tint(.retroBlue)
        #if os(tvOS)
        .retroThemedFocus()
        #endif
    }

    private var labelColor: Color {
        themeManager.currentPalette.settingsCellText?.swiftUIColor
            ?? themeManager.currentPalette.gameLibraryText.swiftUIColor
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
