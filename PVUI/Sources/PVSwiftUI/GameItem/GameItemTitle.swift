//
//  GameItemTitle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes

@available(iOS 14, tvOS 14, *)
struct GameItemTitle: SwiftUI.View {
    @ObservedObject private var themeManager = ThemeManager.shared
    var text: String
    var viewType: GameItemViewType

    var body: some SwiftUI.View {
        Text(text)
            .font(.system(size: viewType.titleFontSize))
            .foregroundColor(themeManager.currentTheme.gameLibraryText.swiftUIColor)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
