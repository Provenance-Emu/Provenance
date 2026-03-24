//
//  ExternalDisplaySettingsView.swift
//  PVUI
//
//  Created by Provenance Emu on 2026-03-24.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Settings view for external / connected-display configuration.
//  Presented via NavigationLink from the Video section.
//

import SwiftUI
import PVSettings
import Defaults
import PVThemes

// MARK: - ExternalDisplaySettingsView (navigation destination)

/// Full-page settings view for external display mode.
struct ExternalDisplaySettingsView: View {
    var body: some View {
        ScrollView {
            ExternalDisplaySection()
                .padding()
        }
        .navigationTitle("External Display")
    }
}

// MARK: - ExternalDisplaySection (embeddable)

/// Embeddable section shown inside a `CollapsibleSection` or directly in a `Form`.
struct ExternalDisplaySection: View {
    @Default(.externalDisplayMode) private var displayMode
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            modePicker
            modeDescription
        }
    }

    // MARK: Private

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display Mode")
                .font(.headline)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

            ForEach(ExternalDisplayMode.allCases, id: \.self) { mode in
                Button {
                    displayMode = mode
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: mode.symbolName)
                            .frame(width: 28)
                            .foregroundColor(displayMode == mode ? .accentColor : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName)
                                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            Text(mode.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if displayMode == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var modeDescription: some View {
        Group {
            if displayMode == .dedicated {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.orange)
                    Text("Dedicated mode only works with standard Metal cores. RetroArch, Dolphin, PPSSPP, Play!, and emuThreeDS automatically fall back to system mirroring.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}

#if DEBUG
struct ExternalDisplaySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExternalDisplaySettingsView()
        }
    }
}
#endif
