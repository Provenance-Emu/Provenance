//
//  GamesDisplayOptionsView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 1/28/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import Defaults

@available(iOS 14, tvOS 14, *)
struct GamesDisplayOptionsView: SwiftUI.View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Default(.gameLibraryScale) private var gameLibraryScale

    var sortAscending = true
    var isGrid = true

    var toggleFilterAction: () -> Void
    var toggleSortAction: () -> Void
    var toggleViewTypeAction: () -> Void

    let font: Font = .system(.footnote, design: .default)
    let spacing: CGFloat = 12
    let padding: CGFloat = 10

    var canZoomIn: Bool {
        gameLibraryScale > 1
    }
    
    var canZoomOut: Bool {
        gameLibraryScale < 8
    }

    var body: some SwiftUI.View {
        HStack(spacing: spacing) {
            Spacer()
            OptionsIndicator(pointDown: sortAscending, action: { toggleSortAction() }) {
                Text("Sort")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(font)
            }
            OptionsIndicator(pointDown: true, action: { toggleViewTypeAction() }) {
                Image(systemName: isGrid == true ? "square.grid.3x3.fill" : "line.3.horizontal")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(font.weight(.light))
            }
            Button(action: zoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(font)
            }
            .disabled(!canZoomOut)
            .padding(.trailing, padding)
            .padding(.leading, padding)

            Button(action: zoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(font)
            }
            .disabled(!canZoomIn)
            .padding(.trailing, padding)
        }
        .onAppear {
            gameLibraryScale = Defaults[.gameLibraryScale]
        }
        .onChange(of: Defaults[.gameLibraryScale]) { newValue in
            gameLibraryScale = newValue
        }
    }

    private func zoomIn() {
        if canZoomIn {
            Defaults[.gameLibraryScale] -= 1
        }
    }

    private func zoomOut() {
        if canZoomOut {
            Defaults[.gameLibraryScale] += 1
        }
    }
}
