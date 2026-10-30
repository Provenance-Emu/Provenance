//
//  NetplayLobbyView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
import PVNetplay
import PVFeatureFlags
import PVSettings
import Defaults
#if canImport(GameKit)
import GameKit
#endif

/// The top-level netplay entry view shown from the pause menu or game library.
///
/// Shows the current game's netplay support badge, Host / Browse / Spectate
/// action cards, and quick-access to settings.
///
/// Presented sheet-style from the pause menu's "Network Play" action.
@MainActor
public struct NetplayLobbyView: View {
    let gameName: String
    let coreIdentifier: String
    /// MD5 hash of the local ROM — threaded down to the room browser for hash verification.
    /// Pass an empty string if unknown (verification will show "unknown" state).
    let localGameHash: String
    /// Serial / game ID and system of the local game, for the room's LAN advertisement.
    let gameSerial: String
    let systemIdentifier: String
    let coreVersion: String
    let isPatched: Bool
    let startHosting: Bool

    @State private var showRoomBrowser = false
    @State private var showSpectate = false
    @State private var showCreateRoom = false
    @State private var showSettings = false
    @State private var showGameCenter = false
    @State private var didOpenHostSetup = false

    private var isNetplayEnabled: Bool {
        Defaults[.netplayEnabled]
    }

    @Environment(\.dismiss) private var dismiss

    public init(
        gameName: String,
        coreIdentifier: String,
        localGameHash: String = "",
        gameSerial: String = "",
        systemIdentifier: String = "",
        coreVersion: String = "",
        isPatched: Bool = false,
        startHosting: Bool = false
    ) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
        self.localGameHash = localGameHash
        self.gameSerial = gameSerial
        self.systemIdentifier = systemIdentifier
        self.coreVersion = coreVersion
        self.isPatched = isPatched
        self.startHosting = startHosting
    }

    private var hostedGame: NetplayHostedGame {
        var game = NetplayHostedGame(
            name: gameName,
            md5: localGameHash,
            serial: gameSerial,
            systemIdentifier: systemIdentifier,
            coreIdentifier: coreIdentifier
        )
        game.isPatched = isPatched
        game.coreVersion = coreVersion
        return game
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Game info header
                gameHeader

                // Action cards
                ScrollView {
                    VStack(spacing: 16) {
                        if !isNetplayEnabled {
                            Label("Netplay is disabled. Enable it in Settings > Advanced > Feature Flags.", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }

                        actionCard(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Host a Room",
                            subtitle: "Let friends on your network join this game",
                            color: .blue
                        ) {
                            showCreateRoom = true
                        }
                        .disabled(!isNetplayEnabled)

                        actionCard(
                            icon: "list.bullet.rectangle",
                            title: "Browse Rooms",
                            subtitle: "Join a game in progress on your network",
                            color: .green
                        ) {
                            showRoomBrowser = true
                        }
                        .disabled(!isNetplayEnabled)

                        if NetplayCoreCompatibility.support(coreIdentifier: coreIdentifier, systemIdentifier: systemIdentifier)?.supportsSpectators == true {
                        actionCard(
                            icon: "eye",
                            title: "Spectate",
                            subtitle: "Watch a room without playing",
                            color: .orange
                        ) {
                            showSpectate = true
                        }
                        .disabled(!isNetplayEnabled)

                        }

#if canImport(GameKit)
                        actionCard(
                            icon: "person.2.wave.2",
                            title: "Game Center Match",
                            subtitle: "Find opponents via Apple Game Center",
                            color: .purple
                        ) {
                            showGameCenter = true
                        }
                        .disabled(!isNetplayEnabled)
#endif
                    }
                    .padding()
                }

                // Support badge
                coreNetplaySupportBadge
                    .padding(.bottom)
            }
            .netplayScreen()
            .onAppear {
                if startHosting && !didOpenHostSetup {
                    didOpenHostSetup = true
                    showCreateRoom = true
                }
            }
            .netplayNavigationTitle("Network Play")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Network Play Settings")
                }
            }
            .netplayPresentation(isPresented: $showRoomBrowser) {
                NetplayRoomBrowserView(gameName: gameName, coreIdentifier: coreIdentifier, localGameHash: localGameHash, spectateMode: false)
            }
            .netplayPresentation(isPresented: $showSpectate) {
                NetplayRoomBrowserView(gameName: gameName, coreIdentifier: coreIdentifier, localGameHash: localGameHash, spectateMode: true)
            }
            .netplayPresentation(isPresented: $showCreateRoom, onDismiss: { if startHosting { dismiss() } }) {
                NetplayCreateRoomView(gameName: gameName, coreIdentifier: coreIdentifier, hostedGame: hostedGame)
            }
            .netplayPresentation(isPresented: $showSettings) {
                NetplaySettingsView()
            }
#if canImport(GameKit)
            .netplayPresentation(isPresented: $showGameCenter) {
                NetplayGameCenterView(gameName: gameName, coreIdentifier: coreIdentifier, localGameHash: localGameHash)
            }
#endif
        }
    }

    // MARK: - Subviews

    private var gameHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "gamecontroller.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(gameName)
                    .font(.headline)
                    .lineLimit(1)
                Text("Play together on your local network")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding()
        #if os(tvOS)
        .background(Color.black.opacity(0.3))
        #elseif canImport(UIKit)
        .background(Color(.systemGroupedBackground))
        #else
        .background(Color.primary.opacity(0.05))
        #endif
    }

    /// Badge reflecting the netplay feature-flag state.
    /// Shows "Disabled" when the feature flag is off, "Available" when on.
    /// Core-specific capability detection is deferred to a later phase.
    private var coreNetplaySupportBadge: some View {
        let isEnabled = Defaults[.netplayEnabled]
        return HStack(spacing: 6) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isEnabled ? .green : .secondary)
            Text(isEnabled ? "Network Play enabled" : "Network Play disabled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func actionCard(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        NetplayActionCard(title: title, subtitle: subtitle, icon: icon, color: color, action: action)
    }
}

#endif
