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
import Combine

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    @State private var selectedTab: Int = 0
    @State private var showDynamicIslandEffects: Bool = true

    // Timer for occasional special effects
    @State private var effectTimer: AnyCancellable?

    var body: some View {
        ZStack {
            // Background that adapts to the theme
            RetroTheme.retroBackground
                .ignoresSafeArea()

            // Dynamic Island retrowave effects
            if showDynamicIslandEffects {
                RetroDynamicIsland()
                    .allowsHitTesting(false) // Prevent interaction with the effects
                    .ignoresSafeArea()
            }

            // Custom RetroTabView with retrowave styling
            RetroTabView(
                selection: $selectedTab,
                content: {
                    // Content views for each tab
                    ZStack {
                        // Show the appropriate view based on the selected tab
                        if selectedTab == 0 {

                            GameLibraryView()
                                .padding(.top, 40)
                        } else if selectedTab == 1 {
                            SettingsView()
                        } else if selectedTab == 2 {
                            DebugView()
                        }
                    }
                },
                tabItems: [
                    RetroTabItem(title: "Games", systemImage: "gamecontroller"),
                    RetroTabItem(title: "Settings", systemImage: "gear"),
                    RetroTabItem(title: "Debug", systemImage: "ladybug")
                ]
            )
            .onAppear {
                ILOG("MainView: Appeared with RetroTabView")

                // Set up a timer to occasionally trigger special effects around the Dynamic Island
                setupEffectTimer()

                // Force home indicator update on view appearance
                setHomeIndicatorAutoHidden()
            }
            .onDisappear {
                // Clean up timer when view disappears
                effectTimer?.cancel()
            }
            .preferredColorScheme(.dark) // Retrowave theme works best with dark mode
        }
        .ignoresSafeArea(.all) // Ensure the view extends edge-to-edge
        .hideHomeIndicator() // Hide the home indicator for immersive experience
    }

    // MARK: - Dynamic Island Effects

    /// Sets up a timer to occasionally trigger special effects around the Dynamic Island
    private func setupEffectTimer() {
        // Create a timer that fires every 30 seconds
        effectTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Randomly decide whether to show a special effect
                if Bool.random() {
                    self.triggerDynamicIslandEffect()
                }
            }
    }

    /// Triggers a special effect around the Dynamic Island
    private func triggerDynamicIslandEffect() {
        // First ensure effects are shown
        showDynamicIslandEffects = true

        // After a few seconds, we can optionally hide the effects again
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            // Randomly decide whether to hide the effects
            if Bool.random() {
                withAnimation {
                    showDynamicIslandEffects = false
                }
            }
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

    /// Force update of home indicator state through UIKit
    private func setHomeIndicatorAutoHidden() {
        // Find the hosting controller and trigger update
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            // Request an update of the home indicator state
            rootViewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
            rootViewController.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()

            DLOG("MainView: Requested update of home indicator state")
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
