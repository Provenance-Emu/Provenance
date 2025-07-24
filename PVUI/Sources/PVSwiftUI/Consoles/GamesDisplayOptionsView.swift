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
import PVCoreBridge
import UIKit
// Import for core options detail view
import struct PVUIBase.CoreOptionsDetailView

@available(iOS 14, tvOS 14, *)
/// Context for the settings button to determine its behavior
enum SettingsContext {
    /// Home view context - opens main app settings
    case home
    /// Console view context - opens core options for the system
    case console(PVSystem)
}

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
    
    // Optional action for the import status button
    var importStatusAction: (() -> Void)?
    
    // Optional action for the settings button
    var settingsAction: (() -> Void)?
    
    // Context for the settings button
    var settingsContext: SettingsContext = .home

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
                Divider()
                    .frame(width: 1, height: 12)

                OptionsIndicator(pointDown: sortAscending, action: {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    toggleSortAction()
                }) {
                    Image(systemName: sortAscending ? "chevron.down.dotted.2" :"chevron.up.dotted.2")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(font.weight(.light))
                }
                .contentShape(Rectangle())

                OptionsIndicator(pointDown: true, action: {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    isGrid.toggle()
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

                Divider()
                    .frame(width: 1, height: 12)

                // Log button for viewing detailed logs
                RetroLogButton(size: 12, color: .retroBlue)
                    .padding(.trailing, padding)

                // Settings button - contextual based on parent view
                settingsButton(for: settingsContext)
                    .padding(.trailing, padding)
                
                // Status control button for viewing system status
                StatusControlButton()
                    .padding(.trailing, padding)

                // Import status button - only show if we have an action or binding
                if importStatusAction != nil || showImportStatusView != nil {
                    Button(action: {
                        #if !os(tvOS)
                        Haptics.impact(style: .light)
                        #endif
                        if let action = importStatusAction {
                            action()
                        } else {
                            showImportStatusView = true
                        }
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            .font(font)
                    }
                    .padding(.trailing, padding)
                }
            }
            .allowsHitTesting(true)
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
    
    // MARK: - Settings Button
    
    /// Creates a settings button appropriate for the current context
    @ViewBuilder
    private func settingsButton(for context: SettingsContext) -> some View {
        switch context {
        case .home:
            // Main app settings button
            Button(action: {
                #if !os(tvOS)
                Haptics.impact(style: .light)
                #endif
                if let action = settingsAction {
                    action()
                }
            }) {
                Image(systemName: "gear")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(font)
            }
            
        case .console(let system):
            // Core options button - shows dropdown if multiple cores
            if system.cores.count > 1 {
                // Multiple cores - show menu
                if #available(iOS 15, tvOS 17, *) {
                    Menu {
                        ForEach(system.cores, id: \.identifier) { core in
                            if let coreClass = NSClassFromString(core.principleClass) as? CoreOptional.Type {
                                Button(action: {
#if !os(tvOS)
                                    Haptics.impact(style: .light)
#endif
                                    presentCoreOptions(for: coreClass, title: core.projectName)
                                }) {
                                    Label("\(core.projectName) Options", systemImage: "slider.horizontal.3")
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "gearshape.2")
                            .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                            .font(font)
                    }
                }
            } else if let core = system.cores.first,
                      let coreClass = NSClassFromString(core.principleClass) as? CoreOptional.Type {
                // Single core - direct button
                Button(action: {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    presentCoreOptions(for: coreClass, title: core.projectName)
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                        .font(font)
                }
            }
        }
    }
    
    /// Present core options for a specific core
    private func presentCoreOptions(for coreClass: CoreOptional.Type, title: String) {
        #if !os(tvOS)
        // Find the nearest UIViewController to present from
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            let coreOptionsView = CoreOptionsDetailView(coreClass: coreClass, title: title)
            let hostingController = UIHostingController(rootView: coreOptionsView)
            let navigationController = UINavigationController(rootViewController: hostingController)
            rootVC.present(navigationController, animated: true)
        }
        #endif
    }
}
