//
//  RetroMenuView+PortDevicePicker.swift
//  PVUI
//
//  Created by Claude (Agent) on 2026-03-17.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Per-port controller device type picker for the pause menu.
//  Mirrors RetroArch's Input > Port N Device Type menu.
//

import SwiftUI
import PVCoreBridge
import PVThemes

// MARK: - RetroMenuView extension

extension RetroMenuView {

    /// Returns the core cast to PortDeviceConfigurable if it conforms, else nil.
    var portDeviceCore: (any PortDeviceConfigurable)? {
        emulatorVC.core as? (any PortDeviceConfigurable)
    }

    /// True when the core has controller port info to display.
    var hasPortDeviceOptions: Bool {
        guard let core = portDeviceCore else { return false }
        return !core.controllerPortDescriptors.isEmpty
    }

    // Convenience accessor for palette without requiring private access to `palette`.
    private var portDevicePalette: UXThemePalette { ThemeManager.shared.currentPalette }

    /// Section shown inside the CORE tab when the core supports per-port device types.
    @ViewBuilder
    var portDevicePickerSection: some View {
        let pal = portDevicePalette
        if let core = portDeviceCore, !core.controllerPortDescriptors.isEmpty {
            VStack(spacing: 8) {
                // Section header
                HStack(spacing: 5) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 10, weight: .bold))
                    Text(String(localized: "PORT DEVICE TYPES"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                }
                .foregroundColor((pal.settingsCellTextDetail?.swiftUIColor ?? pal.gameLibraryText.swiftUIColor).opacity(0.55))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)

                ForEach(Array(core.controllerPortDescriptors.enumerated()), id: \.offset) { portIndex, descriptors in
                    PortDeviceRow(
                        portIndex: portIndex,
                        descriptors: descriptors,
                        currentDeviceType: core.currentDeviceType(forPort: portIndex),
                        palette: pal,
                        onSelect: { deviceType in
                            core.setDeviceType(deviceType, forPort: portIndex)
                        }
                    )
                }
            }
        }
    }
}

// MARK: - PortDeviceRow

/// A single row showing one controller port and a picker for its device type.
private struct PortDeviceRow: View {
    let portIndex: Int
    let descriptors: [PortDeviceDescriptor]
    let initialDeviceType: UInt
    let palette: UXThemePalette
    let onSelect: (UInt) -> Void

    @State private var expanded: Bool = false
    @State private var selectedDeviceType: UInt

    init(portIndex: Int, descriptors: [PortDeviceDescriptor], currentDeviceType: UInt,
         palette: UXThemePalette, onSelect: @escaping (UInt) -> Void) {
        self.portIndex = portIndex
        self.descriptors = descriptors
        self.initialDeviceType = currentDeviceType
        self.palette = palette
        self.onSelect = onSelect
        _selectedDeviceType = State(initialValue: currentDeviceType)
    }

    private var currentDescriptor: PortDeviceDescriptor? {
        descriptors.first { $0.deviceType == selectedDeviceType }
    }

    private var portLabel: String {
        String(localized: "PORT \(portIndex + 1)")
    }

    var body: some View {
        VStack(spacing: 4) {
            // Row header — tap to expand/collapse picker
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                HStack {
                    Image(systemName: deviceSymbol(for: selectedDeviceType))
                        .font(.system(size: 14))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                        .frame(width: 24)

                    Text(portLabel)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(palette.gameLibraryText.swiftUIColor)

                    Spacer()

                    Text(currentDescriptor?.name ?? deviceFallbackName(selectedDeviceType))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.7))
                        .lineLimit(1)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(palette.defaultTintColor.swiftUIColor.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(palette.defaultTintColor.swiftUIColor.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // Picker list — shown when expanded
            if expanded {
                VStack(spacing: 3) {
                    ForEach(descriptors, id: \.deviceType) { descriptor in
                        let isSelected = descriptor.deviceType == selectedDeviceType
                        Button(action: {
                            selectedDeviceType = descriptor.deviceType
                            onSelect(descriptor.deviceType)
                            withAnimation(.easeInOut(duration: 0.15)) { expanded = false }
                        }) {
                            HStack {
                                Image(systemName: deviceSymbol(for: descriptor.deviceType))
                                    .font(.system(size: 12))
                                    .foregroundColor(
                                        isSelected
                                        ? palette.defaultTintColor.swiftUIColor
                                        : palette.gameLibraryText.swiftUIColor.opacity(0.6)
                                    )
                                    .frame(width: 20)

                                Text(descriptor.name)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(
                                        isSelected
                                        ? palette.defaultTintColor.swiftUIColor
                                        : palette.gameLibraryText.swiftUIColor.opacity(0.8)
                                    )

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        isSelected
                                        ? palette.defaultTintColor.swiftUIColor.opacity(0.15)
                                        : Color.clear
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func deviceSymbol(for deviceType: UInt) -> String {
        switch LibretroDeviceType(rawValue: deviceType) {
        case .joypad:   return "gamecontroller"
        case .mouse:    return "computermouse"
        case .keyboard: return "keyboard"
        case .lightgun: return "scope"
        case .analog:   return "gamecontroller.fill"
        case .pointer:  return "hand.point.up"
        case .none:     return "nosign"
        default:        return "gamecontroller"
        }
    }

    private func deviceFallbackName(_ deviceType: UInt) -> String {
        LibretroDeviceType(rawValue: deviceType)?.localizedName ?? "Device \(deviceType)"
    }
}
