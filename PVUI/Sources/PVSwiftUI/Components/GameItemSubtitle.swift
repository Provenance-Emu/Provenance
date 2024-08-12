//
//  GameItemSubtitle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes

@available(iOS 14, tvOS 14, *)
struct GameItemSubtitle: SwiftUI.View {
    var text: String?
    var viewType: GameItemViewType

    var body: some SwiftUI.View {
        Text(text ?? "blank")
            .font(.system(size: viewType.subtitleFontSize))
            .foregroundColor(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(text != nil ? 1.0 : 0.0) // hide rather than not render so that cell keeps consistent height
    }
}
