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

    #if os(iOS)
    /// Shared gamepad state for controller-driven UI routing.
    @StateObject private var gamepadManager = GamepadManager.shared
    #endif

    var body: some View {
        WithPerceptionTracking {
            GeometryReader { proxy in
                let isLandscape = proxy.size.width > proxy.size.height
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
                        #if os(iOS)
                        if shouldUseTVMediaUI(isLandscape: isLandscape),
                           #available(iOS 17.0, *) {
                            TVMediaMainView()
                                .environmentObject(appDelegate)
                                .environmentObject(ThemeManager.shared)
                                .edgesIgnoringSafeArea(.all)
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
#if os(tvOS)
                    case .tvosMedia:
                        TVMediaMainView()
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
                        #else
                        switch appState.mainUIMode {
                        case .singlePage:
                            RetroMainView()
                                .environmentObject(appDelegate)
                                .environmentObject(ThemeManager.shared)
                                .edgesIgnoringSafeArea(.all)
                        case .tvosMedia:
                            TVMediaMainView()
                                .environmentObject(appDelegate)
                                .environmentObject(ThemeManager.shared)
                                .edgesIgnoringSafeArea(.all)
                        case .uikit:
                            UIKitHostedProvenanceMainView(appDelegate: appDelegate)
                                .environmentObject(appDelegate)
                                .edgesIgnoringSafeArea(.all)
                        }
                        #endif
                    }
                }
            }
            .onAppear {
                ILOG("MainView: Appeared")
            }
            .edgesIgnoringSafeArea(.all)
        }
    }

    #if os(iOS)
    /// Determines when the tvOS-style UI should be used on iPhone.
    private func shouldUseTVMediaUI(isLandscape: Bool) -> Bool {
        guard isLandscape, gamepadManager.isControllerConnected else { return false }
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }
    #endif
}
