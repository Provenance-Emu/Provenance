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
    /// Debounced TV media mode to avoid flicker on brief controller disconnect.
    @State private var effectiveUseTVMedia: Bool = false
    @State private var disconnectTask: Task<Void, Never>?
    #endif

    var body: some View {
        WithPerceptionTracking {
            GeometryReader { proxy in
                let isLandscape = proxy.size.width > proxy.size.height
                #if os(iOS)
                let rawUseTVMedia = shouldUseTVMediaUI(isLandscape: isLandscape)
                let useTVMedia = effectiveUseTVMedia
                #endif
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
                        Group {
                            if useTVMedia, #available(iOS 17.0, *) {
                                TVMediaMainView()
                                    .environmentObject(appDelegate)
                                    .environmentObject(ThemeManager.shared)
                                    .edgesIgnoringSafeArea(.all)
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.32), value: useTVMedia)
                        .onAppear { effectiveUseTVMedia = rawUseTVMedia }
                        .onChange(of: rawUseTVMedia) { _, newValue in
                            if newValue {
                                disconnectTask?.cancel()
                                disconnectTask = nil
                                effectiveUseTVMedia = true
                            } else {
                                disconnectTask?.cancel()
                                disconnectTask = Task {
                                    try? await Task.sleep(nanoseconds: 450_000_000)
                                    guard !Task.isCancelled else { return }
                                    await MainActor.run { effectiveUseTVMedia = false }
                                }
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
