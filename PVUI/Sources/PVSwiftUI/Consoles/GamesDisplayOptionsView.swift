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

    // Optional action for the log viewer button
    var logViewerAction: (() -> Void)?

    // Optional action for the system status button
    var systemStatusAction: (() -> Void)?

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
            // Display options menu (consolidated)
            displayOptionsMenu

            Spacer()

            // Core controls (kept separate as requested)
            coreControlsGroup
        }
        .frame(maxWidth: .infinity)
        .clipped() // Prevent overflow
    }

    // MARK: - View Components

    @ViewBuilder
    private var displayOptionsMenu: some View {
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
            .onChange(of: showSearchbar) { _ in
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
#else
        if #available(tvOS 17.0, *) {
            Menu {
                Toggle(isOn: $showGameTitles) {
                    Label("Show Game Titles", systemImage: "textformat")
                }
                Toggle(isOn: $showSearchbar) {
                    Label("Show Search Bar", systemImage: "magnifyingglass")
                }
                Toggle(isOn: $showRecentGames) {
                    Label("Show Recent Games", systemImage: "clock")
                }
                Toggle(isOn: $showRecentSaveStates) {
                    Label("Show Save States", systemImage: "bookmark")
                }
                Toggle(isOn: $showFavorites) {
                    Label("Show Favorites", systemImage: "star")
                }
                Toggle(isOn: $showGameBadges) {
                    Label("Show Badges", systemImage: "rosette")
                }
            }
            label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(font)
            }
        }
#endif
    }

    @ViewBuilder
    private var coreControlsGroup: some View {
        HStack(spacing: spacing) {
            
            Divider()
                .frame(width: 1, height: 12)
            
            // Sort indicator
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

            // View type toggle
            Button(action: {
                #if !os(tvOS)
                Haptics.impact(style: .light)
                #endif
                toggleViewTypeAction()
            }) {
                Image(systemName: isGrid ? "rectangle.grid.1x2" : "square.grid.3x3")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(font)
            }
            .contentShape(Rectangle())

            Divider()
                .frame(width: 1, height: 12)
            
            // Zoom out
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
            .contentShape(Rectangle())

            // Zoom in
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
            .contentShape(Rectangle())

            Divider()
                .frame(width: 1, height: 12)
            
            // Consolidated log/status menu
            logStatusMenu
        }
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private var logStatusMenu: some View {
        Menu {
            // Settings button content
            settingsMenuContent(for: settingsContext)

            Divider()

            // Log viewer
            Button(action: {
                #if !os(tvOS)
                Haptics.impact(style: .light)
                #endif
                if let action = logViewerAction {
                    action()
                }
            }) {
                Label("View Logs", systemImage: "doc.text")
            }
            Button(action: {
                #if !os(tvOS)
                Haptics.impact(style: .light)
                #endif
                if let action = systemStatusAction {
                    action()
                } else {
                    NotificationCenter.default.post(name: NSNotification.Name("PVShowSystemInfo"), object: nil)
                }
            }) {
                Label("System Status", systemImage: "info.circle")
            }

            // Import status - only show if we have an action or binding
            if importStatusAction != nil || showImportStatusView != nil {
                Button(action: {
                    #if !os(tvOS)
                    Haptics.impact(style: .light)
                    #endif
                    if let action = importStatusAction {
                        action()
                    }
                }) {
                    Label("Import Status", systemImage: "square.and.arrow.down")
                }
            }
        }
        label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .font(font)
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

    /// Creates settings menu content appropriate for the current context
    @ViewBuilder
    private func settingsMenuContent(for context: SettingsContext) -> some View {
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
                Label("App Settings", systemImage: "gear")
            }

        case .console(let system):
            // App settings (like HomeView)
            Button(action: {
                #if !os(tvOS)
                Haptics.impact(style: .light)
                #endif
                if let action = settingsAction {
                    action()
                }
            }) {
                Label("App Settings", systemImage: "gear")
            }

            Divider()

            // Core options - show all available cores
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
        }
    }

    // MARK: - Lifecycle

    private func setupView() {
        gameLibraryScale = Defaults[.gameLibraryScale]
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
