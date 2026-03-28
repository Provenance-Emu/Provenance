//
//  ConsoleGamesViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import PVUIBase
import PVRealm
import PVSettings
import Combine
import struct PVUIBase.DiscSelectionAlert

class ConsoleGamesViewModel: ObservableObject {
    let console: PVSystem
    private let consoleIdentifier: String

    /// Game controller navigation state
    @Published var focusedSection: HomeSectionType?
    /// Game controller navigation state
    @Published var focusedItemInSection: String?

    /// Disc selection alert state
    @Published var showDiscSelectionAlert = false
    /// Disc selection alert data
    @Published var discSelectionAlert: DiscSelectionAlert?

    /// Rename Game Alert State
    @Published var showingRenameAlert = false
    /// Game to rename
    @Published var gameToRename: PVGame? = nil
    /// New game title for rename alert
    @Published var newGameTitle = "" // For the TextField binding

    /// Artwork Source Alert State
    @Published var showArtworkSourceAlert = false
    @Published var gameForArtworkUpdate: PVGame? = nil

    /// Import status view properties
    @Published var showImportStatusView = false

    /// Game Info Presentation State
    @Published var selectedGameForInfo: PVGame? = nil
    @Published var showingGameInfo: Bool = false

    var gameToUpdateCover: PVGame?

    @Published var gameLibraryItemsPerRow: Int = 4
    @Published var showImagePicker = false
    @Published var showArtworkSearch = false
    @Published var selectedImage: UIImage? = nil
    @Published var renameTitleFieldIsFocused: Bool = false // For FocusState
    @Published var systemMoveState: SystemMoveState? = nil
    @Published var continuesManagementState: ContinuesManagementState? = nil

    /// Core Options sheet state
    @Published var showCoreOptionsSheet = false
    @Published var coreOptionsClassName: String?
    @Published var coreOptionsCoreName: String?
    @Published var coreOptionsGameMD5: String?

    /// Transfer Pak / Controller Pak sheet state
    @Published var showTransferPakConfig = false
    @Published var transferPakGame: PVGame?
    @Published var showControllerPakSlots = false
    @Published var controllerPakGame: PVGame?

    /// Network Play sheet state
    @Published var showNetworkPlay = false
    @Published var networkPlayGame: PVGame?
    @Published var networkPlayCoreIdentifier: String = ""

    /// Save Export share sheet state
    @Published var showSaveExportShareSheet = false
    @Published var saveExportURL: URL? = nil

    /// SRAM Export share sheet state
    @Published var showSRAMExportShareSheet = false
    @Published var sramExportURL: URL? = nil

    /// SRAM Import document picker state
    @Published var showSRAMImportPicker = false
    @Published var sramImportGame: PVGame? = nil

    /// Save Import wizard state
    @Published var showSaveImportWizard = false
    @Published var saveImportPreSelectedGame: PVGame?

    // MARK: - Multi-Select State

    /// Whether the library is in multi-select (batch-edit) mode.
    @Published var isMultiSelectMode: Bool = false
    /// MD5 hashes of currently-selected games.
    @Published var selectedGameMD5s: Set<String> = []
    /// Controls presentation of the "Normalize Titles" preview sheet.
    @Published var showNormalizeTitlePreview: Bool = false

    /// Toggle a game in/out of the selection set.
    @MainActor
    func toggleSelection(md5: String) {
        if selectedGameMD5s.contains(md5) {
            selectedGameMD5s.remove(md5)
        } else {
            selectedGameMD5s.insert(md5)
        }
    }

    /// Enter multi-select mode; clears any previous selection.
    @MainActor
    func enterMultiSelectMode() {
        selectedGameMD5s = []
        isMultiSelectMode = true
    }

    /// Exit multi-select mode and clear selection.
    @MainActor
    func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedGameMD5s = []
    }

    // Properties that were @State in the View, now @Published in ViewModel
    @Published var searchText: String = "" {
        didSet {
            // Debounce search updates to reduce filtering overhead
            searchDebounceTimer?.invalidate()
            let searchValue = searchText
            searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.isSearching = !searchValue.isEmpty
                    // Clear cache when search text changes
                    if self?.cachedSearchQuery != searchValue {
                        self?.cachedSearchResults = []
                        self?.cachedSearchQuery = ""
                    }
                }
            }
        }
    }
    @Published var isSearching: Bool = false
    @Published var scrollOffset: CGFloat = 0
    @Published var previousScrollOffset: CGFloat = 0
    @Published var isSearchBarVisible: Bool = true

    // MARK: - Snapshot models for rendering (no Realm objects in SwiftUI lists/grids)
    @Published var allGamesModels: [GameCellModel] = []
    @Published var favoritesModels: [GameCellModel] = []
    @Published var recentlyPlayedModels: [GameCellModel] = []

    @Published var sortAscending: Bool = true {
        didSet {
            Task { @MainActor in
                resortModelsOnMain()
            }
        }
    }

    private let modelsQueue = DispatchQueue(label: "org.provenance.ui.consoleGames.models", qos: .userInitiated)
    private var modelsRealm: Realm?
    private var gamesToken: NotificationToken?
    private var recentToken: NotificationToken?

    private var recentMD5Order: [String] = []
    private var modelsByMD5: [String: GameCellModel] = [:]

    /// Cache for filtered search results
    private var cachedSearchResults: [GameCellModel] = []
    private var cachedSearchQuery: String = ""

    /// Timer for debouncing search
    private var searchDebounceTimer: Timer?

    /// Cached BIOS check to avoid repeated Realm queries
    lazy var hasBioses: Bool = {
        return !console.bioses.isEmpty
    }()

    /// Initialize the view model with a console
    init(console: PVSystem) {
        self.console = console
        self.consoleIdentifier = console.identifier

        self.showingRenameAlert = false
        startModelObservations()
    }

    /// Navigation state helpers
    func updateFocus(section: HomeSectionType?, item: String?) async {
        await MainActor.run {
            self.focusedSection = section
            self.focusedItemInSection = item
        }
    }

    /// Get current focused section
    func getCurrentSection() -> HomeSectionType? {
        return focusedSection
    }

    /// Get current focused item
    func getCurrentItem() -> String? {
        return focusedItemInSection
    }

    /// Present disc selection alert for a game
    func presentDiscSelectionAlert(for game: PVGame, rootDelegate: PVRootDelegate?) async {
        let discs = game.relatedFiles.toArray()
        let alertDiscs = discs.compactMap { disc -> DiscSelectionAlert.Disc? in
            return DiscSelectionAlert.Disc(fileName: disc.fileName, path: disc.url!.path)
        }

        await MainActor.run {
            self.discSelectionAlert = DiscSelectionAlert(
                game: game,
                discs: alertDiscs
            )
            self.showDiscSelectionAlert = true
        }
    }

    /// MARK: - Rename Game Alert
    func prepareRenameAlert(for game: PVGame) async {
        await MainActor.run {
            self.newGameTitle = game.title
            self.gameToRename = game
            self.showingRenameAlert = true
        }
    }

    /// Note: The actual renaming logic will remain in ConsoleGamesView for now,
    /// or be passed via a closure, to keep ViewModel focused on state.
    /// This ViewModel method will primarily handle the state changes post-action.
    func completeRenameAction() async {
        await MainActor.run {
            self.showingRenameAlert = false
            self.gameToRename = nil
            self.newGameTitle = ""
        }
    }

    /// Note: The actual renaming logic will remain in ConsoleGamesView for now,
    /// or be passed via a closure, to keep ViewModel focused on state.
    /// This ViewModel method will primarily handle the state changes post-action.
    func cancelRenameAction() async {
        await MainActor.run {
            self.showingRenameAlert = false
            self.gameToRename = nil
            self.newGameTitle = ""
        }
    }

    // MARK: - Artwork Source Alert
    func prepareArtworkSourceAlert(for game: PVGame) async {
        await MainActor.run {
            self.gameForArtworkUpdate = game
            self.showArtworkSourceAlert = true
        }
    }

    // These functions will primarily handle the state for the alert itself.
    // The actual presentation of the image picker or search sheet will still be managed by bindings in the View,
    // but these ViewModel methods will ensure the alert is dismissed correctly.

    func handleSelectFromPhotos() async {
        await MainActor.run {
            self.showArtworkSourceAlert = false
        }
    }

    func handleSearchOnline() async {
        await MainActor.run {
            self.showArtworkSourceAlert = false
        }
    }

    func cancelArtworkSourceAlert() async {
        await MainActor.run {
            self.showArtworkSourceAlert = false
            self.gameForArtworkUpdate = nil
        }
    }

    // MARK: - Game Info Presentation
    @MainActor
    func showGameInfo(gameId: String) {
        guard let game = console.games.first(where: { $0.md5Hash == gameId }) else {
            ELOG("ConsoleGamesViewModel: Could not find game with ID: \(gameId) in console \(console.name)")
            return
        }
        DLOG("ConsoleGamesViewModel: Preparing to show game info for game: \(game.title)")
        self.selectedGameForInfo = game
        self.showingGameInfo = true
    }

    @MainActor
    func dismissGameInfo() {
        DLOG("ConsoleGamesViewModel: Dismissing game info")
        self.showingGameInfo = false
        self.selectedGameForInfo = nil
    }

    /// Get cached filtered search results
    func getFilteredSearchResults() -> [GameCellModel] {
        guard !searchText.isEmpty else {
            cachedSearchResults = []
            cachedSearchQuery = ""
            return []
        }

        // Return cached results if query hasn't changed
        if cachedSearchQuery == searchText && !cachedSearchResults.isEmpty {
            return cachedSearchResults
        }

        let searchTextLowercased = searchText.lowercased()
        let results = allGamesModels.filter { model in
            model.title.lowercased().contains(searchTextLowercased)
        }

        // Cache results
        cachedSearchResults = results
        cachedSearchQuery = searchText

        return results
    }

    deinit {
        searchDebounceTimer?.invalidate()
        gamesToken?.invalidate()
        recentToken?.invalidate()
    }
}

// MARK: - Snapshot model observation
private extension ConsoleGamesViewModel {
    func startModelObservations() {
        modelsQueue.async { [weak self] in
            guard let self else { return }
            do {
                let realm = try Realm()
                self.modelsRealm = realm

                let games = realm.objects(PVGame.self)
                    .filter("systemIdentifier == %@", self.consoleIdentifier)

                self.gamesToken = games.observe(keyPaths: GameCellModel.observedKeyPaths, on: self.modelsQueue) { [weak self] change in
                    autoreleasepool {
                        guard let self else { return }
                        switch change {
                        case .initial(let collection),
                             .update(let collection, _, _, _):
                            let snapshot = collection.freeze()
                            self.rebuildGameModels(from: snapshot)
                        case .error(let error):
                            ELOG("ConsoleGamesViewModel: error observing PVGame: \(error.localizedDescription)")
                        }
                    }
                }

                let recent = realm.objects(PVRecentGame.self)
                    .filter("game.systemIdentifier == %@", self.consoleIdentifier)
                    .sorted(byKeyPath: "lastPlayedDate", ascending: false)

                self.recentToken = recent.observe(on: self.modelsQueue) { [weak self] change in
                    autoreleasepool {
                        guard let self else { return }
                        switch change {
                        case .initial(let collection),
                             .update(let collection, _, _, _):
                            let snapshot = collection.freeze()
                            self.rebuildRecentOrder(from: snapshot)
                        case .error(let error):
                            ELOG("ConsoleGamesViewModel: error observing PVRecentGame: \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                ELOG("ConsoleGamesViewModel: failed to open Realm for models: \(error.localizedDescription)")
            }
        }
    }

    func rebuildGameModels(from games: Results<PVGame>) {
        autoreleasepool {
        // Build snapshots on the Realm thread.
        var byMD5: [String: GameCellModel] = [:]
        byMD5.reserveCapacity(games.count)

        var all: [GameCellModel] = []
        all.reserveCapacity(games.count)

        for game in games where !game.isInvalidated {
            let model = GameCellModel(game: game)
            byMD5[model.md5] = model
            all.append(model)
        }

        // Derive favorites from snapshots (avoids a second Realm observer).
        let favs = all.filter { $0.isFavorite }

        // Derive recently played from existing order.
        let recents = recentMD5Order.compactMap { byMD5[$0] }

        modelsByMD5 = byMD5

        Task { @MainActor in
            self.allGamesModels = self.sorted(all)
            self.favoritesModels = self.sorted(favs)
            self.recentlyPlayedModels = recents
        }
        }
    }

    func rebuildRecentOrder(from recents: Results<PVRecentGame>) {
        autoreleasepool {
            // Build ordering list on Realm thread.
            recentMD5Order = recents.compactMap { recent in
                guard !recent.isInvalidated, !recent.game.isInvalidated else { return nil }
                return recent.game.md5Hash.uppercased()
            }

            let models = recentMD5Order.compactMap { modelsByMD5[$0] }

            Task { @MainActor in
                self.recentlyPlayedModels = models
            }
        }
    }

    @MainActor
    func resortModelsOnMain() {
        allGamesModels = sorted(allGamesModels)
        favoritesModels = sorted(favoritesModels)
        // recentlyPlayedModels keeps play-order, do not resort.
    }

    func sorted(_ models: [GameCellModel]) -> [GameCellModel] {
        models.sorted { lhs, rhs in
            if sortAscending {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            } else {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedDescending
            }
        }
    }
}
