//
//  ThemedToggle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVThemes

struct ThemedToggle<Label: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var isOn: Bool
    @ViewBuilder let label: () -> Label

    var body: some View {
        Toggle(isOn: $isOn) {
            label()
        }
#if !os(tvOS)
        .toggleStyle(SwitchThemedToggleStyle(tint: themeManager.currentPalette.switchON?.swiftUIColor ?? .white))
        .onAppear {
            UISwitch.appearance().thumbTintColor = themeManager.currentPalette.switchThumb
        }
#endif
    }
}
