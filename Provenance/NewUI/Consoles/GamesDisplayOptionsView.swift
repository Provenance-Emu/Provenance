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

@available(iOS 14, tvOS 14, *)
struct GamesDisplayOptionsView: SwiftUI.View {

    var sortAscending = true
    var isGrid = true

    var toggleFilterAction: () -> Void
    var toggleSortAction: () -> Void
    var toggleViewTypeAction: () -> Void

    var body: some SwiftUI.View {
        HStack(spacing: 12) {
            Spacer()
            OptionsIndicator(pointDown: true, action: { toggleFilterAction() }) {
                Text("Filter").foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor).font(.system(size: 13))
            }
            OptionsIndicator(pointDown: sortAscending, action: { toggleSortAction() }) {
                Text("Sort").foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor).font(.system(size: 13))
            }
            OptionsIndicator(pointDown: true, action: { toggleViewTypeAction() }) {
                Image(systemName: isGrid == true ? "square.grid.3x3.fill" : "line.3.horizontal")
                    .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
                    .font(.system(size: 13, weight: .light))
            }
            .padding(.trailing, 10)
        }
    }
}
#endif
