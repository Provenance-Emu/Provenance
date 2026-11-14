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
    /// The iOS controller cursor (plain state: iOS has no focus engine for buttons).
    @State private var cursor: String?

    private var isNetplayEnabled: Bool {
        Defaults[.netplayEnabled]
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var netplay = ObservableNetplayManager.shared

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

                        if let session = sessionSummary {
                            sessionCard(session)
                        } else {
                        actionCard(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Host a Room",
                            subtitle: "Let friends on your network join this game",
                            color: .blue
                        ) {
                            showCreateRoom = true
                        }
                        .disabled(!isNetplayEnabled)
                        .netplayCursorItem(NetplayLobbyCursor.host, cursor: cursor, cornerRadius: 18)

                        actionCard(
                            icon: "list.bullet.rectangle",
                            title: "Browse Rooms",
                            subtitle: "Join a game in progress on your network",
                            color: .green
                        ) {
                            showRoomBrowser = true
                        }
                        .disabled(!isNetplayEnabled)
                        .netplayCursorItem(NetplayLobbyCursor.browse, cursor: cursor, cornerRadius: 18)

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
                        .netplayCursorItem(NetplayLobbyCursor.spectate, cursor: cursor, cornerRadius: 18)

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
                        .netplayCursorItem(NetplayLobbyCursor.gameCenter, cursor: cursor, cornerRadius: 18)
#endif
                        }

                        actionCard(
                            icon: "gearshape",
                            title: "Network Play Settings",
                            subtitle: "Nickname, room size and connection defaults",
                            color: .gray
                        ) {
                            showSettings = true
                        }
                        .netplayCursorItem(NetplayLobbyCursor.settings, cursor: cursor, cornerRadius: 18)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #endif
            .netplayControllerNavigation(cursorRows, cursor: $cursor, isCovered: showGameCenter) { dismiss() }
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

    /// What the iOS controller cursor can reach, in the order it is drawn.
    private var cursorRows: [NetplayCursorRow] {
        if sessionSummary != nil {
            return [
                .single(NetplayCursorTarget(id: NetplayLobbyCursor.leave, action: leaveSession)),
                .single(NetplayCursorTarget(id: NetplayLobbyCursor.settings) { showSettings = true })
            ]
        }
        var targets = [
            NetplayCursorTarget(id: NetplayLobbyCursor.host, isEnabled: isNetplayEnabled) { showCreateRoom = true },
            NetplayCursorTarget(id: NetplayLobbyCursor.browse, isEnabled: isNetplayEnabled) { showRoomBrowser = true }
        ]
        if NetplayCoreCompatibility.support(coreIdentifier: coreIdentifier, systemIdentifier: systemIdentifier)?.supportsSpectators == true {
            targets.append(NetplayCursorTarget(id: NetplayLobbyCursor.spectate, isEnabled: isNetplayEnabled) { showSpectate = true })
        }
        #if canImport(GameKit)
        targets.append(NetplayCursorTarget(id: NetplayLobbyCursor.gameCenter, isEnabled: isNetplayEnabled) { showGameCenter = true })
        #endif
        targets.append(NetplayCursorTarget(id: NetplayLobbyCursor.settings) { showSettings = true })
        return targets.map { .single($0) }
    }

    // MARK: - Session in progress

    private struct SessionSummary {
        let title: String
        let detail: String
        let leaveTitle: String
    }

    /// The session in progress, if any. While one is up the screen shows it in place of the
    /// host and join choices, which could only fail.
    private var sessionSummary: SessionSummary? {
        switch netplay.state {
        case .hosting(let room):
            return SessionSummary(title: String(localized: "Hosting a room"),
                                  detail: String(localized: "\(room.currentPlayers) of \(room.maxPlayers) players"),
                                  leaveTitle: String(localized: "Close Room"))
        case .connected(let session):
            return SessionSummary(title: String(localized: "Connected to \(session.room.hostName)"),
                                  detail: String(localized: "Playing over the network"),
                                  leaveTitle: String(localized: "Leave Room"))
        case .connecting(let room):
            return SessionSummary(title: String(localized: "Connecting to \(room.hostName)…"),
                                  detail: "",
                                  leaveTitle: String(localized: "Cancel"))
        case .idle, .disconnected:
            return nil
        }
    }

    private func leaveSession() {
        Task { @MainActor in await netplay.disconnect() }
    }

    private func sessionCard(_ session: SessionSummary) -> some View {
        NetplayFormSection {
            Label(session.title, systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)
            if !session.detail.isEmpty {
                Text(session.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button(session.leaveTitle, role: .destructive, action: leaveSession)
                .netplayCursorItem(NetplayLobbyCursor.leave, cursor: cursor)
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

/// Cursor IDs of the in-game Network Play screen.
enum NetplayLobbyCursor {
    static let host = "host"
    static let browse = "browse"
    static let spectate = "spectate"
    static let gameCenter = "gameCenter"
    static let settings = "settings"
    static let leave = "leave"
}

#endif
