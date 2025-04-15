//
//  MainView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLogging
import PVUIBase
import PVSwiftUI
import PVThemes
import Perception

struct MainView: View {
    /// Use EnvironmentObject for app state
    @EnvironmentObject private var appState: AppState
    /// Use EnvironmentObject for app delegate
    @EnvironmentObject private var appDelegate: PVAppDelegate

    @EnvironmentObject private var sceneCoordinator: SceneCoordinator

    var body: some View {
        WithPerceptionTracking {
            Group {
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
                    case .uikit:
                        UIKitHostedProvenanceMainView(appDelegate: appDelegate)
                            .environmentObject(appDelegate)
                            .edgesIgnoringSafeArea(.all)
                    }
                }
            }
            .onAppear {
                ILOG("MainView: Appeared")
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}
