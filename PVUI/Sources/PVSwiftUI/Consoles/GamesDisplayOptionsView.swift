//
//  GamesDisplayOptionsView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/28/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes

@available(iOS 14, tvOS 14, *)
struct GamesDisplayOptionsView: SwiftUI.View {

    var sortAscending = true
    var isGrid = true

    var toggleFilterAction: () -> Void
    var toggleSortAction: () -> Void
    var toggleViewTypeAction: () -> Void

    let font: Font = .system(.footnote, design: .default)
    let spacing: CGFloat = 12
    let padding: CGFloat = 10
    
    var body: some SwiftUI.View {
        HStack(spacing: spacing) {
            Spacer()
//            OptionsIndicator(pointDown: true, action: { toggleFilterAction() }) {
//                Text("Filter").foregroundColor(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor).font(font)
//            }
            OptionsIndicator(pointDown: sortAscending, action: { toggleSortAction() }) {
                Text("Sort").foregroundColor(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor).font(font)
            }
            OptionsIndicator(pointDown: true, action: { toggleViewTypeAction() }) {
                Image(systemName: isGrid == true ? "square.grid.3x3.fill" : "line.3.horizontal")
                    .foregroundColor(ThemeManager.shared.currentTheme.gameLibraryText.swiftUIColor)
                    .font(font.weight(.light))
            }
            .padding(.trailing, padding)
        }
    }
}
#endif
