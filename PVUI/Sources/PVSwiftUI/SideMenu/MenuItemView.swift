//
//  MenuItemView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/4/24.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
@_exported import PVUIBase

#if canImport(Introspect)
import Introspect
#endif
@available(iOS 14, tvOS 14, *)
struct MenuItemView: SwiftUI.View {

    var icon: SettingsIcon
    var rowTitle: String
    var isFocused: Bool

    var action: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var gamepadManager = GamepadManager.shared

    private var shouldShowFocus: Bool {
        isFocused && controllerConnected
    }
    
    private var controllerConnected: Bool {
        gamepadManager.isControllerConnected
    }
    
    private var tint: Color {
        shouldShowFocus ? themeManager.currentPalette.menuIconTint.swiftUIColor : themeManager.currentPalette.menuIconTint.swiftUIColor.opacity(controllerConnected ? 0.6 : 1.0)
    }

    var body: some SwiftUI.View {
        let _ = print("MenuItemView '\(rowTitle)' isFocused: \(isFocused)")
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                /// Icon
                icon.image
                    .renderingMode(.template)
                    .resizable().scaledToFit().cornerRadius(4).padding(8)
                    .tint(tint)
                /// Text
                Text(rowTitle)
                    .foregroundColor(tint)
                /// Space
                Spacer()
            }
            /// Height
            .frame(height: 40.0)
            /// Background and focus state
            .background(
                shouldShowFocus ?
                themeManager.currentPalette.menuBackground.swiftUIColor.opacity(0.8) :
                themeManager.currentPalette.menuBackground.swiftUIColor.opacity(controllerConnected ? 0.3 : 1.0)
            )
            .overlay(
                Rectangle()
                    .stroke(shouldShowFocus ? themeManager.currentPalette.menuIconTint.swiftUIColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .focusableIfAvailable()
    }
}
#endif
