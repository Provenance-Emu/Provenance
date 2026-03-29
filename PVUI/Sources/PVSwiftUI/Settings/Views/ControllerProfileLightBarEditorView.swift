//
//  ControllerProfileLightBarEditorView.swift
//  PVUI
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import GameController
import PVCoreBridge
import PVLibrary
import PVLogging
import PVRealm
import PVThemes
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Edits optional light bar color on a `PVControllerProfile` (DualSense / DualShock 4).
struct ControllerProfileLightBarEditorView: View {

    let controller: GCController
    let profileID: String
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    @State private var useCustomColor = false
    @State private var selectedHex: String = "#FFFFFF"
    @State private var pickerColor = Color.white

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    /// Named palette rows (shared with built-in system colors where applicable).
    private static let presets: [(label: String, color: ControllerLightBarManager.LightBarColor)] = [
        ("PlayStation blue", .playstationBlue),
        ("SNES purple", .snesPurple),
        ("Game Boy green", .gameBoyGreen),
        ("NES gray", .nesGray),
        ("N64 blue", .n64Blue),
        ("Sega blue", .segaBlue),
        ("Dreamcast orange", .dreamcastOrange),
        ("GBA purple", .gbaPurple),
        ("GameCube indigo", .gameCubeIndigo),
        ("Xbox green", .xboxGreen),
        ("Atari gold", .atariGold),
        ("Warm white", .default),
        ("Off", .off)
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Custom light bar color", isOn: $useCustomColor)
            } footer: {
                Text("When off, this profile does not override color; Settings and the current system decide.")
            }

            if useCustomColor {
                presetSection
                #if !os(tvOS)
                colorPickerSection
                #endif
            }
        }
        .navigationTitle("Light Bar")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .foregroundColor(accentColor)
            }
        }
        .onAppear(perform: loadFromRealm)
        #if os(tvOS)
        .settingsSubpageTracking()
        #endif
        .onChange(of: useCustomColor) { _, isOn in
            if isOn, ControllerLightBarManager.LightBarColor(hex: selectedHex) == nil {
                selectedHex = ControllerLightBarManager.LightBarColor.default.hexString
                syncPickerFromHex()
            }
        }
    }

    @ViewBuilder
    private var presetSection: some View {
        Section("Presets") {
            ForEach(Array(Self.presets.enumerated()), id: \.offset) { _, item in
                Button(item.label) {
                    selectedHex = item.color.hexString
                    syncPickerFromHex()
                }
                .foregroundColor(.primary)
            }
        }
    }

    #if !os(tvOS)
    private var colorPickerSection: some View {
        Section("Picker") {
            ColorPicker("Color", selection: $pickerColor, supportsOpacity: false)
                .onChange(of: pickerColor) { _, new in
                    if let hex = Self.hexString(fromSwiftUIColor: new) {
                        selectedHex = hex
                    }
                }
        }
    }
    #endif

    /// Loads persisted hex and toggle state.
    private func loadFromRealm() {
        let db = RomDatabase.sharedInstance
        guard let live = db.controllerProfile(withID: profileID) else { return }
        if let hex = live.lightBarColorHex?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty,
           ControllerLightBarManager.LightBarColor(hex: hex) != nil {
            useCustomColor = true
            selectedHex = hex
        } else {
            useCustomColor = false
            selectedHex = ControllerLightBarManager.LightBarColor.default.hexString
        }
        syncPickerFromHex()
    }

    private func syncPickerFromHex() {
        guard let lb = ControllerLightBarManager.LightBarColor(hex: selectedHex) else { return }
        pickerColor = Color(red: Double(lb.red), green: Double(lb.green), blue: Double(lb.blue))
    }

    private func save() {
        let db = RomDatabase.sharedInstance
        guard let live = db.controllerProfile(withID: profileID) else { return }
        let hexToStore: String? = useCustomColor ? selectedHex.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        if useCustomColor, let h = hexToStore, ControllerLightBarManager.LightBarColor(hex: h) == nil {
            WLOG("ControllerProfileLightBarEditorView: invalid hex, not saving")
            return
        }
        do {
            try db.updateControllerProfileLightBarColor(live, hex: hexToStore)
            if live.isActive {
                if #available(iOS 14.0, tvOS 14.0, *) {
                    ControllerLightBarManager.shared.setProfileLightBarOverride(
                        controller: controller,
                        hex: hexToStore
                    )
                }
            }
            onSaved()
            dismiss()
        } catch {
            ELOG("ControllerProfileLightBarEditorView: save failed: \(error)")
        }
    }

    /// Converts a SwiftUI `Color` to `#RRGGBB` using the platform color bridge.
    private static func hexString(fromSwiftUIColor color: Color) -> String? {
#if canImport(UIKit) && (!os(macOS) || targetEnvironment(macCatalyst))
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return ControllerLightBarManager.LightBarColor(red: Float(r), green: Float(g), blue: Float(b)).hexString
#elseif canImport(AppKit)
        let ns = NSColor(color)
        guard let rgb = ns.usingColorSpace(.deviceRGB) else { return nil }
        return ControllerLightBarManager.LightBarColor(
            red: Float(rgb.redComponent),
            green: Float(rgb.greenComponent),
            blue: Float(rgb.blueComponent)
        ).hexString
#else
        return nil
#endif
    }
}
