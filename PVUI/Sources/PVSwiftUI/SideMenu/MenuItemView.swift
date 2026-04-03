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

@available(iOS 14, tvOS 14, *)
struct MenuItemView: SwiftUI.View {

    var icon: SettingsIcon
    var rowTitle: String
    var isFocused: Bool

    var action: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var gamepadManager = GamepadManager.shared

    private var shouldShowFocus: Bool {
        (isFocused && controllerConnected) || !controllerConnected
    }
    
    private var controllerConnected: Bool {
        gamepadManager.isControllerConnected
    }
    
    private var shouldStroke: Bool {
        shouldShowFocus && controllerConnected
    }
    
    private var iconTint: Color {
        shouldShowFocus ? themeManager.currentPalette.menuIconTint.swiftUIColor : themeManager.currentPalette.menuIconTint.swiftUIColor.opacity(controllerConnected ? 0.6 : 1.0)
    }
    
    private var textTint: Color {
        shouldShowFocus ? themeManager.currentPalette.menuText.swiftUIColor : themeManager.currentPalette.menuText.swiftUIColor.opacity(controllerConnected ? 0.6 : 1.0)
    }

    /// Whether this row represents the currently active console/tab
    var isActive: Bool = false

    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                /// Active indicator -- thin accent bar on the leading edge
                if isActive {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(iconTint)
                        .frame(width: 3, height: 24)
                        .shadow(color: iconTint.opacity(0.5), radius: 4)
                        .padding(.trailing, 6)
                }
                /// Icon
                icon.image
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .cornerRadius(4)
                    .frame(width: 40, height: 40)
                    .tint(iconTint)
                    .foregroundStyle(iconTint)
                    .foregroundColor(iconTint)
                /// Text
                Text(rowTitle)
                    .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                    .tracking(0.3)
                    .foregroundColor(textTint)
                /// Space
                Spacer()
            }
            .frame(height: 40.0)
            .background(
                shouldShowFocus ?
                themeManager.currentPalette.menuBackground.swiftUIColor.opacity(0.8) :
                themeManager.currentPalette.menuBackground.swiftUIColor.opacity(controllerConnected ? 0.3 : 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RetroPauseChrome.radiusSM)
                    .stroke(shouldStroke ? themeManager.currentPalette.menuIconTint.swiftUIColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .focusableIfAvailable()
    }
}
#endif
