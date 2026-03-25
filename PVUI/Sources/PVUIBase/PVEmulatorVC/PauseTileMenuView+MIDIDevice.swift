//
//  PauseTileMenuView+MIDIDevice.swift
//  PVUI
//
//  MIDI device picker sheet for the tile-based pause menu.
//  Reuses MIDIPickerSectionView from RetroMenuView+MIDIPicker.swift.
//  Only shown when the active core supports MIDI (iOS/Mac only).
//

import SwiftUI
import PVThemes

#if canImport(CoreMIDI) && !os(tvOS)
import CoreMIDI

// MARK: - MIDIDevicePauseSheet

/// Sheet that shows the MIDI input/output device picker.
/// Displayed when the user taps the "MIDI Device" tile in PauseTileMenuView.
@available(iOS 14.0, macCatalyst 14.0, *)
struct MIDIDevicePauseSheet: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    private var palette: UXThemePalette { themeManager.currentPalette }

    var body: some View {
        NavigationStack {
            ScrollView {
                MIDIPickerSectionView(palette: palette)
                    .padding()
            }
            .background(Color(palette.gameLibraryBackground).ignoresSafeArea())
            .navigationTitle(String(localized: "MIDI Device"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
