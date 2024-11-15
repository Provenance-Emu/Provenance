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
    var action: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.isFocused) private var isFocused: Bool

    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                /// Icon
                icon.image
                    .renderingMode(.template)
                    .resizable().scaledToFit().cornerRadius(4).padding(8)
                    .tint(isFocused ? themeManager.currentPalette.menuIconTint.swiftUIColor : themeManager.currentPalette.menuIconTint.swiftUIColor.opacity(0.6))
                /// Text
                Text(rowTitle)
                    .foregroundColor(isFocused ? themeManager.currentPalette.menuText.swiftUIColor : themeManager.currentPalette.menuText.swiftUIColor.opacity(0.6))
                /// Space
                Spacer()
            }
            /// Height
            .frame(height: 40.0)
            /// Background and focus state
            .background(
                isFocused ?
                themeManager.currentPalette.menuBackground.swiftUIColor.opacity(0.8) :
                themeManager.currentPalette.menuBackground.swiftUIColor.opacity(0.3)
            )
            .overlay(
                Rectangle()
                    .stroke(isFocused ? themeManager.currentPalette.menuIconTint.swiftUIColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .focusableIfAvailable()
    }
}
#endif
