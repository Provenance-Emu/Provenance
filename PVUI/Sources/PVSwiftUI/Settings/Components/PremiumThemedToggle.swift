//
//  PremiumThemedToggle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import UIKit
#if canImport(FreemiumKit)
import FreemiumKit
#endif
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
    #if !os(tvOS)
        PaidFeatureView {
            Toggle(isOn: $isOn) {
                label
            }
            .toggleStyle(RetroTheme.RetroToggleStyle())
        } lockedView: {
            ZStack {
                Color(.clear)
                Toggle(isOn: $isOn) {
                    label
                }
                .toggleStyle(RetroTheme.RetroToggleStyle())
                .opacity(0.6)
                .disabled(true)
            }
        }
        #else
        PaidFeatureView {
            Toggle(isOn: $isOn) {
                label
            }
        } lockedView: {
            ZStack {
                Color(.clear)
                Toggle(isOn: $isOn) {
                    label
                }
                .disabled(true)
            }
        }
        #endif
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
