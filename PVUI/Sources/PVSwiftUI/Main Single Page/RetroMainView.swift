//
//  MainView.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import SwiftUI
import PVUIBase
import PVThemes
import PVLogging
import Combine

#if os(tvOS)
/// Modifier that focuses the tab bar when Menu/Back is pressed on tvOS
struct FocusTabBarOnExitModifier: ViewModifier {
    @Environment(\.focusRetroTabBar) private var focusRetroTabBar

    func body(content: Content) -> some View {
        content
            .onExitCommand {
                focusRetroTabBar?()
            }
    }
}
#endif

public struct RetroMainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("showFeatureFlagsDebug") private var showFeatureFlagsDebug = false

    // Document picker manager as an environment object
    @StateObject private var documentPickerManager = DocumentPickerManager.shared

    /// Observe the sync status manager directly for proper SwiftUI updates
    @ObservedObject private var syncStatusManager = SceneCoordinator.shared.syncStatusManager

    @State private var selectedTab: Int = 0
    @State private var showDynamicIslandEffects: Bool = true

    // Timer for occasional special effects
    @State private var effectTimer: AnyCancellable?

    public init () { }

    // Computed property for tab items that conditionally includes debug tab
    private var tabItems: [RetroTabItem] {
        var items = [
            RetroTabItem(title: "Games", systemImage: "gamecontroller"),
            RetroTabItem(title: "Save States", systemImage: "clock.arrow.circlepath"),
            RetroTabItem(title: "Settings", systemImage: "gear"),
            RetroTabItem(title: "Status", systemImage: "info")
        ]

        if showFeatureFlagsDebug {
            items.append(RetroTabItem(title: "Debug", systemImage: "ladybug"))
        }

        return items
    }

    public var body: some View {
        ZStack {
#if !os(tvOS)
            // Add document picker sheet at the root level
            Color.clear
                .sheet(isPresented: $documentPickerManager.isShowingDocumentPicker, onDismiss: {
                    // Nothing needed here - the DocumentPickerManager handles state reset
                }) {
                    DocumentPicker(onImport: { urls in
                        // Call the callback if it exists
                        documentPickerManager.documentPickerCompleted(urls: urls)

                        // Explicitly set isShowingDocumentPicker to false to ensure proper state update
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            documentPickerManager.isShowingDocumentPicker = false
                        }
                    })
                }
#endif
            // Background that adapts to the theme
            RetroTheme.retroBackground
                .ignoresSafeArea()

#if !os(tvOS)
            // Dynamic Island retrowave effects
            if showDynamicIslandEffects {
                RetroDynamicIsland()
                    .allowsHitTesting(false) // Prevent interaction with the effects
                    .ignoresSafeArea()
            }
#endif

            // Custom RetroTabView with retrowave styling
            RetroTabView(
                selection: $selectedTab,
                content: {
                    // Content views for each tab
                    // Tab indices: 0=Games, 1=Save States, 2=Settings, 3=Status, 4=Debug (optional)
                    ZStack {
                        // Show the appropriate view based on the selected tab
                        if selectedTab == 0 {
                            RetroGameLibraryView()
                                .padding(.top, 40)
                                .environmentObject(SceneCoordinator.shared)
                                .environmentObject(documentPickerManager)
#if os(tvOS)
                                .modifier(FocusTabBarOnExitModifier())
#endif
                        } else if selectedTab == 1 {
                            SaveStateBrowserView()
#if os(tvOS)
                                .modifier(FocusTabBarOnExitModifier())
#endif
                        } else if selectedTab == 2 {
                            SettingsWrapperView()
                        } else if selectedTab == 3 {
                            Group {
#if os(tvOS)
                                // On tvOS, let RetroStatusControlView handle its own scrolling for better focus management
                                RetroStatusControlView()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .modifier(FocusTabBarOnExitModifier())
#else
                                ScrollView {
                                    RetroStatusControlView()
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                }
#endif
                            }
                            .tabItem {
                                Label("Status", systemImage: "test")
                            }
                            .tag("status")
                            .ignoresSafeArea(.all, edges: .bottom)
                        } else if selectedTab == 4 && showFeatureFlagsDebug {
                            RetroDebugView()
#if os(tvOS)
                                .modifier(FocusTabBarOnExitModifier())
#endif
                        }
                    }
                },
                tabItems: tabItems
            )

            // Multi-select batch-action toolbar — rendered here (above RetroTabView)
            // so it is not obscured by the tab bar.
            RetroMultiSelectToolbar()

            // Sync status overlay for game launch and cloud downloads
            if syncStatusManager.isVisible {
                GameSyncStatusView(
                    gameTitle: syncStatusManager.gameTitle,
                    statusMessage: syncStatusManager.statusMessage,
                    isComplete: syncStatusManager.isComplete,
                    hasError: syncStatusManager.hasError,
                    onCancel: syncStatusManager.onCancel
                )
                .transition(.opacity)
                .animation(.easeInOut, value: syncStatusManager.isVisible)
            }

            // RetroWave styled alert overlay
            RetroAlertStateView(alertState: SceneCoordinator.shared.alertState)
        }
        .onAppear {
            ILOG("MainView: Appeared with RetroTabView")

            // Set up a timer to occasionally trigger special effects around the Dynamic Island
            setupEffectTimer()

            // Force home indicator update on view appearance
            setHomeIndicatorAutoHidden()

            // Switch to the Games (library) tab if a search action is already pending
            // (cold-launch: LibraryNavigator queues the action before the view appears).
            if case .search = LibraryNavigator.shared.pendingAction, selectedTab != 0 {
                selectedTab = 0
            }
        }
        .onReceive(LibraryNavigator.shared.$pendingAction) { action in
            // Switch to the Games tab when a search action arrives at runtime.
            if case .search = action, selectedTab != 0 {
                selectedTab = 0
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            effectTimer?.cancel()
        }
        .preferredColorScheme(.dark) // Retrowave theme works best with dark mode
        .ignoresSafeArea(.all) // Ensure the view extends edge-to-edge
#if os(iOS)
        .romDropTarget() // ROM drag & drop import (#2136)
#endif
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
#if !os(tvOS)
            rootViewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
            rootViewController.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
#endif
            DLOG("MainView: Requested update of home indicator state")
        }
    }
}

#if DEBUG
#Preview {
    RetroMainView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
#endif
