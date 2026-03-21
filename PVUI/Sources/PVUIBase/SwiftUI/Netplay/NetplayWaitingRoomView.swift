//
//  NetplayWaitingRoomView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if !os(watchOS)
import SwiftUI
import PVNetplay
#if canImport(Darwin)
import Darwin
#endif

/// Waiting room shown after a host creates a room, while waiting for players to join.
///
/// Displays the room name, game info, connected players, spectator count,
/// connection info (IP + port), and buttons to start the game or cancel hosting.
///
/// Navigated to from `NetplayCreateRoomView` after `netplay.host()` succeeds.
@MainActor
public struct NetplayWaitingRoomView: View {
    let gameName: String
    let coreIdentifier: String
    let settings: NetplaySettings

    /// Bound to NetplayCreateRoomView; set to true before dismissing so the
    /// parent knows the session should remain active (game is starting).
    @Binding var gameStarted: Bool

    @StateObject private var netplay = ObservableNetplayManager.shared
    @State private var localIP: String = ""

    @Environment(\.dismiss) private var dismiss

    public init(gameName: String, coreIdentifier: String, settings: NetplaySettings, gameStarted: Binding<Bool> = .constant(false)) {
        self.gameName = gameName
        self.coreIdentifier = coreIdentifier
        self.settings = settings
        self._gameStarted = gameStarted
    }

    // MARK: - Derived State

    private var connectedPeers: [NetplayPeer] {
        if case .connected(let session) = netplay.state {
            return session.peers.filter { !$0.isSpectator }
        }
        return []
    }

    private var spectatorPeers: [NetplayPeer] {
        if case .connected(let session) = netplay.state {
            return session.peers.filter { $0.isSpectator }
        }
        return []
    }

    /// Number of remote players connected (not counting self).
    private var remotePeerCount: Int {
        switch netplay.state {
        case .hosting(let room):
            // room.currentPlayers reflects the placeholder set at host() time and
            // may not be updated when peers connect. Use it as a best-effort count.
            return max(0, room.currentPlayers - 1)
        case .connected(let session):
            return session.peers.filter { !$0.isSpectator }.count
        default:
            return 0
        }
    }

    /// Start Game is enabled once we can confirm peers have joined.
    ///
    /// During `.hosting` state `PVNetplayManager` does not update `currentPlayers`
    /// after `host()` resolves, so `remotePeerCount` is unreliable. Allow the host
    /// to start from `.hosting` state; the session will reflect actual peers.
    /// When in `.connected` state the session peer list is authoritative.
    private var canStartGame: Bool {
        switch netplay.state {
        case .connected(let session):
            return session.peers.contains { !$0.isSpectator }
        case .hosting:
            return true
        default:
            return false
        }
    }

    private var spectatorCount: Int {
        switch netplay.state {
        case .hosting(let room): return room.spectatorCount
        case .connected(let session): return session.peers.filter { $0.isSpectator }.count
        default: return 0
        }
    }

    private var isHosting: Bool {
        switch netplay.state {
        case .hosting, .connected: return true
        default: return false
        }
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            List {
                roomHeaderSection
                connectionInfoSection
                playersSection
                if settings.allowSpectators && spectatorCount > 0 {
                    spectatorsSection
                }
                startGameSection
            }
            .navigationTitle("Waiting Room")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .destructive) {
                        cancelRoom()
                    }
                }
            }
            .onAppear {
                localIP = Self.localIPAddress()
            }
            .onChange(of: netplay.state) { _, newState in
                if case .idle = newState {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var roomHeaderSection: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.roomName)
                        .font(.headline)
                    Text(gameName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(coreIdentifier)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                if isHosting {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var connectionInfoSection: some View {
        Section("Connection Info") {
            LabeledContent("Room Name", value: settings.roomName)
            LabeledContent("IP Address") {
                if localIP.isEmpty {
                    Text("Detecting…")
                        .foregroundStyle(.secondary)
                } else {
                    Text(localIP)
                        #if !os(tvOS)
                        .textSelection(.enabled)
                        #endif
                        .foregroundStyle(.primary)
                }
            }
            LabeledContent("Port") {
                if settings.port == 0 {
                    Text("Auto (OS-assigned)")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(settings.port)")
                }
            }
            if !localIP.isEmpty && settings.port != 0 {
                LabeledContent("Join Code", value: "\(localIP):\(settings.port)")
                    .font(.callout.monospaced())
            } else if !localIP.isEmpty {
                LabeledContent("Join Code") {
                    Text("Available after connecting")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var playersSection: some View {
        Section {
            let hostNickname = settings.nickname.isEmpty ? "You" : settings.nickname
            playerRow(
                nickname: hostNickname,
                playerIndex: 0,
                pingMS: nil,
                isHost: true,
                isSpectator: false
            )

            if remotePeerCount == 0 {
                HStack {
                    ProgressView()
                        .scaleEffect(0.75)
                    Text("Waiting for players to join…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            } else if !connectedPeers.isEmpty {
                ForEach(connectedPeers) { peer in
                    playerRow(
                        nickname: peer.nickname,
                        playerIndex: peer.playerIndex,
                        pingMS: peer.pingMS,
                        isHost: false,
                        isSpectator: false
                    )
                }
            } else {
                ForEach(0..<remotePeerCount, id: \.self) { index in
                    playerRow(
                        nickname: "Player \(index + 2)",
                        playerIndex: index + 1,
                        pingMS: nil,
                        isHost: false,
                        isSpectator: false
                    )
                }
            }
        } header: {
            Text("Players (\(remotePeerCount + 1)/\(settings.maxPlayers))")
        }
    }

    private var spectatorsSection: some View {
        Section("Spectators (\(spectatorCount))") {
            if spectatorPeers.isEmpty {
                Text("\(spectatorCount) spectator(s) connected")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                ForEach(spectatorPeers) { peer in
                    playerRow(
                        nickname: peer.nickname,
                        playerIndex: peer.playerIndex,
                        pingMS: peer.pingMS,
                        isHost: false,
                        isSpectator: true
                    )
                }
            }
        }
    }

    private var startGameSection: some View {
        Section {
            Button {
                startGame()
            } label: {
                HStack {
                    Spacer()
                    Text("Start Game")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(!canStartGame)

            if !canStartGame {
                Text("Waiting for at least one player to join before starting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Player Row

    @ViewBuilder
    private func playerRow(
        nickname: String,
        playerIndex: Int,
        pingMS: Int?,
        isHost: Bool,
        isSpectator: Bool
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSpectator ? Color.secondary.opacity(0.15)
                          : isHost ? Color.blue.opacity(0.15)
                          : Color.green.opacity(0.15))
                    .frame(width: 36, height: 36)
                if isSpectator {
                    Image(systemName: "eye.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("P\(playerIndex + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(isHost ? .blue : .green)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(nickname)
                        .font(.headline)
                    if isHost {
                        Text("HOST")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Group {
                    if let ms = pingMS {
                        Label("\(ms)ms", systemImage: "waveform.path.ecg")
                    } else if isHost {
                        Label("Local", systemImage: "house.fill")
                    } else {
                        Label("Connecting", systemImage: "ellipsis")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func startGame() {
        gameStarted = true
        dismiss()
    }

    private func cancelRoom() {
        // Just dismiss — teardown is owned by NetplayCreateRoomView's onDismiss,
        // which disconnects when gameStarted is false.
        dismiss()
    }

    // MARK: - Helpers

    /// Returns the first non-loopback IPv4 address of the device.
    private static func localIPAddress() -> String {
        #if canImport(Darwin)
        var address = ""
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return "" }
        defer { freeifaddrs(ifaddr) }
        var ptr = ifaddr
        while let ifa = ptr {
            let flags = Int32(ifa.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            guard let ifaAddr = ifa.pointee.ifa_addr else {
                ptr = ifa.pointee.ifa_next
                continue
            }
            let addr = ifaAddr.pointee
            if isUp && isRunning && !isLoopback && addr.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    ifaAddr,
                    socklen_t(addr.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil, 0,
                    NI_NUMERICHOST
                ) == 0 {
                    address = String(cString: hostname)
                    break
                }
            }
            ptr = ifa.pointee.ifa_next
        }
        return address
        #else
        return ""
        #endif
    }
}
#endif
