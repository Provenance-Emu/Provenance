//
//  ConsoleGamesView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright 2022 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import PVUIBase
import PVCoreBridge
import PVRealm
import PVSettings
import Combine
import RealmSwift
import PVWebServer

struct ConsoleGamesFilterModeFlags: OptionSet {
    let rawValue: Int

    static let played = ConsoleGamesFilterModeFlags(rawValue: 1 << 0)
    static let neverPlayed = ConsoleGamesFilterModeFlags(rawValue: 1 << 1)
    static let recentlyImported = ConsoleGamesFilterModeFlags(rawValue: 1 << 2)
    static let recentlyPlayed = ConsoleGamesFilterModeFlags(rawValue: 1 << 3)
}

struct GameSkinSelectionState: Identifiable {
    let id: String
    let game: PVGame

    init(game: PVGame) {
        self.id = game.id
        self.game = game
    }
}

struct ConsoleGamesView: SwiftUI.View {

    @StateObject internal var gamesViewModel: ConsoleGamesViewModel
    @ObservedObject var viewModel: PVRootViewModel
    @ObservedRealmObject var console: PVSystem
    @EnvironmentObject var themeManager: ThemeManager

    // Properties that were @Default in the View, now @Default in ViewModel
    @Default(.gameLibraryScale) var gameLibraryScale: Float
    @Default(.showRecentSaveStates) var showRecentSaveStates: Bool
    @Default(.showFavorites) var showFavorites: Bool
    @Default(.showRecentGames) var showRecentGames: Bool
    @Default(.showSearchbar) var showSearchbar: Bool
    @Default(.unsupportedCores) var unsupportedCores: Bool
    @Default(.iCloudSync) var iCloudSyncEnabled: Bool

    // Modal state for log viewer and system status
    @State private var showLogViewer = false
    @State private var showSystemStatus = false
    @State private var showSystemSkinSelection = false
    @State private var showSkinCatalog = false
    @State private var gameForSkinSelection: GameSkinSelectionState? = nil

    let gamesForSystemPredicate: NSPredicate

    /// Observed only for the recent-save-states badge check in `continueSection()`.
    /// All game/recent/favorites data is served by `gamesViewModel` (background-queue observer)
    /// to avoid hammering the main thread on every CloudKit write.
    @ObservedResults(
        PVSaveState.self,
        filter: NSPredicate(value: true),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) var recentSaveStates

    weak var rootDelegate: PVRootDelegate?
    var showGameInfo: (String) -> Void

    init(
        console: PVSystem,
        viewModel: PVRootViewModel,
        rootDelegate: PVRootDelegate? = nil,
        showGameInfo: @escaping (String) -> Void
    ) {
        self.gamesForSystemPredicate = NSPredicate(format: "systemIdentifier == %@", argumentArray: [console.identifier])
        _gamesViewModel = StateObject(wrappedValue: ConsoleGamesViewModel(console: console))
        self.console = console
        self.viewModel = viewModel
        self.rootDelegate = rootDelegate
        self.showGameInfo = showGameInfo

        // Only observe save-states for the recent-saves badge; everything else is
        // served by ConsoleGamesViewModel which uses a background-queue Realm observer.
        _recentSaveStates = ObservedResults(
            PVSaveState.self,
            filter: NSPredicate(format: "game.systemIdentifier == %@", console.identifier),
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
        )
    }

    @State private var shouldShowImportProgress = false

    var allGamesModels: [GameCellModel] {
        gamesViewModel.allGamesModels
    }

    var favoritesModels: [GameCellModel] {
        gamesViewModel.favoritesModels
    }

    var recentlyPlayedModels: [GameCellModel] {
        gamesViewModel.recentlyPlayedModels
    }

    private var hasRecentSaveStates: Bool {
        !recentSaveStates.isEmpty
    }

    /// Resolve a live `PVGame` for actions / menus (on-demand).
    private func liveGame(for model: GameCellModel) -> PVGame? {
        let realm = RomDatabase.sharedInstance.realm
        let candidates = [model.md5, model.md5.uppercased(), model.md5.lowercased()]
        var seen = Set<String>()
        for key in candidates where seen.insert(key).inserted {
            if let game = realm.object(ofType: PVGame.self, forPrimaryKey: key) {
                return game
            }
        }
        return nil
    }

    /// Creates a stable view identity key that only changes when artwork changes.
    private func gameIdentityKey(id: String, artworkURL: String) -> String {
        "\(id)_\(artworkURL)"
    }

    /// Shares focus binding construction so SwiftUI builders stay lightweight for type-checking.
    private func focusBinding(
        itemId: String,
        section: HomeSectionType,
        requiresValidityCheck: @escaping () -> Bool = { true }
    ) -> Binding<Bool> {
        Binding(
            get: {
                requiresValidityCheck() &&
                gamesViewModel.focusedSection == section &&
                gamesViewModel.focusedItemInSection == itemId
            },
            set: { isFocused in
                guard isFocused, requiresValidityCheck() else { return }
                gamesViewModel.focusedSection = section
                gamesViewModel.focusedItemInSection = itemId
            }
        )
    }

    func launchGame(md5: String) {
        Task.detached { @MainActor in
            let realm = RomDatabase.sharedInstance.realm
            let candidates = [md5, md5.uppercased(), md5.lowercased()]
            var seen = Set<String>()
            guard let game = candidates.compactMap({ key -> PVGame? in
                guard seen.insert(key).inserted else { return nil }
                return realm.object(ofType: PVGame.self, forPrimaryKey: key)
            }).first else { return }
            SceneCoordinator.shared.launchGame(game.freeze())
        }
    }

    @ViewBuilder
    var unsupportedSystemBanner: some View {
        let supportLevel = console.coreSupportLevel(isAppStore: AppState.shared.isAppStore, unsupportedCores: unsupportedCores)
        if supportLevel != .fullySupported {
            HStack(spacing: 8) {
                Image(systemName: supportLevel == .appStoreRestricted ? "lock.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                VStack(alignment: .leading, spacing: 2) {
                    Text(supportLevel.label)
                        .font(.system(size: 13, weight: .semibold))
                    Text(supportLevel.explanation)
                        .font(.system(size: 11))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .foregroundColor(supportLevel == .appStoreRestricted ? .orange : .red)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: RetroPauseChrome.radiusSM)
                    .fill((supportLevel == .appStoreRestricted ? Color.orange : Color.red).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: RetroPauseChrome.radiusSM)
                            .strokeBorder((supportLevel == .appStoreRestricted ? Color.orange : Color.red).opacity(0.4), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
    }

    /// Setup guidance banner for contentless cores (Doom, Wolf3D, Quake).
    /// Only shown when the system has a guide and the user has no imported games yet.
    @ViewBuilder
    var contentlessSetupGuide: some View {
        if allGamesModels.isEmpty || allGamesModels.allSatisfy({ liveGame(for: $0)?.contentless == true }) {
            ContentlessSetupGuideView(systemIdentifier: console.identifier)
        }
    }

    @ViewBuilder
    var importProgressView: some View {
        // Defer ImportProgressView creation to avoid synchronous ViewModel initialization blocking main thread
        if shouldShowImportProgress, let libraryUpdatesController = AppState.shared.libraryUpdatesController {
            ImportProgressView(
                gameImporter: AppState.shared.gameImporter ?? GameImporter.shared,
                updatesController: libraryUpdatesController,
                onTap: {
                    withAnimation {
                        gamesViewModel.showImportStatusView = true
                    }
                }
            )
            .padding(.horizontal, 8)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    var gamesScrollView: some View {
        ScrollViewWithOffset(
            offsetChanged: { offset in
                // Throttle scroll updates to reduce overhead
                let scrollDistance = abs(offset - gamesViewModel.previousScrollOffset)

                // Only process if scroll distance is significant (reduces update frequency)
                guard scrollDistance > 8 else { return }

                // Detect scroll direction
                let scrollingDown = offset < gamesViewModel.previousScrollOffset

                // Hide search bar when scrolling down, show when scrolling up
                if scrollingDown && offset < -10 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gamesViewModel.isSearchBarVisible = false
                    }
                } else if !scrollingDown && scrollDistance > 10 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gamesViewModel.isSearchBarVisible = true
                    }
                }

                gamesViewModel.scrollOffset = offset
                gamesViewModel.previousScrollOffset = offset
            }
        ) {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 0) {
                    // Add search bar with visibility control
                    if allGamesModels.count > 8 && showSearchbar {
                        PVSearchBar(text: $gamesViewModel.searchText)
                            .opacity(gamesViewModel.isSearchBarVisible ? 1 : 0)
                            .frame(height: gamesViewModel.isSearchBarVisible ? nil : 0)
                            .animation(.easeInOut(duration: 0.3), value: gamesViewModel.isSearchBarVisible)
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                    }

                    continueSection()
                        .id("section_continues")
                        .padding(.horizontal, 10)
                    favoritesSection()
                        .id("section_favorites")
                        .padding(.horizontal, 10)
                    recentlyPlayedSection()
                        .id("section_recent")
                        .padding(.horizontal, 10)
                    gamesSection()
                        .id("section_allgames")
                        .padding(.horizontal, 10)
                }
                /// Add padding at bottom to account for BiosesView if needed
                .padding(.bottom, gamesViewModel.hasBioses ? 120 : 44)
                .onChange(of: gamesViewModel.focusedSection) { newSection in
                    if let section = newSection {
                        withAnimation {
                            let sectionId = sectionToId(section)
                            proxy.scrollTo(sectionId, anchor: .top)
                        }
                    }
                }
            }
        }
        .overlay(
            Group {
                if !gamesViewModel.searchText.isEmpty {
                    VStack {
                        searchResultsView()
                    }
                    .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
                }
            }
        )
        .padding(.bottom, 4)
    }

    @ViewBuilder
    var biosesView: some View {
        if gamesViewModel.hasBioses {
            BiosesView(console: console)
                .padding(.horizontal, 8)
                .padding(.bottom, 66) // Account for tab bar height
        } else {
            emptyView
        }
    }

    @ViewBuilder
    var emptyView: some View {
        HStack {
            Text("")
        }
        .padding(.horizontal)
        .padding(.bottom, 44) // Account for tab bar height
    }

    /// Image Picker Sheet modifier
#if !os(tvOS)
    @ViewBuilder
    var imagePickerSheet: some View {
        ImagePicker(sourceType: .photoLibrary) { image in
            if let game = gamesViewModel.gameForArtworkUpdate {
                saveArtwork(image: image, forGame: game)
            }
            gamesViewModel.showImagePicker = false
        }
    }
#endif

    /// Artwork Search View sheet
    @ViewBuilder
    var artworkSearchSheet: some View {
        ArtworkSearchView(
            initialSearch: gamesViewModel.gameForArtworkUpdate?.title ?? "",
            initialSystem: console.enumValue
        ) { selection in
            if let game = gamesViewModel.gameForArtworkUpdate {
                Task {
                    do {
                        // Load image data from URL
                        let (data, _) = try await URLSession.shared.data(from: selection.metadata.url)
                        if let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                saveArtwork(image: uiImage, forGame: game)
                                gamesViewModel.showArtworkSearch = false
                            }
                        }
                    } catch {
                        rootDelegate?.showMessage("Failed to download artwork: \(error.localizedDescription)", title: "Error")
                        DLOG("Failed to download image: \(error)")
                    }
                }
            }
        }
    }

    var body: some SwiftUI.View {
        ZStack {
            // Theme-aware RetroWave background (includes grid overlay)
            RetroTheme.RetroBackgroundView()
                .environmentObject(themeManager)
                .edgesIgnoringSafeArea(.all)

                VStack(spacing: 4) {

                    displayOptionsView()
                        .allowsHitTesting(true)

                    importProgressView

                    unsupportedSystemBanner

                    contentlessSetupGuide

                    cloudSyncBanner

                    gamesScrollView

                    biosesView
                }
                // Normalize-Titles preview sheet
                .sheet(isPresented: $gamesViewModel.showNormalizeTitlePreview) {
                    normalizeTitleSheet
                }
                .sheet(isPresented: $gamesViewModel.showImagePicker) {
#if !os(tvOS)
                    imagePickerSheet
#endif
                }
                .sheet(isPresented: $gamesViewModel.showArtworkSearch) {
                    artworkSearchSheet
                }
                .sheet(isPresented: $gamesViewModel.showingGameInfo, onDismiss: {
                    gamesViewModel.dismissGameInfo()
                }) {
                    NavigationStack {
                        if let game = gamesViewModel.selectedGameForInfo?.warmUp() {
                            if let driver = try? RealmGameLibraryDriver() {
                                let infoVM = PagedGameMoreInfoViewModel(
                                    driver: driver,
                                    initialGameId: game.md5Hash,
                                    playGameCallback: { md5 in
                                        DLOG("Play game requested for MD5: \(md5) from PagedGameMoreInfoView")
                                        Task { @MainActor in
                                            let realm = RomDatabase.sharedInstance.realm
                                            guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
                                                SceneCoordinator.shared.alertState.show(
                                                    title: "Failed to Load Game",
                                                    message: "Game with MD5: \(md5) not found",
                                                    type: .error
                                                )
                                                return
                                            }
                                            SceneCoordinator.shared.launchGame(game.freeze())
                                        }
                                    }
                                )
                                PagedGameMoreInfoView(viewModel: infoVM)
                                    .environmentObject(AppState.shared)
                                    .environmentObject(themeManager)
                            } else {
                                Text(String(localized: "Unable to initialise driver"))
                            }
                        } else {
                            Text(String(localized: "No game selected"))
                        }
                    }
                    #if !os(tvOS)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    #endif
                }
                .sheet(item: $gamesViewModel.systemMoveState) { state in
                    SystemPickerView(
                        game: state.game,
                        isPresented: Binding(
                            get: { state.isPresenting },
                            set: { newValue in
                                if !newValue {
                                    gamesViewModel.systemMoveState = nil
                                }
                            }
                        )
                    )
                }
                // Batch delete confirmation
                .alert("Delete Selected Games?", isPresented: $gamesViewModel.showBatchDeleteConfirmation) {
                    Button("Delete", role: .destructive) { performBatchDelete() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will delete \(gamesViewModel.selectedGameMD5s.count) game\(gamesViewModel.selectedGameMD5s.count == 1 ? "" : "s") and their ROM files. Save states will be kept.")
                }
                // Batch move to system
                .sheet(isPresented: $gamesViewModel.showBatchMoveToSystem) {
                    batchMoveToSystemSheet
                }
                // Batch offload confirmation
                .alert("Offload Selected Games?", isPresented: $gamesViewModel.showBatchOffloadConfirmation) {
                    Button("Offload", role: .destructive) { performBatchOffload() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will remove the ROM files from this device. You can re-download them from Cloud later.")
                }
                // Batch download confirmation
                .alert("Download Selected Games?", isPresented: $gamesViewModel.showBatchDownloadConfirmation) {
                    Button("Download") { performBatchDownload() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("This will queue the selected games for download from Cloud.")
                }
                // Import Status View
                .fullScreenCover(isPresented: Binding<Bool>(
                    get: { gamesViewModel.showImportStatusView },
                    set: { gamesViewModel.showImportStatusView = $0 }
                )) {
                    ImportStatusView(
                        updatesController: AppState.shared.libraryUpdatesController!,
                        gameImporter: AppState.shared.gameImporter ?? GameImporter.shared,
                        delegate: rootDelegate as? ImportStatusDelegate,
                        dismissAction: {
                            withAnimation {
                                gamesViewModel.showImportStatusView = false
                            }
                        }
                    )
                }
                // Log Viewer Modal
                .fullScreenCover(isPresented: $showLogViewer) {
                    RetroLogView(isFullscreen: $showLogViewer)
                }
                // System Status Modal
                .fullScreenCover(
                    isPresented: Binding(
                        get: {
                            #if os(tvOS)
                            false
                            #else
                            showSystemStatus && UIDevice.current.userInterfaceIdiom == .pad
                            #endif
                        },
                        set: { newValue in
                            if !newValue {
                                showSystemStatus = false
                            }
                        }
                    )
                ) {
                    NavigationStack {
                        ScrollView {
                            RetroStatusControlView()
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                        .navigationTitle("System Status")
                        #if !os(tvOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showSystemStatus = false
                                }
                                .foregroundColor(RetroTheme.retroPink)
                            }
                        }
                    }
                }
                .sheet(
                    isPresented: Binding(
                        get: {
                            #if os(tvOS)
                            showSystemStatus
                            #else
                            showSystemStatus && UIDevice.current.userInterfaceIdiom != .pad
                            #endif
                        },
                        set: { newValue in
                            if !newValue {
                                showSystemStatus = false
                            }
                        }
                    )
                ) {
                    NavigationStack {
                        ScrollView {
                            RetroStatusControlView()
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                        }
                        .navigationTitle("System Status")
                        #if !os(tvOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showSystemStatus = false
                                }
                                .foregroundColor(RetroTheme.retroPink)
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                // System Skin Selection Modal
                .sheet(isPresented: $showSystemSkinSelection) {
                    NavigationStack {
                        SystemSkinSelectionView(system: console.enumValue)
                        #if !os(tvOS)
                            .navigationBarTitleDisplayMode(.inline)
                        #endif
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") {
                                        showSystemSkinSelection = false
                                    }
                                    .foregroundColor(RetroTheme.retroPink)
                                }
                            }
                    }
                }
                // Skin Catalog Browser Modal (pre-filtered to this system)
                .sheet(isPresented: $showSkinCatalog) {
                    NavigationStack {
                        SkinCatalogBrowserView(preselectedSystem: console.shortName.lowercased())
                        #if !os(tvOS)
                            .navigationBarTitleDisplayMode(.inline)
                        #endif
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") {
                                        showSkinCatalog = false
                                    }
                                    .foregroundColor(RetroTheme.retroPink)
                                }
                            }
                    }
                }
                // Per-Game Skin Selection Modal
                .sheet(item: $gameForSkinSelection) { state in
                    NavigationStack {
                        SystemSkinSelectionView(system: state.game.system?.enumValue ?? console.enumValue, game: state.game.warmUp())
                        #if !os(tvOS)
                            .navigationBarTitleDisplayMode(.inline)
                        #endif
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") {
                                        gameForSkinSelection = nil
                                    }
                                    .foregroundColor(RetroTheme.retroPink)
                                }
                            }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PVShowGameSkinSelection"))) { notification in
                    if let game = notification.userInfo?["game"] as? PVGame {
                        gameForSkinSelection = GameSkinSelectionState(game: game)
                    }
                }
                .sheet(item: $gamesViewModel.continuesManagementState) { state in
                    let game = state.game.warmUp()
                    let realm = game.realm?.thaw() ?? RomDatabase.sharedInstance.realm.thaw()

                    /// Create the Realm driver
                    if let driver = try? RealmSaveStateDriver(realm: realm) {

                        /// Create view model
                        let viewModel = ContinuesMagementViewModel(
                            driver: driver,
                            gameTitle: game.title,
                            systemTitle: game.system?.name ?? "",
                            numberOfSaves: game.saveStates.count,
                            onLoadSave: { saveID in
                                gamesViewModel.continuesManagementState = nil
                                Task.detached {
                                    Task { @MainActor in
                                        let realm = RomDatabase.sharedInstance.realm
                                        guard let saveState = realm.object(ofType: PVSaveState.self, forPrimaryKey: saveID) else {
                                            SceneCoordinator.shared.alertState.show(
                                                title: "Failed to Load Save State",
                                                message: "Save state with id: \(saveID) not found",
                                                type: .error
                                            )
                                            return
                                        }
                                        SceneCoordinator.shared.launchSaveState(saveState.freeze())
                                    }
                                }
                            })

                        /// Create and configure the view
                        if #available(iOS 16.4, tvOS 16.4, *) {
                            ContinuesManagementView(viewModel: viewModel)
                                .onAppear {
                                    /// Set the game ID filter
                                    driver.gameId = game.id

                                    let game = game.freeze()
                                    Task { @MainActor in
                                        let image: UIImage? = await game.fetchArtworkFromCache()
                                        viewModel.gameUIImage = image
                                    }
                                }
                                .presentationBackground(content: {Color.clear})
                        } else {
                            ContinuesManagementView(viewModel: viewModel)
                                .onAppear {
                                    /// Set the game ID filter
                                    driver.gameId = game.id

                                    let game = game.freeze()
                                    Task { @MainActor in
                                        let image: UIImage? = await game.fetchArtworkFromCache()
                                        viewModel.gameUIImage = image
                                    }
                                }
                        }
                    } else {
                        Text(String(localized: "Error: Could not load save states"))
                    }
                }
                .uiKitAlert(
                    "Rename Game",
                    message: "Enter a new name for \(gamesViewModel.gameToRename?.title ?? "")",
                    isPresented: $gamesViewModel.showingRenameAlert,
                    textValue: newGameTitleBindingForAlert,
                    preferredContentSize: CGSize(width: 300, height: 200),
                    textField: { textField in
                        textField.placeholder = "Game name"
                        textField.clearButtonMode = .whileEditing
                        textField.autocapitalizationType = .words
                    }
                ) {
                    [
                        UIAlertAction(title: "Save", style: .default) { _ in
                            // The submitRename() method in ConsoleGamesView+GameContextMenuDelegate.swift
                            // has already been updated to use gamesViewModel and handle dismissal.
                            submitRename()
                        },
                        UIAlertAction(title: "Cancel", style: .cancel) { _ in
                            Task {
                                await gamesViewModel.cancelRenameAction()
                            }
                        }
                    ]
                }
                .sheet(item: $gamesViewModel.systemMoveState) { state in
                    SystemPickerView(
                        game: state.game,
                        isPresented: Binding(
                            get: { state.isPresenting },
                            set: { newValue in
                                if !newValue {
                                    gamesViewModel.systemMoveState = nil
                                }
                            }
                        )
                    )
                }
                .uiKitAlert(
                    "Choose Artwork Source",
                    message: "Select artwork from your photo library or search online sources",
                    isPresented: $gamesViewModel.showArtworkSourceAlert,
                    buttons: {
                        UIAlertAction(title: "Search Online", style: .default) { _ in
                            Task { @MainActor in
                                // gameForArtworkUpdate is already set in gamesViewModel via prepareArtworkSourceAlert
                                await gamesViewModel.handleSearchOnline()
                                // After alert is dismissed by ViewModel, trigger the sheet
                                gamesViewModel.showArtworkSearch = true
                            }
                        }
                        UIAlertAction(title: "Select from Photos", style: .default) { _ in
                            Task { @MainActor in
                                await gamesViewModel.handleSelectFromPhotos()
                                // After alert is dismissed by ViewModel, trigger the sheet
                                gamesViewModel.showImagePicker = true
                            }
                        }
                        UIAlertAction(title:  NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                            Task { @MainActor in
                                await gamesViewModel.cancelArtworkSourceAlert()
                            }
                        }
                    }
                )
                .uiKitAlert(
                    "Select Disc",
                    message: "Choose which disc to load",
                    isPresented: Binding(
                        get: { gamesViewModel.discSelectionAlert != nil },
                        set: { if !$0 { gamesViewModel.discSelectionAlert = nil } }
                    ),
                    preferredContentSize: CGSize(width: 500, height: 300),
                    buttons: {
                        if let alert = gamesViewModel.discSelectionAlert, let game = alert.game  {
                            let actions = alert.discs.map { (disc: DiscSelectionAlert.Disc) -> UIAlertAction in
                                UIAlertAction(title: disc.fileName, style: .default) { _ in
                                    gamesViewModel.discSelectionAlert = nil
                                    Task { @MainActor in
                                        SceneCoordinator.shared.launchGame(game.freeze(), discPath: disc.path, core: nil, saveState: nil)
                                    }
                                }
                            }

                            actions + [UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                                gamesViewModel.discSelectionAlert = nil
                            }]
                        } else {
                            [UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel"), style: .cancel) { _ in
                                gamesViewModel.discSelectionAlert = nil
                            }]
                        }
                    }
                )
                .sheet(isPresented: $gamesViewModel.showCoreOptionsSheet) {
                    if let className = gamesViewModel.coreOptionsClassName,
                       let coreClass = NSClassFromString(className) as? CoreOptional.Type {
                        NavigationView {
                            CoreOptionsDetailView(
                                coreClass: coreClass,
                                title: gamesViewModel.coreOptionsCoreName ?? "Core Options",
                                gameMD5: gamesViewModel.coreOptionsGameMD5
                            )
                        }
                    }
                }
                .sheet(isPresented: $gamesViewModel.showTransferPakConfig) {
                    if let game = gamesViewModel.transferPakGame, !game.isInvalidated {
                        TransferPakConfigView(game: game, onDismiss: {
                            gamesViewModel.showTransferPakConfig = false
                        })
                    }
                }
                .sheet(isPresented: $gamesViewModel.showControllerPakSlots) {
                    if let game = gamesViewModel.controllerPakGame, !game.isInvalidated {
                        N64ControllerPakView(
                            gameMD5: game.md5Hash,
                            gameTitle: game.title,
                            onDismiss: { gamesViewModel.showControllerPakSlots = false }
                        )
                    }
                }
                #if !os(watchOS)
                .sheet(isPresented: $gamesViewModel.showNetworkPlay) {
                    if let game = gamesViewModel.networkPlayGame, !game.isInvalidated {
                        NetplayLobbyView(
                            gameName: game.title,
                            coreIdentifier: gamesViewModel.networkPlayCoreIdentifier,
                            localGameHash: game.md5Hash
                        )
                    } else {
                        Color.clear.onAppear { gamesViewModel.showNetworkPlay = false }
                    }
                }
                #endif
                #if !os(tvOS)
                .sheet(isPresented: $gamesViewModel.showSaveExportShareSheet, onDismiss: {
                    if let url = gamesViewModel.saveExportURL {
                        SaveExporter.shared.cleanupExport(at: url)
                        gamesViewModel.saveExportURL = nil
                    }
                }) {
                    if let url = gamesViewModel.saveExportURL {
                        ActivityViewController(activityItems: [url])
                    } else {
                        Color.clear.onAppear { gamesViewModel.showSaveExportShareSheet = false }
                    }
                }
                .sheet(isPresented: $gamesViewModel.showSRAMExportShareSheet, onDismiss: {
                    if let url = gamesViewModel.sramExportURL {
                        SaveExporter.shared.cleanupExport(at: url)
                        gamesViewModel.sramExportURL = nil
                    }
                }) {
                    if let url = gamesViewModel.sramExportURL {
                        ActivityViewController(activityItems: [url])
                    } else {
                        Color.clear.onAppear { gamesViewModel.showSRAMExportShareSheet = false }
                    }
                }
                .sheet(isPresented: $gamesViewModel.showSRAMImportPicker, onDismiss: {
                    gamesViewModel.sramImportGame = nil
                }) {
                    if let game = gamesViewModel.sramImportGame {
                        SRAMImportDocumentPicker { urls in
                            gamesViewModel.showSRAMImportPicker = false
                            guard !urls.isEmpty else { return }
                            Task { @MainActor in
                                await handleSRAMImport(urls: urls, for: game)
                            }
                        }
                    } else {
                        Color.clear.onAppear { gamesViewModel.showSRAMImportPicker = false }
                    }
                }
                #endif
                .sheet(isPresented: $gamesViewModel.showSaveImportWizard, onDismiss: {
                    gamesViewModel.saveImportPreSelectedGame = nil
                }) {
                    if let game = gamesViewModel.saveImportPreSelectedGame {
                        SaveImportWizardView(preSelectedGame: game)
                    } else {
                        SaveImportWizardView()
                    }
                }

                .task(priority: .background) {
                    // Defer BIOS rescan significantly to avoid blocking tab switches
                    // Wait 500ms after view appears before scanning
                    try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay
                    let systemPath = Paths.biosesPath.appendingPathComponent(console.identifier)
                    await BIOSWatcher.shared.rescanDirectory(systemPath)
                }
                .task(priority: .utility) {
                    // Quick scan to fix games marked as iCloud-only but have local files
                    // This fixes race conditions between CloudKit sync and local file scanning
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                    await scanAndFixLocalFileStatus(for: console)
                }
                .task(priority: .utility) {
                    // Keep model sorting aligned with the root view sort setting.
                    await MainActor.run {
                        gamesViewModel.sortAscending = viewModel.sortGamesAscending
                    }
                }
                .task(priority: .utility) {
                    // Defer ImportProgressView initialization to avoid blocking initial render
                    // Wait 300ms after view appears before creating ViewModel
                    // ViewModel itself will defer subscription setup by another 100ms
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                    await MainActor.run {
                        self.shouldShowImportProgress = true
                    }
                }
                .onChange(of: viewModel.sortGamesAscending) { newValue in
                    gamesViewModel.sortAscending = newValue
                }

            // Multi-select batch-action toolbar — overlays at the bottom in select mode
            multiSelectToolbar
        }
        .modifier(ConditionalSearchModifier(
            isEnabled: allGamesModels.count > 8,
            searchText: $gamesViewModel.searchText
        ))
        .ignoresSafeArea(.all)
        // ROM drag & drop import — iOS/iPadOS/macCatalyst only (#3406)
#if os(iOS)
        .romDropTarget()
#endif
    }

    private func loadGame(_ game: PVGame) {
        Task.detached { @MainActor in
            SceneCoordinator.shared.launchGame(game.freeze())
        }
    }

    var itemsPerRow: Int {
        let roundedScale = Int(gameLibraryScale.rounded())
        // If games is less than count, just use the games to fill the row.
        // also don't go below 0
        let count: Int
        if AppState.shared.isSimulator {
            count = max(0,roundedScale )
        } else {
            // TODO: Fill space on iOS or certain layouts only, or a max width?
            let fillSpace = false
            if fillSpace {
                count = min(max(1, roundedScale), allGamesModels.count)
            } else {
                count = max(1, roundedScale)
            }
        }
        return count
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: itemsPerRow)
    }

    @ViewBuilder
    private func showGamesGrid(_ games: [PVGame]) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(games.filter { !$0.isInvalidated }, id: \.id) { game in
                GameItemView(
                    game: game,
                    constrainHeight: false,
                    sectionContext: .allGames,
                    isFocused: focusBinding(
                        itemId: game.id,
                        section: .allGames,
                        requiresValidityCheck: { !game.isInvalidated }
                    )
                ) {
                    Task.detached { @MainActor in
                        SceneCoordinator.shared.launchGame(game.freeze())
                    }
                }
                /// Use compound ID so view recreates when artwork URL changes
                .id(gameIdentityKey(id: game.id, artworkURL: game.trueArtworkURL))
                .focusableIfAvailable()
                .contextMenu {
                    GameContextMenu(
                        game: game,
                        rootDelegate: rootDelegate,
                        contextMenuDelegate: self
                    )
                }
#if !os(tvOS) && !os(watchOS)
                .onDrag { game.romDragProvider() }
#endif
            }
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func showGamesGrid(_ games: [GameCellModel]) -> some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(games, id: \.id) { model in
                multiSelectOverlay(md5: model.md5) {
                    GameItemPresentableView(
                        game: model,
                            constrainHeight: false,
                            sectionContext: .allGames,
                            isFocused: focusBinding(itemId: model.id, section: .allGames)
                    ) {
                        gameAction(for: model.md5)()
                    }
                }
                /// Recreate the tile only when the artwork URL changes.
                /// Selection state is handled by `multiSelectOverlay` via SwiftUI observation —
                /// including it in `.id` would force full view recreation on every tap.
                .id(gameIdentityKey(id: model.id, artworkURL: model.trueArtworkURL))
                .focusableIfAvailable()
                .contextMenu {
                    if !gamesViewModel.isMultiSelectMode, let live = liveGame(for: model) {
                        GameContextMenu(
                            game: live,
                            rootDelegate: rootDelegate,
                            contextMenuDelegate: self
                        )
                    }
                }
                #if os(iOS)
                .romDragSource(gameMD5: model.md5)
                #endif
            }
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func showGamesGrid(_ games: Results<PVGame>) -> some View {
        ScrollViewReader { proxy in
            LazyVGrid(columns: columns, spacing: 10) {
                // Use Results<PVGame> directly (lazy) — avoid .toArray() which materialises all games
                ForEach(games, id: \.id) { game in
                    if !game.isInvalidated {
                        GameItemView(
                            game: game,
                            constrainHeight: false,
                            viewType: .cell,
                            sectionContext: .allGames,
                            isFocused: focusBinding(
                                itemId: game.id,
                                section: .allGames,
                                requiresValidityCheck: { !game.isInvalidated }
                            )
                        ) {
                            Task.detached { @MainActor in
                                SceneCoordinator.shared.launchGame(game.freeze())
                            }
                        }
                        /// Use compound ID so view recreates when artwork URL changes
                        .id(gameIdentityKey(id: game.id, artworkURL: game.trueArtworkURL))
                        .focusableIfAvailable()
                        .contextMenu {
                            GameContextMenu(
                                game: game,
                                rootDelegate: rootDelegate,
                                contextMenuDelegate: self
                            )
                        }
#if !os(tvOS) && !os(watchOS)
                        .onDrag { game.romDragProvider() }
#endif
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func showGamesList(_ games: [PVGame]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(games.filter { !$0.isInvalidated }, id: \.id) { game in
                GameItemView(
                    game: game,
                    constrainHeight: true,
                    viewType: .row,
                    sectionContext: .allGames,
                    isFocused: focusBinding(
                        itemId: game.id,
                        section: .allGames,
                        requiresValidityCheck: { !game.isInvalidated }
                    )
                ) {
                    Task.detached { @MainActor in
                        SceneCoordinator.shared.launchGame(game.freeze())
                    }
                }
                /// Use compound ID so view recreates when artwork URL changes
                .id(gameIdentityKey(id: game.id, artworkURL: game.trueArtworkURL))
                .focusableIfAvailable()
                .contextMenu {
                    GameContextMenu(
                        game: game,
                        rootDelegate: rootDelegate,
                        contextMenuDelegate: self
                    )
                }
#if !os(tvOS) && !os(watchOS)
                .onDrag { game.romDragProvider() }
#endif
                GamesDividerView()
            }
        }
    }

    @ViewBuilder
    private func showGamesList(_ games: [GameCellModel]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(games, id: \.id) { model in
                multiSelectOverlay(md5: model.md5) {
                    GameItemPresentableView(
                        game: model,
                            constrainHeight: true,
                            viewType: .row,
                            sectionContext: .allGames,
                            isFocused: focusBinding(itemId: model.id, section: .allGames)
                    ) {
                        gameAction(for: model.md5)()
                    }
                }
                /// Recreate the tile only when the artwork URL changes.
                /// Selection state is handled by `multiSelectOverlay` via SwiftUI observation —
                /// including it in `.id` would force full view recreation on every tap.
                .id(gameIdentityKey(id: model.id, artworkURL: model.trueArtworkURL))
                .focusableIfAvailable()
                .contextMenu {
                    if !gamesViewModel.isMultiSelectMode, let live = liveGame(for: model) {
                        GameContextMenu(
                            game: live,
                            rootDelegate: rootDelegate,
                            contextMenuDelegate: self
                        )
                    }
                }
                #if os(iOS)
                .romDragSource(gameMD5: model.md5)
                #endif
                GamesDividerView()
            }
        }
    }

    @ViewBuilder
    private func showGamesList(_ games: Results<PVGame>) -> some View {
        LazyVStack(spacing: 8) {
            // Use Results<PVGame> directly (lazy) — avoid .toArray() which materialises all games
            ForEach(games, id: \.id) { game in
                if !game.isInvalidated {
                    GameItemView(
                        game: game,
                        constrainHeight: false,
                        viewType: .row,
                        sectionContext: .allGames,
                        isFocused: focusBinding(
                            itemId: game.id,
                            section: .allGames,
                            requiresValidityCheck: { !game.isInvalidated }
                        ))
                    {
                        loadGame(game)
                    }
                    /// Use compound ID so view recreates when artwork URL changes
                    .id(gameIdentityKey(id: game.id, artworkURL: game.trueArtworkURL))
                    .focusableIfAvailable()
                    .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: self) }
#if !os(tvOS) && !os(watchOS)
                    .onDrag { game.romDragProvider() }
#endif
                }
            }
        }
    }

    private func showOptionsMenu(for gameId: String) {
        let realm = try! Realm()
        // Implement context menu showing logic here
        // This would show the same menu as the long-press context menu
        if let game = realm.objects(PVGame.self).filter("id == %@", gameId).first {
            GameContextMenu(
                game: game,
                rootDelegate: rootDelegate,
                contextMenuDelegate: self
            )
        }
    }

    @ViewBuilder
    private func makeGameMoreInfoView(for game: PVGame) -> some View {
        do {
            let driver = try RealmGameLibraryDriver()
            let viewModel = PagedGameMoreInfoViewModel(
                driver: driver,
                initialGameId: game.md5Hash,
                playGameCallback: { md5 in
                    Task { @MainActor in
                        let realm = RomDatabase.sharedInstance.realm
                        guard let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5.uppercased()) else {
                            SceneCoordinator.shared.alertState.show(
                                title: "Failed to Load Game",
                                message: "Game with MD5: \(md5) not found",
                                type: .error
                            )
                            return
                        }
                        SceneCoordinator.shared.launchGame(game.freeze())
                    }
                }
            )
            return AnyView(PagedGameMoreInfoView(viewModel: viewModel))
        } catch {
            return AnyView(Text("Failed to initialize game info view: \(error.localizedDescription)"))
        }
    }

    private func renameGame(_ game: PVGame, to newName: String) async {
        guard !newName.isEmpty else { return }

        // Get a reference to the Realm
        let realm = try? await Realm()

        // Update the game title
        try? realm?.write {
            game.thaw()?.title = newName
        }

        // Reset state
        //gameToRename = nil
        //newGameTitle = ""
        //showingRenameAlert = false
    }

    // Create a computed binding that wraps the String as String?
    //private var newGameTitleBinding: Binding<String?> {
    //    Binding<String?>(
    //        get: { self.newGameTitle },
    //        set: { self.newGameTitle = $0 ?? "" }
    //    )
    //}

    /// Optimized search results using ViewModel cache
    private func filteredSearchResults() -> [GameCellModel] {
        let query = gamesViewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let lowered = query.lowercased()
        return allGamesModels.filter { $0.title.lowercased().contains(lowered) }
    }

    @ViewBuilder
    private func searchResultsView() -> some View {
        VStack(alignment: .leading) {
            Text(String(localized: "Search Results"))
                .font(.title2)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .padding(.horizontal)

            LazyVStack(spacing: 0) {
                let results = filteredSearchResults()
                if results.isEmpty {
                    Text(String(localized: "NO GAMES FOUND"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(RetroTheme.retroBlue)
                        .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 3, x: 0, y: 0)
                        .padding()
                } else {
                    ForEach(results, id: \.id) { game in
                        GameItemPresentableView(
                            game: game,
                            constrainHeight: true,
                            viewType: .row,
                            sectionContext: .allGames,
                            isFocused: focusBinding(itemId: game.id, section: .allGames)
                        ) {
                            launchGame(md5: game.md5)
                        }
                        .id(gameIdentityKey(id: game.id, artworkURL: game.trueArtworkURL))
                        .focusableIfAvailable()
                        .contextMenu {
                            if let live = liveGame(for: game) {
                                GameContextMenu(
                                    game: live,
                                    rootDelegate: rootDelegate,
                                    contextMenuDelegate: self
                                )
                            }
                        }
                        #if os(iOS)
                        .romDragSource(gameMD5: game.md5)
                        #endif
                        GamesDividerView()
                    }
                }
            }
        }
    }

    private var newGameTitleBindingForAlert: Binding<String?> {
        Binding<String?>(
            get: { gamesViewModel.newGameTitle },
            set: { gamesViewModel.newGameTitle = $0 ?? "" }
        )
    }

    /// Scans local ROM files for this system and updates games marked as iCloud-only
    /// that actually have local files present. Fixes race condition between CloudKit
    /// sync and local file scanning.
    private func scanAndFixLocalFileStatus(for system: PVSystem) async {
        let systemIdentifier = system.identifier
        let systemRomsPath = Paths.romsPath(forSystemIdentifier: systemIdentifier)

        // Step 1: Collect game info on main thread (fast Realm query)
        let gameInfoList: [(md5: String, filenames: [String], title: String)] = await MainActor.run {
            guard FileManager.default.fileExists(atPath: systemRomsPath.path) else {
                DLOG("[LOCAL FILE FIX] No ROMs directory for system: \(systemIdentifier)")
                return []
            }

            let realm = RomDatabase.sharedInstance.realm
            let gamesNeedingCheck = realm.objects(PVGame.self)
                .filter("systemIdentifier == %@ AND isDownloaded == false", systemIdentifier)

            guard !gamesNeedingCheck.isEmpty else {
                DLOG("[LOCAL FILE FIX] No games need local file check for system: \(systemIdentifier)")
                return []
            }

            ILOG("[LOCAL FILE FIX] Checking \(gamesNeedingCheck.count) games for local files in system: \(systemIdentifier)")

            return gamesNeedingCheck.map { game in
                let filenames: [String] = [
                    game.file?.fileName,
                    game.romPath.isEmpty ? nil : URL(fileURLWithPath: game.romPath).lastPathComponent
                ].compactMap { $0 }.filter { !$0.isEmpty }
                return (md5: game.md5Hash, filenames: filenames, title: game.title)
            }
        }

        guard !gameInfoList.isEmpty else { return }

        // Step 2: Do file system scanning on background thread (no Realm access)
        let gamesToFix: [(md5: String, filename: String, path: URL, title: String)] = await Task.detached(priority: .utility) {
            let fileManager = FileManager.default

            // Build map of local files (fast)
            var localFiles: [String: URL] = [:]
            if let enumerator = fileManager.enumerator(at: systemRomsPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue {
                        localFiles[fileURL.lastPathComponent.lowercased()] = fileURL
                    }
                }
            }

            guard !localFiles.isEmpty else {
                return []
            }

            DLOG("[LOCAL FILE FIX] Found \(localFiles.count) local files to check against")

            // Match games to local files
            var results: [(md5: String, filename: String, path: URL, title: String)] = []
            for game in gameInfoList {
                for filename in game.filenames {
                    if let foundPath = localFiles[filename.lowercased()] {
                        results.append((md5: game.md5, filename: filename, path: foundPath, title: game.title))
                        break
                    }
                }
            }
            return results
        }.value

        guard !gamesToFix.isEmpty else {
            DLOG("[LOCAL FILE FIX] No local files found for games marked as iCloud-only")
            return
        }

        // Step 3: Batch update Realm on main thread
        let fixedCount = await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            var count = 0

            do {
                try realm.write {
                    for gameInfo in gamesToFix {
                        guard let liveGame = realm.object(ofType: PVGame.self, forPrimaryKey: gameInfo.md5) else { continue }

                        if liveGame.file == nil {
                            let pvFile = PVFile(withURL: gameInfo.path)
                            liveGame.file = pvFile
                        } else if let existingFile = liveGame.file {
                            let relativePath = "\(systemIdentifier)/\(gameInfo.filename)"
                            if existingFile.partialPath != relativePath {
                                existingFile.partialPath = relativePath
                            }
                        }
                        liveGame.isDownloaded = true
                        count += 1
                        DLOG("[LOCAL FILE FIX] Updated: \(gameInfo.title)")
                    }
                }
            } catch {
                ELOG("[LOCAL FILE FIX] Failed to batch update games: \(error.localizedDescription)")
            }
            return count
        }

        if fixedCount > 0 {
            ILOG("[LOCAL FILE FIX] Fixed \(fixedCount) games for system \(systemIdentifier) that had local files but were marked as iCloud-only")
        }
    }
}

// MARK: - View Components
extension ConsoleGamesView {

    @ViewBuilder
    private func displayOptionsView() -> some View {
        GamesDisplayOptionsView(
            viewModel: viewModel,
            showImportStatusView: Binding(
                get: { gamesViewModel.showImportStatusView },
                set: { gamesViewModel.showImportStatusView = $0 }
            ),
            importStatusAction: {
                withAnimation {
                    gamesViewModel.showImportStatusView = true
                }
            },
            logViewerAction: {
                showLogViewer = true
            },
            systemStatusAction: {
                showSystemStatus = true
            },
            settingsAction: {
                // TODO: This is a hack, we should use the delegate
                // Use NotificationCenter to trigger settings
                NotificationCenter.default.post(name: NSNotification.Name("PVShowSettings"), object: nil)
            },
            skinSelectionAction: {
                showSystemSkinSelection = true
            },
            skinCatalogAction: {
                showSkinCatalog = true
            },
            settingsContext: .console(console),
            toggleFilterAction: { self.rootDelegate?.showUnderConstructionAlert() },
            toggleSortAction: { viewModel.sortGamesAscending.toggle() },
            toggleViewTypeAction: { viewModel.viewGamesAsGrid.toggle() }
        )
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .retroPausePanelBackground(isDark: themeManager.currentPalette.dark)
        .clipShape(RoundedRectangle(cornerRadius: RetroPauseChrome.panelCornerRadius))
        .padding(.horizontal, 8)
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private func continueSection() -> some View {
        Group {
            if showRecentSaveStates && hasRecentSaveStates {
                HomeContinueSection(
                    rootDelegate: rootDelegate,
                    consoleIdentifier: console.identifier,
                    parentFocusedSection: $gamesViewModel.focusedSection,
                    parentFocusedItem: $gamesViewModel.focusedItemInSection
                )
                HomeDividerView()
            }
        }
    }

    @ViewBuilder
    private func favoritesSection() -> some View {
        Group {
            if showFavorites && !favoritesModels.isEmpty {
                /// Intrinsic height (title + row) — do not cap with a fixed frame; shelf cells use `PVRowHeight * PVCompactShelfRowHeightScale`
                /// for favorites/recently played; a shorter container clips artwork in the horizontal `ScrollView`.
                HomeSection(title: String(localized: "Favorites")) {
                    ForEach(favoritesModels, id: \.id) { game in
                        gameItem(game, section: .favorites)
                    }
                }
                HomeDividerView()
            }
        }
    }

    @ViewBuilder
    private func recentlyPlayedSection() -> some View {
        Group {
            if showRecentGames && !recentlyPlayedModels.isEmpty {
                HomeSection(title: "Recently Played") {
                    ForEach(recentlyPlayedModels, id: \.id) { game in
                        gameItem(game, section: .recentlyPlayedGames)
                    }
                }
                HomeDividerView()
            }
        }
    }

    @ViewBuilder
    private func gamesSection() -> some View {
        Group {
            if allGamesModels.isEmpty {
                if AppState.shared.isSimulator {
                    let fakeGames = PVGame.mockGenerate(systemID: console.identifier)
                    if viewModel.viewGamesAsGrid {
                        showGamesGrid(fakeGames)
                    } else {
                        showGamesList(fakeGames)
                    }
                } else if AppState.shared.bootupStateManager.isBootupCompleted,
                          // Fast synchronous Realm count to avoid briefly flashing the
                          // empty-state while async view model observations spin up.
                          (try? Realm())?.objects(PVGame.self)
                              .filter("systemIdentifier == %@", console.identifier).count == 0 {
                    cloudSyncUpsell()
                        .padding(.vertical, 12)
                } else {
                    // Library still loading — show nothing to avoid a brief empty-state flash
                    Color.clear
                }
            } else {
                VStack(alignment: .leading) {

                    titleBar()

                    if viewModel.viewGamesAsGrid {
                        showGamesGrid(allGamesModels)
                    } else {
                        showGamesList(allGamesModels)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func titleBar() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(console.name)
                    .font(.headline)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .shadow(color: .retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
                HStack {
                    Text(console.manufacturer)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                        .shadow(color: Color.retroPink.opacity(0.5), radius: 1, x: 1, y: 1)

                    if console.releaseYear > 1970 {
                        Text("•")
                        Text(String(console.releaseYear))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                            .shadow(color: Color.retroPink.opacity(0.5), radius: 1, x: 1, y: 1)
                    }
                }
            }

            Spacer()

            // Use the already-computed snapshot count to avoid a live Realm
            // relationship traversal on every body evaluation.
            Text("\(allGamesModels.count)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                .shadow(color: .retroCyan.opacity(0.5), radius: 3)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    RetroPauseInsetPillBackground(isDark: themeManager.currentPalette.dark)
                }

#if !os(tvOS)
            multiSelectToggleButton
#endif
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .retroPausePanelBackground(isDark: themeManager.currentPalette.dark)
        .clipShape(RoundedRectangle(cornerRadius: RetroPauseChrome.panelCornerRadius))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func gameItem(_ game: GameCellModel, section: HomeSectionType) -> some View {
        GameItemPresentableView(
            game: game,
                constrainHeight: true,
                shelfRowHeightScale: PVCompactShelfRowHeightScale,
                viewType: .cell,
                sectionContext: section,
                isFocused: focusBinding(itemId: game.id, section: section)
        ) {
            launchGame(md5: game.md5)
        }
        .id(gameIdentityKey(id: game.id, artworkURL: game.trueArtworkURL))
        .focusableIfAvailable()
        .contextMenu {
            if let live = liveGame(for: game) {
                GameContextMenu(
                    game: live,
                    rootDelegate: rootDelegate,
                    contextMenuDelegate: self
                )
            }
        }
        #if os(iOS)
        .saveStateDropTarget(gameId: game.md5)
        #endif
#if !os(tvOS) && !os(watchOS)
        .onDrag { romDragProvider(for: game) }
#endif
    }

    // MARK: - Drag Export

#if !os(tvOS) && !os(watchOS)
    /// Resolves the live Realm game from a `GameCellModel` then delegates to the shared helper.
    private func romDragProvider(for model: GameCellModel) -> NSItemProvider {
        guard let live = liveGame(for: model) else { return NSItemProvider() }
        return live.romDragProvider()
    }
#endif

    @ViewBuilder
    private func saveStateItem(_ saveState: PVSaveState) -> some View {
        if !saveState.isInvalidated && !saveState.game.isInvalidated {
            GameItemView(
                game: saveState.game,
                constrainHeight: true,
                viewType: .cell,
                sectionContext: .recentSaveStates,
                isFocused: Binding(
                    get: {
                        !saveState.isInvalidated &&
                        gamesViewModel.focusedSection == .recentSaveStates &&
                        gamesViewModel.focusedItemInSection == saveState.id
                    },
                    set: {
                        if $0 && !saveState.isInvalidated {
                            gamesViewModel.focusedSection = .recentSaveStates
                            gamesViewModel.focusedItemInSection = saveState.id
                        }
                    }
                )
            ) {
                Task.detached { @MainActor in
                    guard !saveState.isInvalidated, !saveState.game.isInvalidated else { return }
                    SceneCoordinator.shared.launchSaveState(saveState.freeze(), core: saveState.core?.freeze())
                }
            }
            .id(saveState.id)
            .focusableIfAvailable()
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct ConsoleGamesView_Previews: PreviewProvider {
    static let console: PVSystem = ._rlmDefaultValue()
    static let viewModel: PVRootViewModel = .init()

    static var previews: some SwiftUI.View {
        ConsoleGamesView(console: console,
                         viewModel: viewModel,
                         rootDelegate: nil,
                         showGameInfo: {_ in})
    }
}

private struct ConditionalSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var searchText: String

    func body(content: Content) -> some View {
        if isEnabled {
#if !os(tvOS)
            content
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search games")
#else
            content
                .searchable(text: $searchText, placement: .automatic, prompt: "Search games")
#endif
        } else {
            content
                .searchable(text: .constant(""), prompt: "")
        }
    }
}

extension ConsoleGamesView {
    @ViewBuilder
    private func cloudSyncUpsell() -> some View {
        CloudSyncUpsellView(
            hasCachedCloudData: CloudSyncUpsellView.detectCachedCloudData(),
            onOpenSettings: {
                SettingsNavigator.shared.navigate(to: .cloudSync)
                NotificationCenter.default.post(name: NSNotification.Name("PVShowSettings"), object: nil)
            },
            onUpgrade: {
                SettingsNavigator.shared.navigate(to: .cloudSync)
                NotificationCenter.default.post(name: NSNotification.Name("PVShowSettings"), object: nil)
            }
        )
    }

    /// Compact banner shown above the game list when cloud sync is off but cloud data exists.
    /// Only visible for Plus/sideloaded users who could enable sync.
    @ViewBuilder
    private var cloudSyncBanner: some View {
        if !iCloudSyncEnabled && CloudSyncUpsellView.detectCachedCloudData() {
            cloudSyncUpsell()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }
}
#endif
