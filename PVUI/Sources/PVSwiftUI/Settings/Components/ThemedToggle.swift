//
//  ThemedToggle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/27/24.
//

import SwiftUI
import PVThemes

public struct ThemedToggle<Label: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Binding public var isOn: Bool
    @ViewBuilder public let label: () -> Label
    
    // Use RetroToggleStyle by default, but allow fallback to system style
    public var useRetroStyle: Bool = true

    public var body: some View {
        Toggle(isOn: $isOn) {
            label()
        }
#if !os(tvOS)
        .modifier(ToggleStyleModifier(useRetroStyle: useRetroStyle, themeManager: themeManager))
#endif
    }
}

// Helper modifier to handle different toggle styles
private struct ToggleStyleModifier: ViewModifier {
    let useRetroStyle: Bool
    let themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        if useRetroStyle {
            content.toggleStyle(RetroTheme.RetroToggleStyle())
        } else {
            content.toggleStyle(SwitchThemedToggleStyle(tint: themeManager.currentPalette.switchON?.swiftUIColor ?? .white))
        }
    }
}
