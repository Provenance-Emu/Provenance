//
//  PauseTileMenuView+PortDevices.swift
//  PVUI
//
//  Port device type picker sheet for the tile-based pause menu.
//  Reuses PortDeviceRow from RetroMenuView+PortDevicePicker.swift.
//  Only shown when the active core conforms to PortDeviceConfigurable and has ports.
//

import SwiftUI
import PVCoreBridge
import PVThemes

// MARK: - PortDevicesPauseSheet

/// Sheet that shows per-port controller device type pickers.
/// Displayed when the user taps the "Port Devices" tile in PauseTileMenuView.
struct PortDevicesPauseSheet: View {
    let emulatorVC: PVEmulatorViewController
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    private var palette: UXThemePalette { themeManager.currentPalette }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if let core = emulatorVC.core as? (any PortDeviceConfigurable) {
                        ForEach(Array(core.controllerPortDescriptors.enumerated()), id: \.offset) { portIndex, descriptors in
                            PortDeviceRow(
                                portIndex: portIndex,
                                descriptors: descriptors,
                                currentDeviceType: core.currentDeviceType(forPort: portIndex),
                                palette: palette,
                                onSelect: { deviceType in
                                    core.setDeviceType(deviceType, forPort: portIndex)
                                }
                            )
                        }
                    } else {
                        Text(String(localized: "No configurable ports available."))
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .background(Color(palette.gameLibraryBackground).ignoresSafeArea())
            .navigationTitle(String(localized: "Port Devices"))
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if os(tvOS)
        // On tvOS the hardware Menu button is the standard way to dismiss sheets.
        .onExitCommand { dismiss() }
        #endif
    }
}
