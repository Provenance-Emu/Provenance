//
//  HomeItemView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/12/24.
//

import SwiftUI
import PVThemes

@available(iOS 14, tvOS 14, *)
struct HomeItemView: SwiftUI.View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var imageName: String
    var rowTitle: String

    var body: some SwiftUI.View {
        HStack(spacing: 0) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .cornerRadius(4)
                .padding(8)
                .tint(themeManager.currentTheme.barButtonItemTint?.swiftUIColor)
            Text(rowTitle)
                .foregroundColor(themeManager.currentTheme.barButtonItemTint?.swiftUIColor)
            Spacer()
        }
        .frame(height: 40.0)
        .background(themeManager.currentTheme.gameLibraryBackground.swiftUIColor)
    }
}
