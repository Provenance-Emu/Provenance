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

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var sceneCoordinator: TestSceneCoordinator

    // State to force view refresh
    @State private var forceRefresh: Bool = false

    init() {
        ILOG("ContentView: init() called, current bootup state: \(AppState.shared.bootupStateManager.currentState.localizedDescription)")
    }

    // State to track delayed transition
    @State private var showCompletedContent: Bool = false
    
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
                        MainView()
                    }
                    .onAppear {
                        ILOG("ContentView: MainView appeared")
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: sceneCoordinator.currentScene)
                    .hideHomeIndicator()
                }
            } else if case .completed = bootupState, !showCompletedContent {
                // Show bootup view for 1 second before transitioning
                BootupView()
                    .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .transition(.opacity)
                    .animation(.easeInOut, value: bootupState)
                    .hideHomeIndicator()
                    .onAppear {
                        // Schedule transition after 1 second
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            withAnimation {
                                showCompletedContent = true
                            }
                        }
                    }
            } else if case .error(let error) = bootupState {
                ErrorView(error: error) {
                    appState.startBootupSequence()
                }
                .transition(.opacity)
                .animation(.easeInOut, value: bootupState)
                .hideHomeIndicator()
            } else {
                BootupView()
                    .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .transition(.opacity)
                    .animation(.easeInOut, value: bootupState)
                    .hideHomeIndicator()
            }
        }
        .edgesIgnoringSafeArea(.all)
        .id(forceRefresh) // Force view refresh when this changes
        .onAppear {
            ILOG("ContentView: Appeared with bootup state: \(bootupState.localizedDescription)")

            // Force a refresh after a delay if we're in Database Initialized state
            if case .databaseInitialized = bootupState {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    ILOG("ContentView: Forcing refresh for Database Initialized state")
                    forceRefresh.toggle()
                }
            }

            // If we're already in completed state, force a refresh
            if case .completed = bootupState, showCompletedContent {
                // Multiple refreshes with different delays to ensure the UI updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    ILOG("ContentView: Forcing immediate refresh for already Completed state")
                    forceRefresh.toggle()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ILOG("ContentView: Forcing second refresh for already Completed state")
                    forceRefresh.toggle()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ILOG("ContentView: Forcing third refresh for already Completed state")
                    forceRefresh.toggle()
                }
            }
        }
        .onChange(of: bootupState) { newState in
            ILOG("ContentView: Bootup state changed to \(newState.localizedDescription)")

            // Force refresh when state changes to completed
            if case .completed = newState {
                // Use multiple delayed refreshes with different intervals to ensure UI updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    ILOG("ContentView: Forcing first refresh after state changed to completed")
                    forceRefresh.toggle()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    ILOG("ContentView: Forcing second refresh after state changed to completed")
                    forceRefresh.toggle()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    ILOG("ContentView: Forcing third refresh after state changed to completed")
                    forceRefresh.toggle()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState.shared)
        .environmentObject(ThemeManager.shared)
}
