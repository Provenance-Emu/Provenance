//
//  NetplayLibraryLobbyView.swift
//  PVUI
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Netplay from the library, before any game is running: lists the rooms
//  hosted on the local network, finds each room's game in this library, and
//  launches it straight into the room. Hosting launches a recent game and
//  opens its Network Play menu.
//
//  Design: docs/superpowers/specs/2026-10-15-netplay-library-lobby-design.md
//

#if !os(watchOS)
import SwiftUI
import PVNetplay
import PVLibrary
import PVRealm
import RealmSwift
import PVLogging
import Defaults
import PVSettings

@MainActor
public struct NetplayLibraryLobbyView: View {
    /// This view's own browser: the shared one's stopDiscovery() would clear
    /// the rooms of every other screen browsing at the same time.
    @StateObject private var discovery = PVNetplayBonjourDiscovery()
    @State private var recentGames: [PVGame] = []

    @Environment(\.dismiss) private var dismiss

    private enum Layout {
        static let recentGameCount = 20
        /// Let the sheet finish dismissing before the emulator is presented.
        static let launchDelay: Duration = .milliseconds(400)
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                if !Defaults[.netplayEnabled] {
                    Label("Netplay is disabled. Enable it in Settings > Advanced.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                roomsSection
                hostSection
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
                    if discovery.isSearching {
                        ProgressView()
                    }
                }
            }
        }
        .onAppear {
            discovery.startDiscovery()
            recentGames = Self.loadRecentGames(limit: Layout.recentGameCount)
        }
        .onDisappear {
            discovery.stopDiscovery()
        }
    }

    // MARK: - Rooms

    @ViewBuilder
    private var roomsSection: some View {
        SwiftUI.Section {
            if discovery.rooms.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Looking for rooms on your network…")
                        .font(.headline)
                    Text("Both devices must be on the same Wi-Fi, with Local Network access allowed for Provenance in Settings > Privacy & Security.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        discovery.stopDiscovery()
                        discovery.startDiscovery()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .padding(.vertical, 4)
            } else {
                ForEach(discovery.rooms) { room in
                    roomRow(room, match: Self.match(room))
                }
            }
        } header: {
            Text("Rooms Nearby")
        }
    }

    private func roomRow(_ room: NetplayRoom, match: NetplayGameMatch<PVGame>) -> some View {
        Button {
            guard let game = match.game, Defaults[.netplayEnabled] else { return }
            launch(game, coreIdentifier: room.coreIdentifier, action: .join(room))
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(room.hasOpenSlots ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.gameName)
                        .font(.headline)
                        .lineLimit(1)
                    Text(room.hostName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Label(room.playerCountDisplay, systemImage: "person.2")
                        if room.isPasswordProtected {
                            Image(systemName: "lock.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                matchBadge(match, roomIsFull: room.isFull)
            }
        }
        .disabled(match.game == nil || room.isFull || !Defaults[.netplayEnabled])
    }

    @ViewBuilder
    private func matchBadge(_ match: NetplayGameMatch<PVGame>, roomIsFull: Bool) -> some View {
        switch match {
        case .sameFile, .sameSerial:
            Text(roomIsFull ? "Full" : "Join")
                .font(.caption.bold())
                .foregroundStyle(roomIsFull ? Color.secondary : Color.accentColor)
        case .notInLibrary:
            Text("Not in your library")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .unknown:
            Text("Game unknown")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Host

    @ViewBuilder
    private var hostSection: some View {
        SwiftUI.Section {
            if recentGames.isEmpty {
                Text("Play a game once to host it from here, or host from its pause menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recentGames, id: \.md5Hash) { game in
                    Button {
                        launch(game, coreIdentifier: nil, action: .host)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(game.title)
                                .lineLimit(1)
                            Text(game.system?.name ?? game.systemIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!Defaults[.netplayEnabled])
                }
            }
        } header: {
            Text("Host a Game")
        } footer: {
            Text("The game starts and opens Network Play so you can create the room.")
        }
    }

    // MARK: - Launch

    private func launch(_ game: PVGame, coreIdentifier: String?, action: NetplayLaunchIntent.Action) {
        let md5 = game.md5Hash
        let core = Self.core(identifier: coreIdentifier, for: game)
        ILOG("Netplay lobby: launching \(game.title) to \(action) with core \(core?.identifier ?? "default")")
        dismiss()
        Task { @MainActor in
            await ObservableNetplayManager.shared.setLaunchIntent(NetplayLaunchIntent(action: action, gameMD5: md5))
            try? await Task.sleep(for: Layout.launchDelay)
            SceneCoordinator.shared.launchGame(game, core: core)
        }
    }

    // MARK: - Library lookups

    private static var realm: Realm { RomDatabase.sharedInstance.realm }

    static func match(_ room: NetplayRoom) -> NetplayGameMatch<PVGame> {
        NetplayGameMatcher.match(
            room,
            gameByMD5: { realm.object(ofType: PVGame.self, forPrimaryKey: $0) },
            gameBySerial: { serial, system in
                realm.objects(PVGame.self)
                    .filter("romSerial == %@ AND systemIdentifier == %@", serial, system)
                    .first
            }
        )
    }

    /// The host's core, when this library has it and it runs the game's system.
    private static func core(identifier: String?, for game: PVGame) -> PVCore? {
        guard let identifier, !identifier.isEmpty,
              let core = realm.object(ofType: PVCore.self, forPrimaryKey: identifier),
              core.supportedSystems.contains(where: { $0.identifier == game.systemIdentifier }) else { return nil }
        return core
    }

    private static func loadRecentGames(limit: Int) -> [PVGame] {
        Array(
            realm.objects(PVGame.self)
                .filter("lastPlayed != nil")
                .sorted(byKeyPath: "lastPlayed", ascending: false)
                .prefix(limit)
        )
    }
}
#endif
