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

    var imageName: String
    var rowTitle: String
    var action: () -> Void

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                /// Icon
                Image(imageName, bundle: PVUIBase.BundleLoader.myBundle)
                    .resizable().scaledToFit().cornerRadius(4).padding(8)
                    .tint(themeManager.currentTheme.menuIconTint.swiftUIColor)
                /// Text
                Text(rowTitle)
                    .foregroundColor(themeManager.currentTheme.menuText.swiftUIColor)
                    .background(themeManager.currentTheme.menuBackground.swiftUIColor)
                /// Space
                Spacer()
            }
            /// Height
            .frame(height: 40.0)
            /// Background
            .background(themeManager.currentTheme.menuBackground.swiftUIColor.opacity(0.3))
        }
        /// Mac Catalyst fix
        .buttonStyle(PlainButtonStyle())
    }
}
#endif
