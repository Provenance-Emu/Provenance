//
//  NetplayLobbyView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVNetplay

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

    @StateObject private var netplay = ObservableNetplayManager.shared
    @State private var showRoomBrowser = false
    @State private var showCreateRoom = false
    @State private var showSettings = false
    @State private var errorMessage: String?
    @State private var showError = false

    @Environment(\.dismiss) private var dismiss

    public init(gameName: String, coreIdentifier: String) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Game info header
                gameHeader

                // Action tiles
                ScrollView {
                    VStack(spacing: 16) {
                        actionTile(
                            icon: "antenna.radiowaves.left.and.right",
                            title: "Host a Room",
                            subtitle: "Invite friends to join your game",
                            color: .blue
                        ) {
                            showCreateRoom = true
                        }

                        actionTile(
                            icon: "list.bullet.rectangle",
                            title: "Browse Rooms",
                            subtitle: "Join a game in progress on your network",
                            color: .green
                        ) {
                            showRoomBrowser = true
                        }

                        actionTile(
                            icon: "eye",
                            title: "Spectate",
                            subtitle: "Watch without playing",
                            color: .orange
                        ) {
                            showRoomBrowser = true
                        }
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
                NetplayRoomBrowserView(gameName: gameName, coreIdentifier: coreIdentifier)
            }
            .sheet(isPresented: $showCreateRoom) {
                NetplayCreateRoomView(gameName: gameName, coreIdentifier: coreIdentifier)
            }
            .alert("Netplay Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
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
        .background(Color(.systemGroupedBackground))
    }

    private var coreNetplaySupportBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Netplay: Full support")
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
