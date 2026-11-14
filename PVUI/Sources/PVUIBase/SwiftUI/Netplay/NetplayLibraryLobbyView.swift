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
    #if !os(tvOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
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
    /// The iOS controller cursor (plain state: iOS has no focus engine for buttons).
    @State private var cursor: String?
    @State private var gridWidth: CGFloat = 0
    @FocusState private var searchFocused: Bool

    public init(initialGameMD5: String? = nil) { self.initialGameMD5 = initialGameMD5 }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Pick a game. Bring your friends.").font(.title2.bold())
                    .accessibilityIdentifier("netplay.hub.heading")
                Text("Host a multiplayer game or join a compatible room nearby.").foregroundStyle(.secondary)
                headerControls
                if !Defaults[.netplayEnabled] {
                    Label("Enable Netplay in Settings > Advanced to host or join.", systemImage: "exclamationmark.triangle")
                }
                #if os(tvOS)
                HStack(alignment: .top, spacing: 48) {
                    gamesPanel.frame(maxWidth: .infinity)
                    roomsPanel.frame(maxWidth: 520)
                }
                #else
                if showRooms { roomsPanel } else { gamesPanel }
                #endif
            }
            .padding(.horizontal, horizontalInset)
            .padding(.top, topInset)
            .netplayScreen()
            .netplayNavigationTitle("Network Play")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("netplay.hub.done")
                }
            }
            #endif
            .netplayControllerNavigation(cursorRows, cursor: $cursor, isCovered: errorMessage != nil) {
                if searchFocused { searchFocused = false } else { dismiss() }
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
        .onChange(of: list) { _, _ in pageLimit = Self.pageSize }
        .onChange(of: query) { _, _ in pageLimit = Self.pageSize }
        .pvAlert(item: $errorMessage) { message in
            PVAlert(title: "Network Play", message: message, type: .error)
        }
    }

    private static let pageSize = 40

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

    /// Search, the games/rooms switch (iOS; TV shows both side by side) and Settings, in the
    /// content rather than the toolbar, so the focus engine and the controller cursor reach them.
    @ViewBuilder
    private var headerControls: some View {
        #if os(tvOS)
        HStack(spacing: 12) {
            searchField
            settingsButton
        }
        #else
        if searchHasOwnRow {
            // A phone has no room for the field beside the panes: it shrank to an ellipsis.
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    paneChips
                    Spacer(minLength: 0)
                    settingsButton
                }
                searchField
            }
        } else {
            HStack(spacing: 12) {
                paneChips
                searchField
                settingsButton
            }
        }
        #endif
    }

    #if !os(tvOS)
    private var searchHasOwnRow: Bool { horizontalSizeClass == .compact }

    private var paneChips: some View {
        ForEach([false, true], id: \.self) { rooms in
            let id = NetplayHubCursor.tab(rooms: rooms)
            NetplayChoiceChip(title: rooms ? "Nearby Rooms" : "Your Games", selected: showRooms == rooms, isCursor: cursor == id) {
                showRooms = rooms
            }
            .fixedSize()
            .netplayCursorItem(id, cursor: cursor, cornerRadius: 16)
        }
        .accessibilityIdentifier("netplay.panes")
    }
    #endif

    private var searchField: some View {
        TextField("Game or system", text: $query)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .focused($searchFocused)
            .padding(searchPadding)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .netplayCursorItem(NetplayHubCursor.search, cursor: cursor)
            .accessibilityIdentifier("netplay.hub.search")
    }

    /// Beside the panes on a phone there is room for the gear alone: the word wrapped mid-syllable.
    @ViewBuilder
    private var settingsLabel: some View {
        #if os(tvOS)
        Label("Settings", systemImage: "gearshape")
        #else
        if searchHasOwnRow {
            Label("Settings", systemImage: "gearshape").labelStyle(.iconOnly)
        } else {
            Label("Settings", systemImage: "gearshape")
        }
        #endif
    }

    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            settingsLabel
                .padding(searchPadding)
                .contentShape(Rectangle())
        }
        .retroFocusButtonStyle(focusScale: 1.05)
        .netplayCursorItem(NetplayHubCursor.settings, cursor: cursor)
        .accessibilityIdentifier("netplay.hub.settings")
    }

    private var searchPadding: CGFloat {
        #if os(tvOS)
        16
        #else
        10
        #endif
    }

    private var availableLists: [NetplayGameList] {
        NetplayGameList.allCases.filter { $0 != .unverified || showUnverified }
    }

    private var gamesPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            NetplayChoiceRow(title: "", choices: availableLists.map { ($0, $0.title) }, selection: $list,
                             cursorPrefix: NetplayHubCursor.listPrefix, cursor: cursor)
                .accessibilityIdentifier("netplay.gameList")
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: cardWidth), spacing: Self.gridSpacing)], spacing: Self.gridSpacing) {
                    ForEach(visible.prefix(pageLimit)) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            GameItemView(game: entry.game) { selected = entry }
                                .accessibilityIdentifier("netplay.game.\(entry.id)")
                            Text(entry.eligibility.options.first?.mode.title ?? "Multiplayer unverified")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .netplayCursorItem(NetplayHubCursor.game(entry.id), cursor: cursor)
                    }
                }
                .padding(Self.gridPadding)
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { gridWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { _, width in gridWidth = width }
                    }
                }
                if visible.count > pageLimit {
                    Button("Show More (\(visible.count) games)") { pageLimit += Self.pageSize }
                        .buttonStyle(.bordered)
                        .netplayCursorItem(NetplayHubCursor.showMore, cursor: cursor)
                }
            }
            #if os(tvOS)
            .focusSection()
            #endif
        }
    }

    private static let gridSpacing: CGFloat = 28
    private static let gridPadding: CGFloat = 12

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
                ForEach(sortedRooms) { room in
                    let entry = entry(for: room)
                    let ready = entry.flatMap { NetplayLibraryEligibility.option(for: room, entry: $0) } != nil
                    NetplayActionCard(title: room.gameName, subtitle: "\(room.hostName) · \(room.playerCountDisplay) · \(roomState(room, entry: entry, ready: ready))",
                                      icon: room.isPasswordProtected ? "lock.fill" : "person.2.fill") {
                        selected = entry
                    }
                    .disabled(entry == nil || !Defaults[.netplayEnabled])
                    .netplayCursorItem(NetplayHubCursor.room(room.id), cursor: cursor, cornerRadius: 18)
                }
                Button("Refresh Rooms", systemImage: "arrow.clockwise", action: refreshRooms)
                    .buttonStyle(.bordered)
                    .netplayCursorItem(NetplayHubCursor.refresh, cursor: cursor)
            }
            .padding(12)
        }
    }

    private var sortedRooms: [NetplayRoom] {
        discovery.rooms.sorted { $0.gameName.localizedStandardCompare($1.gameName) == .orderedAscending }
    }

    private func entry(for room: NetplayRoom) -> NetplayLibraryEligibility.Entry? {
        Self.match(room).game.flatMap { game in entries.first { $0.id == game.md5Hash } }
    }

    private func refreshRooms() {
        discovery.stopDiscovery()
        discovery.startDiscovery()
        refresh()
    }

    /// What the iOS controller cursor can reach, in the order it is drawn.
    private var cursorRows: [NetplayCursorRow] {
        var header: [NetplayCursorTarget] = []
        #if !os(tvOS)
        header += [false, true].map { rooms in
            NetplayCursorTarget(id: NetplayHubCursor.tab(rooms: rooms)) { showRooms = rooms }
        }
        #endif
        let search = NetplayCursorTarget(id: NetplayHubCursor.search) { searchFocused = true }
        let settings = NetplayCursorTarget(id: NetplayHubCursor.settings) { showSettings = true }
        var rows: [NetplayCursorRow]
        #if os(tvOS)
        rows = [NetplayCursorRow(id: "row.header", isHeader: true, targets: header + [search, settings])]
        #else
        if searchHasOwnRow {
            rows = [NetplayCursorRow(id: "row.header", isHeader: true, targets: header + [settings]),
                    NetplayCursorRow(id: "row.search", isHeader: true, targets: [search])]
        } else {
            rows = [NetplayCursorRow(id: "row.header", isHeader: true, targets: header + [search, settings])]
        }
        #endif
        if showRooms {
            rows += sortedRooms.map { room in
                let entry = entry(for: room)
                return .single(NetplayCursorTarget(id: NetplayHubCursor.room(room.id), isEnabled: entry != nil && Defaults[.netplayEnabled]) {
                    selected = entry
                })
            }
            rows.append(.single(NetplayCursorTarget(id: NetplayHubCursor.refresh, action: refreshRooms)))
        } else {
            rows.append(NetplayChoiceRow.cursorRow(NetplayHubCursor.listPrefix, choices: availableLists, selection: $list))
            let visible = visibleEntries
            let shown = Array(visible.prefix(pageLimit))
            let columns = ControllerGridMetrics.adaptiveColumnCount(availableWidth: gridWidth - 2 * Self.gridPadding,
                                                                    minItemWidth: cardWidth, spacing: Self.gridSpacing)
            rows += NetplayHubCursor.gridRows(shown.map(\.id), columns: columns).map { row in
                NetplayCursorRow(id: row.id, targets: row.items.compactMap { item in
                    shown.first { NetplayHubCursor.game($0.id) == item }.map { entry in
                        NetplayCursorTarget(id: item) { selected = entry }
                    }
                })
            }
            if visible.count > pageLimit {
                rows.append(.single(NetplayCursorTarget(id: NetplayHubCursor.showMore) { pageLimit += Self.pageSize }))
            }
        }
        return rows
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
/// Cursor IDs on the hub.
enum NetplayHubCursor {
    static let search = "search"
    static let settings = "settings"
    static let refresh = "refresh"
    static let showMore = "showMore"
    static let listPrefix = "list"

    static func tab(rooms: Bool) -> String { rooms ? "tab.rooms" : "tab.games" }
    static func game(_ md5: String) -> String { "game.\(md5)" }
    static func room(_ id: some CustomStringConvertible) -> String { "room.\(id)" }

    /// The games grid as cursor rows of `game(...)` IDs.
    static func gridRows(_ md5s: [String], columns: Int) -> [ControllerCursorLayout.Row] {
        ControllerCursorLayout.gridRows(md5s.map(game), columns: columns, rowPrefix: "row.games")
    }
}
#endif
