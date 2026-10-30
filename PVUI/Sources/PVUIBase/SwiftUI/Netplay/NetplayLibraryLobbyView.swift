// Copyright © 2026 Provenance Emu. All rights reserved.
#if !os(watchOS)
import SwiftUI
import PVNetplay
import PVLibrary
import PVRealm
import RealmSwift
import PVLogging
import Defaults
import PVSettings

/// Library-first network play. Eligibility is evaluated before every list is ranked.
@MainActor
public struct NetplayLibraryLobbyView: View {
    private let initialGameMD5: String?
    @StateObject private var discovery = PVNetplayBonjourDiscovery()
    @Environment(\.dismiss) private var dismiss
    @AppStorage(NetplayDefaultsKey.showUnverified) private var showUnverified = false
    @AppStorage(NetplayDefaultsKey.playStyle) private var playStyle = "any"
    @State private var query = ""
    @State private var list = NetplayGameList.suggested
    @State private var entries: [NetplayLibraryEligibility.Entry] = []
    @State private var selected: NetplayLibraryEligibility.Entry?
    @State private var showSettings = false
    @State private var showRooms = false
    @State private var pageLimit = 40
    @State private var pendingLaunch: (PVGame, NetplayGameOption, NetplayLaunchIntent.Action, String?)?
    @State private var errorMessage: String?
    @State private var didOpenInitialGame = false

    public init(initialGameMD5: String? = nil) { self.initialGameMD5 = initialGameMD5 }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pick a game. Bring your friends.").font(.title2.bold())
                    .accessibilityIdentifier("netplay.hub.heading")
                Text("Host a multiplayer game or join a compatible room nearby.").foregroundStyle(.secondary)
                #if os(tvOS)
                TextField("Game or system", text: $query)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .padding(16)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("netplay.hub.search")
                #endif
                if !Defaults[.netplayEnabled] {
                    Label("Enable Netplay in Settings > Advanced to host or join.", systemImage: "exclamationmark.triangle")
                }
                #if os(tvOS)
                HStack(alignment: .top, spacing: 48) {
                    gamesPanel.frame(maxWidth: .infinity)
                    roomsPanel.frame(maxWidth: 520)
                }
                #else
                Picker("Browse", selection: $showRooms) {
                    Text("Your Games").tag(false)
                    Text("Nearby Rooms").tag(true)
                }.pickerStyle(.segmented)
                    .accessibilityIdentifier("netplay.panes")
                if showRooms { roomsPanel } else { gamesPanel }
                #endif
            }
            .padding(.horizontal, horizontalInset)
            .padding(.top, topInset)
            .netplayScreen()
            .netplayNavigationTitle("Network Play")
            #if !os(tvOS)
            .searchable(text: $query, prompt: "Game or system")
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("netplay.hub.done")
                }
                ToolbarItem(placement: .primaryAction) {
                    #if os(tvOS)
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("netplay.hub.settings")
                    #else
                    Button("Settings", systemImage: "gearshape") { showSettings = true }.accessibilityIdentifier("netplay.hub.settings")
                    #endif
                }
            }
        }
        .netplayPresentation(isPresented: $showSettings, onDismiss: refresh) { NetplaySettingsView() }
        .netplayPresentation(item: $selected, onDismiss: launchPending) { entry in
            NetplayLibraryGameDetail(entry: entry, rooms: discovery.rooms, onMetadataChanged: refresh) { option, action, password in
                pendingLaunch = (entry.game, option, action, password)
                selected = nil
            }
        }
        .task {
            refresh()
            discovery.startDiscovery()
            if !didOpenInitialGame, let initialGameMD5 {
                didOpenInitialGame = true
                selected = entries.first { $0.id == initialGameMD5 }
            }
        }
        .onDisappear {
            // A TV child cover hides the hub too. Keep rooms alive while its details are open.
            if selected == nil && !showSettings { discovery.stopDiscovery() }
        }
        .onChange(of: showUnverified) { _, enabled in if !enabled && list == .unverified { list = .suggested } }
        .onChange(of: list) { _, _ in pageLimit = 40 }
        .onChange(of: query) { _, _ in pageLimit = 40 }
        .alert("Network Play", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var horizontalInset: CGFloat {
        #if os(tvOS)
        64
        #else
        20
        #endif
    }

    private var topInset: CGFloat {
        #if os(tvOS)
        80
        #else
        20
        #endif
    }

    private var gamesPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Game list", selection: $list) {
                ForEach(NetplayGameList.allCases.filter { $0 != .unverified || showUnverified }, id: \.self) { item in
                    Text(item.title)
                        #if os(tvOS)
                        // The native TV selection capsule is white even in a dark theme.
                        .foregroundStyle(item == list ? Color.black : Color.primary)
                        #endif
                        .tag(item)
                }
            }
            .accessibilityIdentifier("netplay.gameList")
            #if !os(tvOS)
            .pickerStyle(.menu)
            #endif
            if list == .unverified {
                Text("Multiplayer details are missing. These games are never recommended. Select one to review its details.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ScrollView {
                let visible = visibleEntries
                if visible.isEmpty {
                    ContentUnavailableView(list == .unverified ? "No Unverified Games" : "No Compatible Games", systemImage: "gamecontroller",
                                           description: Text("Games need multiplayer details and an installed core for that mode. Enable Unverified in Settings to review missing details."))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: cardWidth), spacing: 28)], spacing: 28) {
                    ForEach(visible.prefix(pageLimit)) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            GameItemView(game: entry.game) { selected = entry }
                                .accessibilityIdentifier("netplay.game.\(entry.id)")
                            Text(entry.eligibility.options.first?.mode.title ?? "Multiplayer unverified")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                if visible.count > pageLimit {
                    Button("Show More (\(visible.count) games)") { pageLimit += 40 }.buttonStyle(.bordered)
                }
            }
        }
    }

    private var cardWidth: CGFloat {
        #if os(tvOS)
        230
        #else
        140
        #endif
    }

    private var visibleEntries: [NetplayLibraryEligibility.Entry] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = entries.filter { entry in
            let matchesSearch = search.isEmpty || entry.game.title.localizedStandardContains(search)
                || (entry.game.system?.name.localizedStandardContains(search) ?? false)
            let options = entry.eligibility.options
            let matchesStyle = list == .unverified || playStyle == "any"
                || options.contains { playStyle == "shared" ? $0.mode.isSharedConsole : !$0.mode.isSharedConsole }
            return matchesSearch && matchesStyle
        }
        let snapshots = filtered.map { entry in
            NetplayRankedGame(id: entry.id, title: entry.game.title, system: entry.game.system?.name ?? entry.game.systemIdentifier,
                              favorite: entry.game.isFavorite, lastPlayed: entry.game.lastPlayed,
                              hasJoinableRoom: discovery.rooms.contains { NetplayLibraryEligibility.option(for: $0, entry: entry) != nil && !$0.isPasswordProtected },
                              eligibility: entry.eligibility)
        }
        let byID = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
        return NetplayRankedGame.select(snapshots, list: list).compactMap { byID[$0.id] }
    }

    private var roomsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Rooms Nearby").font(.title3.bold())
                if discovery.rooms.isEmpty {
                    Label("Looking for rooms nearby", systemImage: "antenna.radiowaves.left.and.right")
                    Text("Use the same Wi-Fi or Ethernet network and allow Local Network access.").foregroundStyle(.secondary)
                }
                ForEach(discovery.rooms.sorted { $0.gameName.localizedStandardCompare($1.gameName) == .orderedAscending }) { room in
                    let match = Self.match(room)
                    let entry = match.game.flatMap { game in entries.first { $0.id == game.md5Hash } }
                    let ready = entry.flatMap { NetplayLibraryEligibility.option(for: room, entry: $0) } != nil
                    NetplayActionCard(title: room.gameName, subtitle: "\(room.hostName) · \(room.playerCountDisplay) · \(roomState(room, entry: entry, ready: ready))",
                                      icon: room.isPasswordProtected ? "lock.fill" : "person.2.fill") {
                        selected = entry
                    }
                    .disabled(entry == nil || !Defaults[.netplayEnabled])
                }
                Button("Refresh Rooms", systemImage: "arrow.clockwise") {
                    discovery.stopDiscovery()
                    discovery.startDiscovery()
                    refresh()
                }.buttonStyle(.bordered)
            }
            .padding(12)
        }
    }

    private func roomState(_ room: NetplayRoom, entry: NetplayLibraryEligibility.Entry?, ready: Bool) -> String {
        if entry == nil { return "Not in your library" }
        if room.isFull { return "Full" }
        if ready { return room.isPasswordProtected ? "Password required" : "Join" }
        if room.gameHash.caseInsensitiveCompare(entry?.id ?? "") != .orderedSame { return "Different ROM — matching file required" }
        return "Compatibility unverified or unsupported"
    }

    private func refresh() {
        let available = NetplayLibraryEligibility.availableCores(in: Self.realm)
        entries = Self.localGames(in: Self.realm, matching: "", limit: Int.max).games.map {
            NetplayLibraryEligibility.entry($0, realm: Self.realm, available: available)
        }
    }

    private func launchPending() {
        guard let (game, option, action, password) = pendingLaunch else { return }
        pendingLaunch = nil
        guard Defaults[.netplayEnabled],
              let liveGame = Self.realm.object(ofType: PVGame.self, forPrimaryKey: game.md5Hash),
              NetplayLibraryEligibility.entry(liveGame, realm: Self.realm).eligibility.options.contains(option),
              let core = Self.realm.object(ofType: PVCore.self, forPrimaryKey: option.core.coreIdentifier) else {
            refresh()
            errorMessage = "The selected core or game is no longer available."
            return
        }
        dismiss()
        Task { @MainActor in
            await ObservableNetplayManager.shared.setLaunchIntent(NetplayLaunchIntent(action: action, gameMD5: game.md5Hash,
                                                                                     option: option, password: password))
            try? await Task.sleep(for: .milliseconds(400))
            SceneCoordinator.shared.launchGame(game, core: core)
        }
    }

    private static var realm: Realm { RomDatabase.sharedInstance.realm }
    nonisolated static let gamePickerLimit = 200

    /// Local library candidates. Final eligibility also checks file presence and installed cores.
    static func localGames(in realm: Realm, matching query: String, limit: Int = NetplayLibraryLobbyView.gamePickerLimit) -> (games: [PVGame], total: Int) {
        var results = realm.objects(PVGame.self).filter("contentless == false AND isDownloaded == true AND isHiddenPatchVariant == false")
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty { results = results.filter("title CONTAINS[cd] %@ OR system.name CONTAINS[cd] %@", search, search) }
        return (results.sorted(byKeyPath: "title").prefix(limit).map { $0.freeze() }, results.count)
    }

    static func match(_ room: NetplayRoom) -> NetplayGameMatch<PVGame> {
        NetplayGameMatcher.match(room, gameByMD5: { realm.object(ofType: PVGame.self, forPrimaryKey: $0) }, gameBySerial: { serial, system in
            realm.objects(PVGame.self).filter("romSerial == %@ AND systemIdentifier == %@", serial, system).first
        })
    }
}
#endif
