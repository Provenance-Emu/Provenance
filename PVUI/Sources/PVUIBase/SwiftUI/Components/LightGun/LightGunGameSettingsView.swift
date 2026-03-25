//
//  LightGunGameSettingsView.swift
//  PVUIBase
//
//  Per-game light gun settings shown in the Game Info screen.
//  Only rendered for games whose system is registered as light-gun-capable.
//

import SwiftUI
import PVSettings
import Defaults

/// Compact SwiftUI card that lets users configure per-game light gun behavior.
///
/// Shows crosshair style, sensitivity, and auto-detect mode overrides.
/// Only meaningful for games on systems registered in `LightGunSystemRegistry`.
struct LightGunGameSettingsView: View {

    /// MD5 hash of the game — used as the persistence key.
    let gameMD5: String

    let accentColor: Color
    let backgroundColor: Color
    let borderGradient: LinearGradient

    @Default(.lightGunGameSettings) private var gameSettings
    @Default(.lightGunCrosshairStyle) private var globalCrosshairStyle
    @Default(.lightGunAutoDetect) private var globalAutoDetect
    @Default(.lightGunMouseSensitivity) private var globalSensitivity

    private var current: LightGunGameSettings {
        gameSettings[gameMD5] ?? LightGunGameSettings()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Image(systemName: "scope")
                    .foregroundColor(accentColor)
                Text("LIGHT GUN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accentColor)
                Spacer()
            }

            // Mode picker (auto / enabled / disabled)
            modeSection

            Divider()
                .background(accentColor.opacity(0.3))

            // Crosshair style picker
            crosshairSection

            Divider()
                .background(accentColor.opacity(0.3))

            // Sensitivity slider
            sensitivitySection
        }
        .padding(12)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderGradient, lineWidth: 1)
        )
    }

    // MARK: - Mode Section

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Mode")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            #if os(tvOS)
            Picker("Light Gun Mode", selection: Binding(
                get: { current.mode },
                set: { saveMode($0) }
            )) {
                ForEach(LightGunMode.allCases, id: \.self) { mode in
                    HStack {
                        Image(systemName: mode.sfSymbolName)
                        Text(mode.displayTitle)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.menu)
            #else
            Picker("Light Gun Mode", selection: Binding(
                get: { current.mode },
                set: { saveMode($0) }
            )) {
                ForEach(LightGunMode.allCases, id: \.self) { mode in
                    Label(mode.displayTitle, systemImage: mode.sfSymbolName)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            #endif

            Text(current.mode.displayDescription)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Crosshair Section

    private var crosshairSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Crosshair")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            #if os(tvOS)
            Picker("Crosshair Style", selection: Binding(
                get: { current.crosshairStyle ?? globalCrosshairStyle },
                set: { saveCrosshair($0) }
            )) {
                ForEach(LightGunCrosshairStyle.allCases, id: \.self) { style in
                    HStack {
                        Image(systemName: style.sfSymbolName)
                        Text(style.displayTitle)
                    }
                    .tag(style)
                }
            }
            .pickerStyle(.menu)
            #else
            Picker("Crosshair Style", selection: Binding(
                get: { current.crosshairStyle ?? globalCrosshairStyle },
                set: { saveCrosshair($0) }
            )) {
                ForEach(LightGunCrosshairStyle.allCases, id: \.self) { style in
                    Label(style.displayTitle, systemImage: style.sfSymbolName)
                        .tag(style)
                }
            }
            .pickerStyle(.segmented)
            #endif

            if current.crosshairStyle != nil {
                Button("Reset to Global Default") {
                    saveCrosshair(nil)
                }
                .font(.system(size: 11))
                .foregroundColor(accentColor)
            }
        }
    }

    // MARK: - Sensitivity Section

    private var sensitivitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sensitivity")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.1f×", current.sensitivityOverride ?? globalSensitivity))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(.secondary)
            }

            Slider(
                value: Binding(
                    get: { current.sensitivityOverride ?? globalSensitivity },
                    set: { saveSensitivity($0) }
                ),
                in: 0.1...5.0,
                step: 0.1
            )
            .tint(accentColor)

            HStack {
                Text("Slow")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Text("Fast")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if current.sensitivityOverride != nil {
                Button("Reset to Global Default") {
                    saveSensitivity(nil)
                }
                .font(.system(size: 11))
                .foregroundColor(accentColor)
            }
        }
    }

    // MARK: - Persistence

    private func saveMode(_ mode: LightGunMode) {
        var settings = current
        settings.mode = mode
        persist(settings)
    }

    private func saveCrosshair(_ style: LightGunCrosshairStyle?) {
        var settings = current
        settings.crosshairStyle = style
        persist(settings)
    }

    private func saveSensitivity(_ value: Double?) {
        var settings = current
        settings.sensitivityOverride = value
        persist(settings)
    }

    private func persist(_ settings: LightGunGameSettings) {
        if settings.isDefault {
            gameSettings.removeValue(forKey: gameMD5)
        } else {
            gameSettings[gameMD5] = settings
        }
    }
}
