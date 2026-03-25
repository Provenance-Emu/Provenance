//
//  RetroMenuView+MIDIPicker.swift
//  PVUI
//
//  Created by Claude (Agent) on 2026-03-21.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  MIDI device picker section for the pause / retro menu.
//
//  Features:
//  - Lists available MIDI input sources and output destinations
//  - Live TX (transmit) and RX (receive) activity indicator lights
//  - "Press a key" auto-detect: waits for first MIDI input and selects
//    its source automatically
//  - Shown only when the active core advertises MIDI support
//

import SwiftUI
import PVCoreBridge
import PVEmulatorCore
import PVSettings
import PVThemes
#if canImport(CoreMIDI) && !os(tvOS)
import CoreMIDI
#endif

// MARK: - RetroMenuView extension

extension RetroMenuView {

    /// True when the active core reports MIDI peripheral support.
    var coreSupportsMIDI: Bool {
        emulatorVC.core.supportsMIDI
    }

    /// MIDI section shown inside the CORE tab when the core supports MIDI.
    /// Only rendered on platforms that ship CoreMIDI.
    @ViewBuilder
    var midiPickerSection: some View {
#if canImport(CoreMIDI) && !os(tvOS)
        if coreSupportsMIDI {
            MIDIPickerSectionView(palette: ThemeManager.shared.currentPalette)
        }
#else
        EmptyView()
#endif
    }

    /// Toggle section for the RetroArch-level MIDI driver, shown in the CORE tab
    /// for libretro cores on MIDI-capable systems.
    /// The setting is applied to `retroarch.cfg` on the next session start.
    @ViewBuilder
    var retroArchMIDISection: some View {
#if canImport(CoreMIDI) && !os(tvOS)
        if isRetroArchMIDICapable {
            RetroArchMIDIToggleView(palette: ThemeManager.shared.currentPalette)
        }
#else
        EmptyView()
#endif
    }
}

// MARK: - MIDIPickerSectionView

#if canImport(CoreMIDI) && !os(tvOS)
/// Stand-alone section view that owns the `@ObservedObject` for `MIDIDeviceManager`.
struct MIDIPickerSectionView: View {
    let palette: UXThemePalette

    @ObservedObject private var midi = MIDIDeviceManager.shared

    var body: some View {
        VStack(spacing: 8) {
            // Section header + activity lights
            HStack(spacing: 6) {
                Image(systemName: "pianokeys")
                    .font(.system(size: 10, weight: .bold))
                Text(String(localized: "MIDI DEVICE"))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                Spacer()
                ActivityLight(active: midi.rxActivity, label: "RX", color: .green)
                ActivityLight(active: midi.txActivity, label: "TX", color: .orange)
            }
            .foregroundColor(sectionHeaderColor)
            .padding(.top, 6)

            // Input source picker (single-select convenience view).
            // multipleSelectedCount lets the row surface "Multiple" when more than one
            // source is selected via the Quick Settings multi-select picker.
            // emptySelectionLabel is "All" because an empty source set means auto-detect
            // (listen to all available MIDI sources), not "disabled".
            MIDIEndpointRow(
                label: String(localized: "INPUT"),
                symbolName: "arrow.down.circle",
                endpoints: midi.sources,
                selectedID: Binding(
                    get: { midi.selectedSourceID },
                    set: { midi.selectedSourceID = $0 }
                ),
                multipleSelectedCount: midi.selectedSourceIDs.count,
                emptySelectionLabel: String(localized: "All"),
                palette: palette
            )

            // Output destination picker (single-select convenience view).
            MIDIEndpointRow(
                label: String(localized: "OUTPUT"),
                symbolName: "arrow.up.circle",
                endpoints: midi.destinations,
                selectedID: Binding(
                    get: { midi.selectedDestinationID },
                    set: { midi.selectedDestinationID = $0 }
                ),
                multipleSelectedCount: midi.selectedDestinationIDs.count,
                palette: palette
            )

            // "Press any key" auto-detect
            AutoDetectButton(midi: midi, palette: palette)
        }
    }

    private var sectionHeaderColor: Color {
        (palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
            .opacity(0.55)
    }
}

// MARK: - ActivityLight

/// Pulsing coloured dot that lights up on MIDI activity.
private struct ActivityLight: View {
    let active: Bool
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(active ? color : color.opacity(0.18))
                .frame(width: 7, height: 7)
                .animation(.easeOut(duration: 0.1), value: active)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(active ? color : color.opacity(0.35))
        }
    }
}

// MARK: - MIDIEndpointRow

/// Expandable row for selecting a MIDI input source or output destination.
private struct MIDIEndpointRow: View {
    let label: String
    let symbolName: String
    let endpoints: [MIDIEndpointInfo]
    @Binding var selectedID: MIDIUniqueID?
    /// Total number of selected IDs from the backing multi-select set.
    /// Used to distinguish "Multiple devices selected" from "None/All selected" when
    /// `selectedID` is nil (which happens whenever count != 1).
    var multipleSelectedCount: Int = 0
    /// Label shown when no specific device is selected (empty set).
    /// Use "All" for INPUT (empty = listen to all sources) and "None" for OUTPUT (empty = disabled).
    var emptySelectionLabel: String = String(localized: "None")
    let palette: UXThemePalette

    @State private var expanded = false

    private var selectedName: String {
        if let id = selectedID {
            return endpoints.first { $0.id == id }?.name ?? emptySelectionLabel
        } else if multipleSelectedCount > 1 {
            return String(format: String(localized: "Multiple (%d)"), multipleSelectedCount)
        }
        return emptySelectionLabel
    }

    var body: some View {
        VStack(spacing: 3) {
            // Row header — tap to expand / collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            }) {
                HStack {
                    Image(systemName: symbolName)
                        .font(.system(size: 13))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                        .frame(width: 22)

                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(palette.gameLibraryText.swiftUIColor)

                    Spacer()

                    Text(selectedName)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(secondaryTextColor.opacity(0.7))
                        .lineLimit(1)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor.opacity(0.6))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(rowBackground())
            }
            .buttonStyle(.plain)

            // Device list — shown when expanded
            if expanded {
                VStack(spacing: 2) {
                    EndpointOptionRow(
                        name: emptySelectionLabel,
                        isSelected: selectedID == nil,
                        palette: palette
                    ) {
                        selectedID = nil
                        withAnimation { expanded = false }
                    }
                    ForEach(endpoints) { endpoint in
                        EndpointOptionRow(
                            name: endpoint.name,
                            isSelected: endpoint.id == selectedID,
                            palette: palette
                        ) {
                            selectedID = endpoint.id
                            withAnimation { expanded = false }
                        }
                    }
                    if endpoints.isEmpty {
                        Text(String(localized: "No devices found"))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.4))
                            .padding(.vertical, 6)
                    }
                }
                .padding(.leading, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // Collapse automatically when selection changes from outside (e.g. auto-detect)
        .onChange(of: selectedID) { _ in
            if expanded { withAnimation { expanded = false } }
        }
    }

    private var secondaryTextColor: Color {
        palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor
    }

    private func rowBackground() -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(palette.defaultTintColor.swiftUIColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        palette.defaultTintColor.swiftUIColor.opacity(0.25),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - EndpointOptionRow

private struct EndpointOptionRow: View {
    let name: String
    let isSelected: Bool
    let palette: UXThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(
                        isSelected
                        ? palette.defaultTintColor.swiftUIColor
                        : palette.gameLibraryText.swiftUIColor.opacity(0.8)
                    )
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
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

// MARK: - AutoDetectButton

/// "Press any key on your MIDI device" auto-select control.
private struct AutoDetectButton: View {
    @ObservedObject var midi: MIDIDeviceManager
    let palette: UXThemePalette

    var body: some View {
        Button(action: toggleAutoDetect) {
            HStack(spacing: 6) {
                Image(systemName: midi.isAutoDetecting ? "stop.circle" : "hand.point.up.braille")
                    .font(.system(size: 12))

                Text(
                    midi.isAutoDetecting
                    ? String(localized: "Press any key to identify device…")
                    : String(localized: "Auto-detect input device")
                )
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)

                if midi.isAutoDetecting {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(autoDetectBackground)
            .foregroundColor(
                midi.isAutoDetecting
                ? palette.defaultTintColor.swiftUIColor
                : palette.gameLibraryText.swiftUIColor.opacity(0.75)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: midi.isAutoDetecting)
    }

    private func toggleAutoDetect() {
        if midi.isAutoDetecting {
            midi.cancelAutoDetect()
        } else {
            midi.startAutoDetect()
        }
    }

    private var autoDetectBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(
                midi.isAutoDetecting
                ? palette.defaultTintColor.swiftUIColor.opacity(0.12)
                : palette.defaultTintColor.swiftUIColor.opacity(0.06)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        palette.defaultTintColor.swiftUIColor.opacity(
                            midi.isAutoDetecting ? 0.4 : 0.15
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - RetroArchMIDIToggleView

/// Toggle that enables or disables the RetroArch CoreMIDI driver for the next session.
/// Writes to `Defaults[.retroArchMIDIEnabled]`; the Obj-C `applyMIDIPreferenceToUserCfg:`
/// method reads this key at core startup and patches `retroarch.cfg` accordingly.
struct RetroArchMIDIToggleView: View {
    let palette: UXThemePalette

    @Default(.retroArchMIDIEnabled) private var midiEnabled

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "pianokeys")
                    .font(.system(size: 10, weight: .bold))
                Text(String(localized: "RETROARCH MIDI"))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                Spacer()
            }
            .foregroundColor(headerColor)
            .padding(.top, 6)

            Toggle(isOn: $midiEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: midiEnabled ? "waveform.path" : "waveform.path.badge.minus")
                        .font(.system(size: 13))
                        .foregroundColor(palette.defaultTintColor.swiftUIColor)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "Enable MIDI Driver"))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(palette.gameLibraryText.swiftUIColor)
                        Text(String(localized: "Applies on next session start"))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(palette.gameLibraryText.swiftUIColor.opacity(0.5))
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: palette.defaultTintColor.swiftUIColor))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(palette.defaultTintColor.swiftUIColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                palette.defaultTintColor.swiftUIColor.opacity(0.25),
                                lineWidth: 1
                            )
                    )
            )
        }
    }

    private var headerColor: Color {
        (palette.settingsCellTextDetail?.swiftUIColor ?? palette.gameLibraryText.swiftUIColor)
            .opacity(0.55)
    }
}

#endif // canImport(CoreMIDI) && !os(tvOS)
