//
//  MainView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLogging
import PVLibrary
import PVUIBase
import PVSwiftUI
import PVThemes
import Perception

struct MainView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appDelegate: PVAppDelegate
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator

    #if os(iOS)
    @StateObject private var gamepadManager = GamepadManager.shared
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
                    if isEmulatorActive {
                        emulatorView
                    } else {
                        #if os(iOS)
                        iOSContentView(useTVMedia: useTVMedia)
                            .animation(.easeInOut(duration: 0.32), value: useTVMedia)
                            .onAppear { effectiveUseTVMedia = rawUseTVMedia }
                            .onChange(of: rawUseTVMedia) { newValue in
                                handleTVMediaChange(newValue)
                            }
                        #else
                        tvOSContentView
                        #endif
                    }
                }
            }
            .onAppear {
                ILOG("MainView: Appeared")
            }
            .edgesIgnoringSafeArea(.all)
            // Pre-launch Transfer Pak setup sheet — covers all UI modes (RetroMainView,
            // TVMediaMainView, UIKit) so the launch continuation is never left pending.
            // Presentation is derived from preLaunchTransferPakGame (single source of truth).
            // launchAction is the single callback for button taps; the sheet's own onDismiss
            // handles swipe-to-dismiss so no duplicate closures are needed.
            .sheet(item: $sceneCoordinator.preLaunchTransferPakGame, onDismiss: {
                // onDismiss fires after the sheet animation fully completes.
                // Resume the launch continuation here (not in launchAction) so that
                // openEmulatorScene() is called only after the sheet is fully gone,
                // preventing a SwiftUI freeze from racing sheet dismissal with root-view replacement.
                SceneCoordinator.shared.dismissPreLaunchTransferPak()
            }) { game in
                TransferPakConfigView(
                    game: game,
                    launchAction: {
                        // Only dismiss the sheet; onDismiss resumes the continuation.
                        SceneCoordinator.shared.dismissPreLaunchTransferPakSheet()
                    }
                )
            }
        }
    }

    // MARK: - State Checks

    private var isEmulatorActive: Bool {
        sceneCoordinator.currentScene == .emulator
            && sceneCoordinator.showEmulator
            && appState.emulationUIState.currentGame != nil
    }

    // MARK: - Emulator

    @ViewBuilder
    private var emulatorView: some View {
        ZStack {
            EmulatorContainerView()
        }
        .onAppear {
            ILOG("ContentView: EmulatorContainerView appeared")
        }
        .transition(.opacity)
        .animation(.easeInOut, value: sceneCoordinator.currentScene)
        .hideHomeIndicator()
    }

    // MARK: - Main UI Mode

    /// Resolves the current main UI mode into the appropriate root view
    @ViewBuilder
    private var mainUIForCurrentMode: some View {
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

    // MARK: - Platform Content

    #if os(iOS)
    @ViewBuilder
    private func iOSContentView(useTVMedia: Bool) -> some View {
        Group {
            if useTVMedia, #available(iOS 17.0, *) {
                TVMediaMainView()
                    .environmentObject(appDelegate)
                    .environmentObject(ThemeManager.shared)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                mainUIForCurrentMode
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
    }

    private func handleTVMediaChange(_ newValue: Bool) {
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

    private func shouldUseTVMediaUI(isLandscape: Bool) -> Bool {
        guard isLandscape, gamepadManager.isControllerConnected else { return false }
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }
    #else
    @ViewBuilder
    private var tvOSContentView: some View {
        mainUIForCurrentMode
    }
    #endif
}
