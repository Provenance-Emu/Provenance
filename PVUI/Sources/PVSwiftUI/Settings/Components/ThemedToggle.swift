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
    let label: Label

    init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self._isOn = isOn
        self.label = label()
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            label
        }
        .toggleStyle(SwitchThemedToggleStyle(tint: themeManager.currentPalette.switchON?.swiftUIColor ?? .white))
        .onAppear {
            UISwitch.appearance().thumbTintColor = themeManager.currentPalette.switchThumb
        }
    }
}
