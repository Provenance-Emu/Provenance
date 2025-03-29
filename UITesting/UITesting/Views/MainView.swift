//
//  MainView.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import SwiftUI
import PVSwiftUI
import PVUIBase
import PVThemes
import PVLogging

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            // Background that adapts to the theme
            Color(themeManager.currentPalette.gameLibraryBackground)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                // Game Library Tab
                GameLibraryView()
                .tabItem {
                    Label("Games", systemImage: "gamecontroller")
                }
                .tag(0)

                // Settings Tab
                SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(1)

                // Debug Tab
                DebugView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
                .tag(2)
            }
            .accentColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
            .onAppear {
                // Configure TabBar appearance to respect theme
//                configureTabBarAppearance()
                ILOG("MainView: Appeared")
            }
            .preferredColorScheme(themeManager.currentPalette.dark ? .dark : .light)
//            .onChange(of: themeManager.currentPalette) {
//                // Update TabBar appearance when theme changes
//                configureTabBarAppearance()
//            }
        }
    }

    /// Configures the UITabBar appearance to match the current theme
    private func configureTabBarAppearance() {
        let isDarkMode = themeManager.currentPalette.dark

        // Create a new appearance object
        let tabBarAppearance = UITabBarAppearance()

        // Configure the appearance for the current theme
        if isDarkMode {
            // Dark mode configuration
            tabBarAppearance.configureWithDefaultBackground()
            tabBarAppearance.backgroundColor = themeManager.currentPalette.gameLibraryBackground.withAlphaComponent(0.95)

            // Configure normal and selected item colors
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.lightGray
            ]

            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: themeManager.currentPalette.defaultTintColor
            ]

            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .lightGray
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = themeManager.currentPalette.defaultTintColor
        } else {
            // Light mode configuration
            tabBarAppearance.configureWithDefaultBackground()
            tabBarAppearance.backgroundColor = themeManager.currentPalette.gameLibraryBackground.withAlphaComponent(0.95)

            // Configure normal and selected item colors
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.darkGray
            ]

            let selectedAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: themeManager.currentPalette.defaultTintColor
            ]

            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttributes
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttributes
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .darkGray
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = themeManager.currentPalette.defaultTintColor
        }

        // Apply the appearance to both standard and scrolling edge appearances
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
