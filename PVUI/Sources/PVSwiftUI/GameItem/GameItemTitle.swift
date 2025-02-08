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
        GeometryReader { geometry in
            MarqueeText(text: text,
                        font: .system(size: viewType.titleFontSize),
                        delay: 1.0,
                        speed: 50.0,
                        loop: true)
                .frame(width: geometry.size.width, alignment: .leading)
                .clipped()
        }
        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
