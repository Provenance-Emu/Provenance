//
//  PremiumThemedToggle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import UIKit
import FreemiumKit
import PVThemes

struct PremiumThemedToggle<Label: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding var isOn: Bool
    let label: Label

    init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {
        self._isOn = isOn
        self.label = label()
    }

#if canImport(FreemiumKit)
    var body: some View {
        PaidFeatureView {
            Toggle(isOn: $isOn) {
                label
            }
            .toggleStyle(SwitchThemedToggleStyle(tint: themeManager.currentPalette.switchON?.swiftUIColor ?? .white))
            .onAppear {
                UISwitch.appearance().thumbTintColor = themeManager.currentPalette.switchThumb
            }
        } lockedView: {
            Toggle(isOn: $isOn) {
                label
            }
            .toggleStyle(SwitchThemedToggleStyle(tint: themeManager.currentPalette.switchON?.swiftUIColor ?? .white))
            .onAppear {
                UISwitch.appearance().thumbTintColor = themeManager.currentPalette.switchThumb
            }.disabled(true)
        }
    }
#else
    var body: some View {
        Toggle(isOn: $isOn) {
            label
        }
        .toggleStyle(SwitchThemedToggleStyle(tint: themeManager.currentPalette.switchON?.swiftUIColor ?? .white))
        .onAppear {
            UISwitch.appearance().thumbTintColor = themeManager.currentPalette.switchThumb
        }
    }
#endif
}
