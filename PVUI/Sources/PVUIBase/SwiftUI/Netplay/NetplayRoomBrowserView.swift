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
/// Each room has a focusable Join action; in `spectateMode`, that action
/// watches the room instead of joining as a player.
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
    @State private var password = ""
    /// The iOS controller cursor (plain state: iOS has no focus engine for buttons).
    @State private var cursor: String?
    @FocusState private var passwordFocused: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.netplayReturnToGame) private var returnToGame

    public init(gameName: String, coreIdentifier: String, localGameHash: String = "", spectateMode: Bool = false) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
        self.localGameHash = localGameHash
        self.spectateMode = spectateMode
    }

    public var body: some View {
        NavigationStack {
            Group {
                if netplay.discoveredRooms.isEmpty {
                    lanEmptyState
                } else {
                    lanRoomList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .netplayScreen()
            .netplayNavigationTitle(spectateMode ? "Find Room to Spectate" : "Browse Rooms")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        if netplay.bonjourDiscovery.isSearching {
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
            #endif
            .netplayControllerNavigation(cursorRows, cursor: $cursor, isCovered: showError) {
                if passwordFocused { passwordFocused = false } else { dismiss() }
            }
            .netplayPresentation(isPresented: $showManualConnect) {
                NetplayManualConnectView(gameName: gameName, coreIdentifier: coreIdentifier, defaultSpectate: spectateMode)
            }
            .netplayPresentation(item: $roomToConfirm) { room in
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
            .netplayPresentation(isPresented: $showInviteSheet) {
                NetplayInviteView(gameName: gameName)
            }
            .pvAlert(isPresented: $showError) {
                PVAlert(title: "Connection Error", message: errorMessage, type: .error)
            }
            .onAppear {
                netplay.startDiscovery()
            }
            .onDisappear {
                netplay.stopDiscovery()
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

            listActions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Refresh and Manual Connect, in the content so the focus engine and the controller reach them.
    private var listActions: some View {
        HStack(spacing: 16) {
            Button(action: refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .netplayCursorItem(NetplayRoomBrowserCursor.refresh, cursor: cursor)
            Button {
                showManualConnect = true
            } label: {
                Label("Manual Connect", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .netplayCursorItem(NetplayRoomBrowserCursor.manual, cursor: cursor)
        }
    }

    private func refresh() {
        netplay.stopDiscovery()
        netplay.startDiscovery()
    }

    private var lanRoomList: some View {
        NetplayForm {
            listActions
            NetplayFormSection {
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

            if room.isPasswordProtected {
                SecureField("Room password", text: $password)
                    .frame(maxWidth: 220)
                    .focused($passwordFocused)
                    .netplayCursorItem(NetplayRoomBrowserCursor.password(room.id), cursor: cursor)
            }
            Button {
                join(room: room, spectate: spectateMode)
            } label: {
                Label(spectateMode ? "Spectate" : (room.isFull ? "Full" : "Join"), systemImage: spectateMode ? "eye" : "arrow.right.circle.fill")
                    .padding(12)
            }
            .retroFocusButtonStyle(focusScale: 1.025)
            .disabled(!canJoin(room))
            .netplayCursorItem(NetplayRoomBrowserCursor.join(room.id), cursor: cursor)

            // Show a spectate button for full rooms that allow spectators,
            // unless we're already in spectate mode (the tap itself will spectate).
            if offersSpectate(room) {
                Button {
                    join(room: room, spectate: true)
                } label: {
                    Text("Spectate")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(isJoining)
                .netplayCursorItem(NetplayRoomBrowserCursor.spectate(room.id), cursor: cursor)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - Controller

    private func matchesLocalGame(_ room: NetplayRoom) -> Bool {
        room.coreIdentifier == coreIdentifier && room.gameHash.caseInsensitiveCompare(localGameHash) == .orderedSame
    }

    private func canJoin(_ room: NetplayRoom) -> Bool {
        !isJoining && (spectateMode || !room.isFull) && matchesLocalGame(room)
            && (!spectateMode || room.allowsSpectators) && !(room.isPasswordProtected && password.isEmpty)
    }

    private func offersSpectate(_ room: NetplayRoom) -> Bool {
        !spectateMode && room.isFull && room.allowsSpectators && matchesLocalGame(room)
    }

    /// What the iOS controller cursor can reach, in the order it is drawn.
    private var cursorRows: [NetplayCursorRow] {
        var rows = [NetplayCursorRow(id: "row.actions", isHeader: true, targets: [
            NetplayCursorTarget(id: NetplayRoomBrowserCursor.refresh, action: refresh),
            NetplayCursorTarget(id: NetplayRoomBrowserCursor.manual) { showManualConnect = true }
        ])]
        for room in netplay.discoveredRooms {
            var targets: [NetplayCursorTarget] = []
            if room.isPasswordProtected {
                targets.append(NetplayCursorTarget(id: NetplayRoomBrowserCursor.password(room.id)) { passwordFocused = true })
            }
            targets.append(NetplayCursorTarget(id: NetplayRoomBrowserCursor.join(room.id), isEnabled: canJoin(room)) {
                join(room: room, spectate: spectateMode)
            })
            if offersSpectate(room) {
                targets.append(NetplayCursorTarget(id: NetplayRoomBrowserCursor.spectate(room.id), isEnabled: !isJoining) {
                    join(room: room, spectate: true)
                })
            }
            rows.append(NetplayCursorRow(id: "row.\(room.id)", targets: targets))
        }
        return rows
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
                guard room.coreIdentifier == coreIdentifier,
                      room.gameHash.caseInsensitiveCompare(localGameHash) == .orderedSame else { throw NetplayError.romMismatch }
                var settings = NetplaySettings.fromStoredDefaults()
                settings.password = password.isEmpty ? nil : password
                if spectate {
                    try await netplay.spectate(room: room, settings: settings)
                } else {
                    try await netplay.join(room: room, settings: settings)
                }
                NetplayJoinFeedback.joined(room.hostName, returnToGame: returnToGame, dismiss: dismiss)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isJoining = false
        }
    }
}

/// Cursor IDs of the room browser.
enum NetplayRoomBrowserCursor {
    static let refresh = "refresh"
    static let manual = "manual"

    static func password(_ room: UUID) -> String { "password.\(room)" }
    static func join(_ room: UUID) -> String { "join.\(room)" }
    static func spectate(_ room: UUID) -> String { "spectate.\(room)" }
}
#endif
