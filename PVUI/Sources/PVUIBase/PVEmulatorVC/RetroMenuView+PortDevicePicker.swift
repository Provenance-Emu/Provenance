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

// MARK: - Platform-aware metrics

/// Font sizes and paddings for the Port Device picker rows.
/// tvOS values are sized for 10-foot legibility; iOS values match the
/// historical compact pause-menu styling.
private enum PortDeviceRowMetrics {
    #if os(tvOS)
    static let sectionLabel: CGFloat = 20
    static let sectionIcon: CGFloat = 18
    static let portLabel: CGFloat = 22
    static let valueText: CGFloat = 20
    static let pickerItem: CGFloat = 20
    static let pickerIcon: CGFloat = 20
    static let chevron: CGFloat = 18
    static let rowVerticalPadding: CGFloat = 16
    static let rowHorizontalPadding: CGFloat = 22
    static let pickerVerticalPadding: CGFloat = 12
    static let pickerHorizontalPadding: CGFloat = 24
    static let mainIconWidth: CGFloat = 32
    static let pickerIconWidth: CGFloat = 28
    #else
    static let sectionLabel: CGFloat = 11
    static let sectionIcon: CGFloat = 10
    static let portLabel: CGFloat = 13
    static let valueText: CGFloat = 12
    static let pickerItem: CGFloat = 12
    static let pickerIcon: CGFloat = 12
    static let chevron: CGFloat = 11
    static let rowVerticalPadding: CGFloat = 10
    static let rowHorizontalPadding: CGFloat = 14
    static let pickerVerticalPadding: CGFloat = 8
    static let pickerHorizontalPadding: CGFloat = 18
    static let mainIconWidth: CGFloat = 24
    static let pickerIconWidth: CGFloat = 20
    #endif
}

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
                        .font(.system(size: PortDeviceRowMetrics.sectionIcon, weight: .bold))
                    Text(String(localized: "PORT DEVICE TYPES"))
                        .font(.system(size: PortDeviceRowMetrics.sectionLabel, weight: .bold, design: .monospaced))
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
struct PortDeviceRow: View {
    let portIndex: Int
    let descriptors: [PortDeviceDescriptor]
    /// External source of truth — used to re-sync `selectedDeviceType` if the core
    /// changes the device type independently while the menu is open.
    let currentDeviceType: UInt
    let palette: UXThemePalette
    let onSelect: (UInt) -> Void

    @State private var expanded: Bool = false
    @State private var selectedDeviceType: UInt
    /// Tracks focus across the main expand/collapse button and each picker-item button.
    /// Stable IDs let us light up the appropriate row tint on focus and survive
    /// list re-renders when the picker expands.
    @FocusState private var focusedID: String?

    init(portIndex: Int, descriptors: [PortDeviceDescriptor], currentDeviceType: UInt,
         palette: UXThemePalette, onSelect: @escaping (UInt) -> Void) {
        self.portIndex = portIndex
        self.descriptors = descriptors
        self.currentDeviceType = currentDeviceType
        self.palette = palette
        self.onSelect = onSelect
        _selectedDeviceType = State(initialValue: currentDeviceType)
    }

    private var currentDescriptor: PortDeviceDescriptor? {
        descriptors.first { $0.deviceType == selectedDeviceType }
    }

    private var portLabel: String {
        String(format: NSLocalizedString("Port %d", comment: "Controller port label (e.g. Port 1)"), portIndex + 1).uppercased()
    }

    private var mainID: String { "port_\(portIndex)_main" }
    private func itemID(_ deviceType: UInt) -> String { "port_\(portIndex)_item_\(deviceType)" }

    var body: some View {
        let isMainFocused = focusedID == mainID

        VStack(spacing: 4) {
            // Row header — tap to expand/collapse picker
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }) {
                HStack {
                    Image(systemName: deviceSymbol(for: selectedDeviceType))
                        .font(.system(size: PortDeviceRowMetrics.portLabel))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                        .frame(width: PortDeviceRowMetrics.mainIconWidth)

                    Text(portLabel)
                        .font(.system(size: PortDeviceRowMetrics.portLabel, weight: .semibold, design: .monospaced))
                        .foregroundColor(palette.gameLibraryText.swiftUIColor)

                    Spacer()

                    Text(currentDescriptor?.name ?? deviceFallbackName(selectedDeviceType))
                        .font(.system(size: PortDeviceRowMetrics.valueText, design: .monospaced))
                        .foregroundColor((palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor).opacity(0.7))
                        .lineLimit(1)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: PortDeviceRowMetrics.chevron))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.7))
                }
                .padding(.horizontal, PortDeviceRowMetrics.rowHorizontalPadding)
                .padding(.vertical, PortDeviceRowMetrics.rowVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(palette.defaultTintColor.swiftUIColor.opacity(isMainFocused ? 0.18 : 0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    palette.defaultTintColor.swiftUIColor.opacity(isMainFocused ? 0.6 : 0.25),
                                    lineWidth: isMainFocused ? 1.5 : 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .focused($focusedID, equals: mainID)
            .tvOSDisableFocusEffect()
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isMainFocused)

            // Picker list — shown when expanded
            if expanded {
                VStack(spacing: 3) {
                    ForEach(descriptors, id: \.deviceType) { descriptor in
                        let isSelected = descriptor.deviceType == selectedDeviceType
                        let id = itemID(descriptor.deviceType)
                        let isItemFocused = focusedID == id

                        Button(action: {
                            selectedDeviceType = descriptor.deviceType
                            onSelect(descriptor.deviceType)
                            withAnimation(.easeInOut(duration: 0.15)) { expanded = false }
                        }) {
                            HStack {
                                Image(systemName: deviceSymbol(for: descriptor.deviceType))
                                    .font(.system(size: PortDeviceRowMetrics.pickerIcon))
                                    .foregroundColor(
                                        isSelected
                                        ? palette.defaultTintColor.swiftUIColor
                                        : palette.gameLibraryText.swiftUIColor.opacity(0.6)
                                    )
                                    .frame(width: PortDeviceRowMetrics.pickerIconWidth)

                                Text(descriptor.name)
                                    .font(.system(size: PortDeviceRowMetrics.pickerItem, design: .monospaced))
                                    .foregroundColor(
                                        isSelected
                                        ? palette.defaultTintColor.swiftUIColor
                                        : palette.gameLibraryText.swiftUIColor.opacity(0.8)
                                    )

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: PortDeviceRowMetrics.chevron, weight: .bold))
                                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                                }
                            }
                            .padding(.horizontal, PortDeviceRowMetrics.pickerHorizontalPadding)
                            .padding(.vertical, PortDeviceRowMetrics.pickerVerticalPadding)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        isItemFocused
                                        ? palette.defaultTintColor.swiftUIColor.opacity(0.18)
                                        : (isSelected ? palette.defaultTintColor.swiftUIColor.opacity(0.15) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(
                                                palette.defaultTintColor.swiftUIColor.opacity(isItemFocused ? 0.6 : 0.0),
                                                lineWidth: isItemFocused ? 1.5 : 0
                                            )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .focused($focusedID, equals: id)
                        .tvOSDisableFocusEffect()
                        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: isItemFocused)
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: currentDeviceType) { newValue in
            selectedDeviceType = newValue
        }
    }

    private func deviceSymbol(for deviceType: UInt) -> String {
        // Mask off subclass bits (RETRO_DEVICE_SUBCLASS encodes extra info above bit 7).
        let baseType = deviceType & LibretroDeviceType.deviceMask
        return LibretroDeviceType(rawValue: baseType)?.symbolName ?? "gamecontroller"
    }

    private func deviceFallbackName(_ deviceType: UInt) -> String {
        let baseType = deviceType & LibretroDeviceType.deviceMask
        return LibretroDeviceType(rawValue: baseType)?.localizedName ?? "Device \(deviceType)"
    }
}
