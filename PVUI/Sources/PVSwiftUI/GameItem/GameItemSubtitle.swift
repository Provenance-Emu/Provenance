//
//  GameItemSubtitle.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//

import SwiftUI
import PVThemes

@available(iOS 14, tvOS 14, *)
struct GameItemSubtitle_Preview: PreviewProvider {
    static var previews: some SwiftUI.View {
        HStack {
            GameItemSubtitle(text:  "Foo Bar", viewType: .cell)
            GameItemSubtitle(text:  "Bar Foo", viewType: .row)
        }
        .environmentObject(ThemeManager.shared)
    }
}

@available(iOS 14, tvOS 14, *)
struct GameItemSubtitle: SwiftUI.View {
    var text: String?
    var viewType: GameItemViewType
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some SwiftUI.View {
        Text(text ?? "blank")
            .font(.system(size: viewType.subtitleFontSize))
            .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(text != nil ? 1.0 : 0.0) // hide rather than not render so that cell keeps consistent height
    }
}
