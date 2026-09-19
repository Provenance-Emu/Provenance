//
//  ContentView.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVSwiftUI
import PVUIBase
import PVThemes
import PVLogging
import PVPrimitives

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var sceneCoordinator: SceneCoordinator
    /// Use EnvironmentObject for app delegate
    @EnvironmentObject private var appDelegate: PVAppDelegate

    // State to force view refresh
    @State private var forceRefresh: Bool = false

    init() {
        ILOG("ContentView: init() called, current bootup state: \(AppState.shared.bootupStateManager.currentState.localizedDescription)")
    }

    // State to track delayed transition.
    // In screenshot mode there is no splash hold: show content as soon as bootup completes.
    @State private var showCompletedContent: Bool = LaunchArgument.screenshotMode.isEnabled
    
    
    var bootupView: some View {
        ZStack {
            // Show the bootup view
            BootupViewRetroWave()
                .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .transition(.opacity)
                .animation(.easeInOut, value: appState.bootupStateManager.currentState)
                .hideHomeIndicator()
                .accessibilityIdentifier("screenshot.bootup")
                .onAppear {
                    // Schedule transition after 2 seconds (immediately in screenshot mode)
                    let delay: TimeInterval = LaunchArgument.screenshotMode.isEnabled ? 0 : 2.0
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation {
                            showCompletedContent = true
                        }
                    }
                }
        }
    }
    

    var body: some View {
        // Use a local variable to track the bootup state
        let bootupState = appState.bootupStateManager.currentState
        ILOG("ContentView: body evaluated with bootup state: \(bootupState.localizedDescription)")

        return Group {
            if case .completed = bootupState, showCompletedContent {
                // Use the TestSceneCoordinator to determine which view to show
                // Only show emulator if both the scene coordinator says to AND there's a game in EmulationUIState
                if sceneCoordinator.currentScene == .emulator && sceneCoordinator.showEmulator && appState.emulationUIState.currentGame != nil {
                    // Show the emulator view
                    ZStack {
                        EmulatorContainerView()
                    }
                    .onAppear {
                        ILOG("ContentView: EmulatorContainerView appeared")
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: sceneCoordinator.currentScene)
                    .hideHomeIndicator()
                } else {
                    // Show the main view
                    ZStack {
                        switch appState.mainUIMode {
                            #if !os(tvOS)
                        case .paged:
                            SwiftUIHostedProvenanceMainView()
                                .environmentObject(appDelegate)
                                .edgesIgnoringSafeArea(.all)
                            #endif
                        case .singlePage:
                            RetroMainView()
                                .environmentObject(appDelegate)
                                .environmentObject(ThemeManager.shared)
                                .edgesIgnoringSafeArea(.all)
                            #if os(tvOS)
                        case .tvosMedia:
                            // TVMediaMainView is internal to PVSwiftUI; fall back to the
                            // single-page UI. (UITesting does not yet build for tvOS anyway:
                            // TestEmulatorScene uses iOS-only commands/keyboard-shortcut APIs.)
                            RetroMainView()
                                .environmentObject(appDelegate)
                                .environmentObject(ThemeManager.shared)
                                .edgesIgnoringSafeArea(.all)
                            #endif
                        case .uikit:
                            UIKitHostedProvenanceMainView(appDelegate: appDelegate)
                                .environmentObject(appDelegate)
                                .edgesIgnoringSafeArea(.all)
                        }
                    }
                    .onAppear {
                        ILOG("ContentView: MainView appeared")
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: sceneCoordinator.currentScene)
                    .hideHomeIndicator()
                    // Marker for UITests: bootup finished and the main UI is on screen.
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("screenshot.mainContent")
                }
            } else if case .completed = bootupState, !showCompletedContent {
                // Show bootup view for 1 second before transitioning
                bootupView
            } else if case .error(let error) = bootupState {
                RetroErrorView(error: error) {
                    appState.startBootupSequence()
                }
                .transition(.opacity)
                .animation(.easeInOut, value: bootupState)
                .hideHomeIndicator()
            } else {
                bootupView
            }
        }
        .edgesIgnoringSafeArea(.all)
        .id(forceRefresh) // Force view refresh when this changes
        .onAppear {
            ILOG("ContentView: Appeared with bootup state: \(bootupState.localizedDescription)")

//            // Force a refresh after a delay if we're in Database Initialized state
//            if case .databaseInitialized = bootupState {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                    ILOG("ContentView: Forcing refresh for Database Initialized state")
//                    forceRefresh.toggle()
//                }
//            }
//
//            // If we're already in completed state, force a refresh
//            if case .completed = bootupState, showCompletedContent {
//                // Refresh with delay to ensure the UI updates
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    ILOG("ContentView: Forcing immediate refresh for already Completed state")
//                    forceRefresh.toggle()
//                }
//            }
        }
        .onChange(of: bootupState) { newState in
            ILOG("ContentView: Bootup state changed to \(newState.localizedDescription)")

            // Force refresh when state changes to completed
//            if case .completed = newState {
//                // Use multiple delayed refreshes with different intervals to ensure UI updates
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    ILOG("ContentView: Forcing first refresh after state changed to completed")
//                    forceRefresh.toggle()
//                }
//
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                    ILOG("ContentView: Forcing second refresh after state changed to completed")
//                    forceRefresh.toggle()
//                }
//
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    ILOG("ContentView: Forcing third refresh after state changed to completed")
//                    forceRefresh.toggle()
//                }
//            }
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
#endif
