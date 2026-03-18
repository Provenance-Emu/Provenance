//
//  NetplayRoomBrowserView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVNetplay

/// Displays available netplay rooms discovered via Bonjour on the local network.
///
/// Automatically starts/stops Bonjour discovery when presented.
/// Rooms are polled from `PVNetplayBonjourDiscovery` and displayed in a list.
/// Tapping a room attempts to join it.
@MainActor
public struct NetplayRoomBrowserView: View {
    let gameName: String
    let coreIdentifier: String

    @StateObject private var netplay = ObservableNetplayManager.shared
    @State private var selectedRoom: NetplayRoom?
    @State private var joinAsSpectator = false
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showManualConnect = false

    @Environment(\.dismiss) private var dismiss

    public init(gameName: String, coreIdentifier: String) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
    }

    public var body: some View {
        NavigationStack {
            Group {
                if netplay.discoveredRooms.isEmpty {
                    emptyState
                } else {
                    roomList
                }
            }
            .navigationTitle("Browse Rooms")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        if netplay.bonjourDiscovery.isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Button {
                            showManualConnect = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showManualConnect) {
                NetplayManualConnectView(gameName: gameName, coreIdentifier: coreIdentifier)
            }
            .alert("Connection Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
            .onAppear { netplay.startDiscovery() }
            .onDisappear { netplay.stopDiscovery() }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Rooms Found")
                .font(.headline)
            Text("Looking for rooms on your local network…\nMake sure the host is running Provenance on the same Wi-Fi.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                netplay.stopDiscovery()
                netplay.startDiscovery()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var roomList: some View {
        List {
            Section {
                ForEach(netplay.discoveredRooms) { room in
                    roomRow(room)
                }
            } header: {
                Text("LOCAL NETWORK")
            } footer: {
                Text("Showing rooms on your Wi-Fi. Internet play coming soon.")
                    .font(.caption2)
            }
        }
    }

    private func roomRow(_ room: NetplayRoom) -> some View {
        HStack(spacing: 12) {
            // Status dot
            Circle()
                .fill(room.hasOpenSlots ? Color.green : Color.orange)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(room.hostName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(room.gameName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label(room.playerCountDisplay, systemImage: "person.2")
                    if let ms = room.pingMS {
                        Label("\(ms)ms", systemImage: "waveform.path.ecg")
                    }
                    if room.isPasswordProtected {
                        Image(systemName: "lock.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if room.isFull && room.allowsSpectators {
                Button {
                    join(room: room, spectate: true)
                } label: {
                    Text("Spectate")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(isJoining)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isJoining {
                join(room: room, spectate: false)
            }
        }
    }

    // MARK: - Actions

    private func join(room: NetplayRoom, spectate: Bool) {
        isJoining = true
        Task {
            do {
                let settings = NetplaySettings.defaultLAN
                if spectate {
                    try await netplay.spectate(room: room)
                } else {
                    try await netplay.join(room: room, settings: settings)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isJoining = false
        }
    }
}
