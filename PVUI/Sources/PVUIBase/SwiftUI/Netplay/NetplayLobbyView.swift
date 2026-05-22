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
/// action tiles, and quick-access to settings.
///
/// Presented sheet-style from:
///   - Long-press context menu on a game: "Network Play"
///   - Pause menu: "Network Play"
@MainActor
public struct NetplayLobbyView: View {
    let gameName: String
    let coreIdentifier: String
    /// MD5 hash of the local ROM — threaded down to the room browser for hash verification.
    /// Pass an empty string if unknown (verification will show "unknown" state).
    let localGameHash: String

    @State private var showRoomBrowser = false
    @State private var showSpectate = false
    @State private var showCreateRoom = false
    @State private var showSettings = false
    @State private var showGameCenter = false

    private var isNetplayEnabled: Bool {
        Defaults[.netplayEnabled]
    }

    @Environment(\.dismiss) private var dismiss

    public init(gameName: String, coreIdentifier: String, localGameHash: String = "") {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
        self.localGameHash = localGameHash
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Game info header
                gameHeader

                // Action tiles
                ScrollView {
                    VStack(spacing: 16) {
                        if !isNetplayEnabled {
                            Label("Netplay is disabled. Enable it in Settings > Advanced > Feature Flags.", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }

                        actionTile(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Host a Room",
                            subtitle: "Invite friends to join your game",
                            color: .blue
                        ) {
                            showCreateRoom = true
                        }
                        .disabled(!isNetplayEnabled)

                        actionTile(
                            icon: "list.bullet.rectangle",
                            title: "Browse Rooms",
                            subtitle: "Join a game in progress on your network",
                            color: .green
                        ) {
                            showRoomBrowser = true
                        }
                        .disabled(!isNetplayEnabled)

                        actionTile(
                            icon: "eye",
                            title: "Spectate",
                            subtitle: "Watch a room without playing",
                            color: .orange
                        ) {
                            showSpectate = true
                        }
                        .disabled(!isNetplayEnabled)

#if canImport(GameKit)
                        actionTile(
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
            .navigationTitle("Network Play")
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
                }
            }
            .sheet(isPresented: $showRoomBrowser) {
                NetplayRoomBrowserView(gameName: gameName, coreIdentifier: coreIdentifier, localGameHash: localGameHash, spectateMode: false)
            }
            .sheet(isPresented: $showSpectate) {
                NetplayRoomBrowserView(gameName: gameName, coreIdentifier: coreIdentifier, localGameHash: localGameHash, spectateMode: true)
            }
            .sheet(isPresented: $showCreateRoom) {
                NetplayCreateRoomView(gameName: gameName, coreIdentifier: coreIdentifier)
            }
            .sheet(isPresented: $showSettings) {
                NetplaySettingsView()
            }
#if canImport(GameKit)
            .sheet(isPresented: $showGameCenter) {
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
                Text(coreIdentifier)
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
            Text(isEnabled ? "Netplay: Available" : "Netplay: Disabled")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func actionTile(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            #if os(tvOS)
            .background(Color.white.opacity(0.1))
            #elseif canImport(UIKit)
            .background(Color(.secondarySystemGroupedBackground))
            #else
            .background(Color(.controlBackgroundColor))
            #endif
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#endif
