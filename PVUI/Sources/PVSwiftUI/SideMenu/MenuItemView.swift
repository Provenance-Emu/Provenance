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

    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                /// Icon
                icon.image
                    .renderingMode(.template)
                    .resizable().scaledToFit().cornerRadius(4).padding(8)
                    .tint(themeManager.currentPalette.menuIconTint.swiftUIColor)
                    .foregroundStyle(themeManager.currentPalette.menuIconTint.swiftUIColor)
                /// Text
                Text(rowTitle)
                    .foregroundColor(themeManager.currentPalette.menuText.swiftUIColor)
                    .background(themeManager.currentPalette.menuBackground.swiftUIColor)
                /// Space
                Spacer()
            }
            /// Height
            .frame(height: 40.0)
            /// Background
            .background(themeManager.currentPalette.menuBackground.swiftUIColor.opacity(0.3))
        }
        /// Mac Catalyst fix
        .buttonStyle(PlainButtonStyle())
    }
}
#endif
