//
//  ICadeControllerView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import Defaults
import PVSettings
import PVThemes
import PVUIBase

/// Settings → Controllers → iCade / 8Bitdo: picks which iCade-protocol controller is paired.
struct ICadeControllerView: View {
    @Default(.myiCadeControllerSetting) private var selection

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared

    private var accentColor: Color {
        themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .accentColor
    }

    var body: some View {
        List {
            Section {
                ForEach(iCadeControllerSetting.allCases, id: \.self) { setting in
                    Button {
                        select(setting)
                    } label: {
                        HStack {
                            Text(setting.description)
                                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            Spacer()
                            if selection == setting {
                                Image(systemName: "checkmark")
                                    .foregroundColor(accentColor)
                            }
                        }
                    }
                    #if os(tvOS)
                    .retroFocusButtonStyle(showBorder: false)
                    #endif
                }
            } header: {
                Text("Supported iCade Controllers")
            } footer: {
                Text("Controllers must be paired with device.")
            }
        }
        #if os(tvOS)
        .listStyle(.plain)
        .background { RetroSettingsBackground() }
        .tvOSSettingsHorizontalPadding()
        #else
        .listStyle(.insetGrouped)
        #endif
        .navigationTitle("iCade / 8Bitdo")
        #if os(tvOS)
        .focusSection()
        .onExitCommand { dismiss() }
        #endif
        .settingsSubpageTracking()
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func select(_ setting: iCadeControllerSetting) {
        selection = setting
        PVControllerManager.shared.resetICadeController()
        dismiss()
    }
}
