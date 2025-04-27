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
import PVUIBase

@available(iOS 14, tvOS 14, *)
struct GamesDisplayOptionsView: SwiftUI.View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Default(.gameLibraryScale) private var gameLibraryScale
    @Default(.showGameTitles) private var showGameTitles
    @Default(.showRecentGames) private var showRecentGames
    @Default(.showSearchbar) private var showSearchbar
    @Default(.showRecentSaveStates) private var showRecentSaveStates
    @Default(.showFavorites) private var showFavorites
    @Default(.showGameBadges) private var showGameBadges

    @State var sortAscending = true
    @State var isGrid = true
    
    // Binding to control the import status view visibility
    @Binding var showImportStatusView: Bool

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
#if !os(tvOS)
            Menu {
                Toggle(isOn: $showGameTitles) {
                    Label("Show Game Titles", systemImage: "textformat")
                }
                .onChange(of: showGameTitles) { _ in
                    Haptics.impact(style: .light)
                }
                Toggle(isOn: $showSearchbar) {
                    Label("Show Search Bar", systemImage: "magnifyingglass")
                }
                .onChange(of: showGameTitles) { _ in
                    Haptics.impact(style: .light)
                }
                Toggle(isOn: $showRecentGames) {
                    Label("Show Recent Games", systemImage: "clock")
                }
                .onChange(of: showRecentGames) { _ in
                    Haptics.impact(style: .light)
                }
                Toggle(isOn: $showRecentSaveStates) {
                    Label("Show Save States", systemImage: "bookmark")
                }
                .onChange(of: showRecentSaveStates) { _ in
                    Haptics.impact(style: .light)
                }
                Toggle(isOn: $showFavorites) {
                    Label("Show Favorites", systemImage: "star")
                }
                .onChange(of: showFavorites) { _ in
                    Haptics.impact(style: .light)
                }
                Toggle(isOn: $showGameBadges) {
                    Label("Show Badges", systemImage: "rosette")
                }
                .onChange(of: showGameBadges) { _ in
                    Haptics.impact(style: .light)
                }
            }
            label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(font)
            }
            .padding(.horizontal, 30)
#else
            if #available(tvOS 17.0, *) {
                Menu {
                    Toggle(isOn: $showGameTitles) {
                        Label("Show Game Titles", systemImage: "textformat")
                    }
                    .onChange(of: showGameTitles) { _ in
                    }
                    Toggle(isOn: $showSearchbar) {
                        Label("Show Search Bar", systemImage: "magnifyingglass")
                    }
                    .onChange(of: showRecentGames) { _ in
                    }
                    Toggle(isOn: $showRecentGames) {
                        Label("Show Recent Games", systemImage: "clock")
                    }
                    .onChange(of: showRecentGames) { _ in
                    }
                    Toggle(isOn: $showRecentSaveStates) {
                        Label("Show Save States", systemImage: "bookmark")
                    }
                    .onChange(of: showRecentSaveStates) { _ in
                    }
                    Toggle(isOn: $showFavorites) {
                        Label("Show Favorites", systemImage: "star")
                    }
                    .onChange(of: showFavorites) { _ in
                    }
                    Toggle(isOn: $showGameBadges) {
                        Label("Show Badges", systemImage: "rosette")
                    }
                    .onChange(of: showGameBadges) { _ in
                    }
                }
                label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(font)
                }
                .padding(.horizontal, 30)
            }
#endif

            Spacer()
            Group {
                OptionsIndicator(pointDown: sortAscending, action: {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    toggleSortAction()
                }) {
                    Text("Sort")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(font)
                }
                .contentShape(Rectangle())

                OptionsIndicator(pointDown: true, action: {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    toggleViewTypeAction()
                }) {
                    Image(systemName: isGrid == true ? "square.grid.3x3.fill" : "line.3.horizontal")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(font.weight(.light))
                }
                .contentShape(Rectangle())

                Button(action: {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    zoomOut()
                }) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(font)
                }
                .disabled(!canZoomOut)
                .padding(.trailing, padding)
                .padding(.leading, padding)

                Button(action: {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    zoomIn()
                }) {
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(font)
                }
                .disabled(!canZoomIn)
                .padding(.trailing, padding)
                
                Spacer()

                // Log button for viewing detailed logs
                RetroLogButton(size: 12, color: .retroBlue)
                    .padding(.trailing, padding)
                
                // Status control button for viewing system status
                StatusControlButton()
                    .padding(.trailing, padding)
                
                // Import status button
                Button(action: {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    showImportStatusView = true
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(font)
                }
                .padding(.trailing, padding)
            }
            .allowsHitTesting(true)
            
            Spacer()
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
            #if !os(tvOS)
            Haptics.impact(style: .light)
            #endif
            Defaults[.gameLibraryScale] -= 1
        }
    }

    private func zoomOut() {
        if canZoomOut {
            #if !os(tvOS)
            Haptics.impact(style: .light)
            #endif
            Defaults[.gameLibraryScale] += 1
        }
    }
}
