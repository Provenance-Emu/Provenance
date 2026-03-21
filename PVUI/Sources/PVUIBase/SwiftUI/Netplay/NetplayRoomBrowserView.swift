//
//  NetplayRoomBrowserView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
import PVNetplay

/// Displays available netplay rooms discovered via Bonjour on the local network.
///
/// Automatically starts/stops Bonjour discovery when presented.
/// Rooms are polled from `PVNetplayBonjourDiscovery` and displayed in a list.
/// Tapping a room attempts to join it; when `spectateMode` is true, room
/// taps default to spectating instead of joining as a player.
@MainActor
public struct NetplayRoomBrowserView: View {
    let gameName: String
    let coreIdentifier: String
    /// When `true`, row taps spectate rather than join as a player.
    let spectateMode: Bool

    /// MD5 hash of the local ROM — used to verify against the host before joining.
    /// Pass an empty string if unknown (verification will show "unknown" state).
    let localGameHash: String

    @ObservedObject private var netplay = ObservableNetplayManager.shared
    @State private var isJoining = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showManualConnect = false
    @State private var roomToConfirm: NetplayRoom?
    @State private var showInviteSheet = false
    @State private var selectedTab: BrowserTab = .lan

    private enum BrowserTab: String, CaseIterable {
        case lan = "Local"
        case wan = "Internet"
    }

    @Environment(\.dismiss) private var dismiss

    public init(gameName: String, coreIdentifier: String, localGameHash: String = "", spectateMode: Bool = false) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
        self.localGameHash = localGameHash
        self.spectateMode = spectateMode
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tab", selection: $selectedTab) {
                    ForEach(BrowserTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Group {
                    switch selectedTab {
                    case .lan:
                        if netplay.discoveredRooms.isEmpty {
                            lanEmptyState
                        } else {
                            lanRoomList
                        }
                    case .wan:
                        wanContent
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(spectateMode ? "Find Room to Spectate" : "Browse Rooms")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        if selectedTab == .lan, netplay.bonjourDiscovery.isSearching {
                            ProgressView().scaleEffect(0.8)
                        }
                        if selectedTab == .wan, netplay.wanIsFetching {
                            ProgressView().scaleEffect(0.8)
                        }
                        Button {
                            showManualConnect = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Manual Connect")
                        .accessibilityHint("Open manual host and port form")
                    }
                }
            }
            .sheet(isPresented: $showManualConnect) {
                NetplayManualConnectView(gameName: gameName, coreIdentifier: coreIdentifier, defaultSpectate: spectateMode)
            }
            .sheet(item: $roomToConfirm) { room in
                NetplayJoinConfirmView(
                    room: room,
                    localGameHash: localGameHash
                ) {
                    roomToConfirm = nil
                    performJoin(room: room, spectate: false)
                } onCancel: {
                    roomToConfirm = nil
                }
            }
            .sheet(isPresented: $showInviteSheet) {
                NetplayInviteView(gameName: gameName)
            }
            .alert("Connection Error", isPresented: $showError, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
            .onAppear {
                netplay.startDiscovery()
                if selectedTab == .wan {
                    netplay.fetchWANRooms()
                }
            }
            .onDisappear {
                netplay.stopDiscovery()
                netplay.cancelWANFetch()
            }
            .onChange(of: selectedTab) { _, newTab in
                switch newTab {
                case .lan:
                    netplay.cancelWANFetch()
                    netplay.startDiscovery()
                case .wan:
                    netplay.stopDiscovery()
                    netplay.fetchWANRooms()
                }
            }
        }
    }

    // MARK: - Subviews

    private var lanEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Local Rooms Found")
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

    private var lanRoomList: some View {
        List {
            SwiftUI.Section {
                ForEach(netplay.discoveredRooms) { room in
                    roomRow(room)
                }
            } header: {
                Text("LOCAL NETWORK")
            } footer: {
                Text("Rooms discovered on your Wi-Fi via Bonjour.")
                    .font(.caption2)
            }
        }
    }

    @ViewBuilder
    private var wanContent: some View {
        if netplay.wanIsFetching && netplay.wanRooms.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                Text("Fetching internet rooms…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = netplay.wanLastError, netplay.wanRooms.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "globe.slash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Could Not Reach Lobby")
                    .font(.headline)
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button {
                    netplay.fetchWANRooms()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if netplay.wanRooms.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "globe")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No Internet Rooms")
                    .font(.headline)
                Text("No public rooms listed right now.\nHost a room and share the invite link with a friend.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button {
                    showInviteSheet = true
                } label: {
                    Label("Share Invite Link", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                SwiftUI.Section {
                    ForEach(netplay.wanRooms) { room in
                        roomRow(room)
                    }
                } header: {
                    HStack {
                        Text("INTERNET (\(netplay.wanRooms.count))")
                        Spacer()
                        Button {
                            netplay.fetchWANRooms()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Refresh rooms")
                        .accessibilityHint("Fetch the latest list of internet rooms")
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Public rooms from lobby.libretro.com. Rooms using the RA.ME relay server work without port forwarding.")
                            .font(.caption2)
                        Button {
                            showInviteSheet = true
                        } label: {
                            Label("Share my invite link", systemImage: "square.and.arrow.up")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .tint(.accentColor)
                    }
                }
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

            // Show a spectate button for full rooms that allow spectators,
            // unless we're already in spectate mode (the tap itself will spectate).
            if !spectateMode && room.isFull && room.allowsSpectators {
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
                join(room: room, spectate: spectateMode)
            }
        }
    }

    // MARK: - Actions

    private func join(room: NetplayRoom, spectate: Bool) {
        if spectate {
            performJoin(room: room, spectate: true)
        } else {
            // Show ROM hash confirmation before joining as a player.
            roomToConfirm = room
        }
    }

    private func performJoin(room: NetplayRoom, spectate: Bool) {
        isJoining = true
        Task { @MainActor in
            do {
                let settings = NetplaySettings.fromStoredDefaults()
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
#endif
