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

    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                Image(imageName, bundle: PVUIBase.BundleLoader.myBundle)
                    .resizable().scaledToFit().cornerRadius(4).padding(8)
                    .tint(ThemeManager.shared.currentTheme.barButtonItemTint?.swiftUIColor ?? Color.gray)
                
                Text(rowTitle)
                    .foregroundColor(ThemeManager.shared.currentTheme.settingsCellText?.swiftUIColor ?? Color.white)
                    .background(Color.clear) // Clear background

                Spacer()
            }
            .frame(height: 40.0)
            .background(ThemeManager.shared.currentTheme.settingsCellBackground?.swiftUIColor.opacity(0.3) ?? Color.black)
        }
        .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to remove default button styling

    }
}
#endif
