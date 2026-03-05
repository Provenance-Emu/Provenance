//
//  RetroGameLibraryView.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVLibrary
import PVThemes
import RealmSwift
import Combine
import PVSystems
import PVPrimitives

#if canImport(PVWebServer)
import PVWebServer
#endif

// Import for StatusMessageView
import PVUIBase
#if canImport(SafariServices)
import SafariServices
#endif

// ViewModel is defined in RetroGameLibraryViewModel.swift

/// Helper class to implement ImportStatusDelegate for RetroGameLibraryView
public final class ImportStatusDelegateHelper: ImportStatusDelegate {
    public var showDocumentPicker: () -> Void
    public var dismissImportStatusView: () -> Void
    public var gameImporter: any GameImporting

    public init(showDocumentPicker: @escaping () -> Void, dismissImportStatusView: @escaping () -> Void, gameImporter: any GameImporting) {
        self.showDocumentPicker = showDocumentPicker
        self.dismissImportStatusView = dismissImportStatusView
        self.gameImporter = gameImporter
    }

    @MainActor
    public func dismissAction() {
        dismissImportStatusView()
    }

    @MainActor
    public func addImportsAction() {
        // First dismiss the import status view
        dismissImportStatusView()

        // Then show the import options
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showDocumentPicker()
        }
    }

    @MainActor
    public func forceImportsAction() {
        // Force the game importer to start processing
        gameImporter.startProcessing()
    }

    @MainActor
    public func didSelectSystem(_ system: SystemIdentifier, for item: ImportQueueItem) {
        // For now, we'll just log this action since updateSystem is not available
        // We would need to implement this in the GameImporting protocol
        ILOG("Selected system \(system.rawValue) for import item \(item.id)")
    }
}

public struct RetroGameLibraryView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var sceneCoordinator: SceneCoordinator
    @StateObject private var saveStatesStore = RetroSaveStatesStore.shared

    // State for document picker presentation
    #if !os(tvOS)
    @State private var isShowingDocumentPicker = false
    #endif

    // State for import options alert
    @State private var showingImportOptionsAlert = false

    // Helper for ImportStatusDelegate
    @State private var importStatusDelegate: ImportStatusDelegateHelper?

    // MARK: - ViewModel
    @StateObject private var viewModel = RetroGameLibraryViewModel()

    // Web server state
    @State private var isWebServerRunning = false
    @State private var webServerURL: String?
    @State private var webDavURL: String?

    // Notification observer for web server status changes
    @State private var webServerStatusObserver: NSObjectProtocol?

    /// Cached games and systems - fetched once and refreshed manually
    /// Using @State instead of @ObservedResults to prevent constant re-renders from CloudKit sync
    @State private var cachedGames: [PVGame] = []
    @State private var cachedSystems: [PVSystem] = []
    @State private var gamesCount: Int = 0
    @State private var needsDataRefresh: Bool = true
    @State private var saveBrowserContext: SaveBrowserContext?

    // Track expanded sections with AppStorage to persist between app runs
    @AppStorage("GameLibraryExpandedSections") private var expandedSectionsData: Data = Data()

    // Focus state for rename field
    @FocusState internal var renameTitleFieldIsFocused: Bool

    #if os(tvOS)
    /// Centralized focus state for tvOS to reduce per-cell focus binding overhead
    @FocusState private var focusedGameID: String?
    #endif

    public init() {}

    /// Initialize the import status delegate helper
    private func setupImportStatusDelegate() {
        if importStatusDelegate == nil {
            self.importStatusDelegate = ImportStatusDelegateHelper(
                showDocumentPicker: { self.showImportOptions() },
                dismissImportStatusView: { viewModel.showImportStatusView = false },
                gameImporter: viewModel.gameImporter
            )
        }
    }

    // Create a computed binding that wraps the String as String?
    private var newGameTitleBinding: Binding<String?> {
        Binding<String?>(
            get: { self.viewModel.newGameTitle },
            set: { self.viewModel.newGameTitle = $0 ?? "" }
        )
    }

    public var body: some View {
        // Main content
        mainContentView()
            .background(retroBackgroundView())
            .navigationTitle("GAME LIBRARY")
#if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline) // Changed to inline to avoid overlap
#endif
            .toolbarColorScheme(.dark, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                // Add a spacer with height that matches status bar
                Color.clear.frame(height: 0)
            }
#if !os(tvOS)
            .toolbar {
                // Add button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        /// Show the document picker directly using local state
                        /// This simplifies the implementation and avoids environment object issues
                        isShowingDocumentPicker = true
                    }) {
                        Image(systemName: "plus")
                    }
                }

                // Notifications toggle button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showStatusMessages.toggle()
                    }) {
                        Image(systemName: viewModel.showStatusMessages ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(viewModel.showStatusMessages ? RetroTheme.retroPink : .gray)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.showStatusMessages)
                    }
                }
            }
        /// Use a sheet modifier with local state for document picker
            .sheet(isPresented: $isShowingDocumentPicker) {
                /// When the sheet is dismissed, log for debugging
                VLOG("RetroGameLibraryView: Document picker sheet dismissed")
            } content: {
                /// Present the DocumentPicker directly with the importFiles callback
                DocumentPicker(onImport: importFiles)
            }
#endif
            .retroAlert("Import Result",
                        message: viewModel.importMessage ?? "",
                        isPresented: $viewModel.showingImportMessage) {
                Button("OK", role: .cancel) {
                    viewModel.showingImportMessage = false
                }
            }
            .retroAlert("Select Import Source",
                       message: "Choose how you want to import files",
                       isPresented: $showingImportOptionsAlert) {
                VStack(spacing: 10) {
                    #if !os(tvOS)
                    RetroButton(title: "Files", isPrimary: true) {
                        showingImportOptionsAlert = false
                        // Use a slight delay to avoid SwiftUI sheet presentation issues
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isShowingDocumentPicker = true
                        }
                    }
                    #endif

                    #if canImport(PVWebServer)
                    RetroButton(title: "Web Server", isPrimary: true) {
                        showingImportOptionsAlert = false
                        // Use a slight delay to avoid SwiftUI sheet presentation issues
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            startWebServer()
                        }
                    }
                    #endif

                    RetroButton(title: "Cancel", isPrimary: false) {
                        showingImportOptionsAlert = false
                    }
                }
            }
        .onAppear {
            /// Fetch games and systems once on appear (not using @ObservedResults to avoid constant re-renders)
            if needsDataRefresh {
                refreshGameData()
            }

            // Load expanded sections from AppStorage
            viewModel.loadExpandedSections(from: expandedSectionsData, allSystems: cachedSystems)

            // Set up web server status monitoring (one-time check)
            updateWebServerStatus()

            // Quick scan to fix games marked as iCloud-only but have local files
            Task(priority: .utility) {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms delay to let UI settle
                await scanAndFixAllLocalFileStatus()
            }

            // Listen for web server status changes via notification instead of polling
            webServerStatusObserver = NotificationCenter.default.addObserver(
                forName: .webServerStatusChanged,
                object: nil,
                queue: .main
            ) { [weak viewModel] _ in
                updateWebServerStatus()
            }
        }
        .onDisappear {
            // Remove notification observer when view disappears
            if let observer = webServerStatusObserver {
                NotificationCenter.default.removeObserver(observer)
                webServerStatusObserver = nil
            }
        }
        .onChange(of: viewModel.expandedSections) { _ in
            /// Persist expanded sections to AppStorage when they change
            expandedSectionsData = viewModel.getExpandedSectionsData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .GameImporterDidFinish)) { _ in
            /// Refresh data when games import finishes
            refreshGameData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .PVGameImported)) { _ in
            /// Refresh data when a single game is imported
            refreshGameData()
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
#if !os(tvOS)
            ImagePicker(sourceType: .photoLibrary) { image in
                if let game = viewModel.gameToUpdateCover {
                    viewModel.saveArtwork(image: image, forGame: game)
                }
                viewModel.showImagePicker = false
                viewModel.gameToUpdateCover = nil
            }
#endif
        }
        .fullScreenCover(isPresented: $viewModel.showArtworkSearch) {
            ArtworkSearchView(
                initialSearch: viewModel.gameToUpdateCover?.title ?? "",
                initialSystem: viewModel.gameToUpdateCover?.system?.enumValue ?? SystemIdentifier.Unknown
            ) { selection in
                if let game = viewModel.gameToUpdateCover {
                    Task {
                        do {
                            // Load image data from URL
                            let (data, _) = try await URLSession.shared.data(from: selection.metadata.url)
                            if let uiImage = UIImage(data: data) {
                                await MainActor.run {
                                    viewModel.saveArtwork(image: uiImage, forGame: game)
                                    viewModel.showArtworkSearch = false
                                    viewModel.gameToUpdateCover = nil
                                }
                            }
                        } catch {
                            DLOG("Failed to load artwork image: \(error)")
                        }
                    }
                }
            }
        }
        .retroAlert(
            "Rename Game",
            message: "Enter a new name for \(viewModel.gameToRename?.title ?? "")",
            isPresented: $viewModel.showingRenameAlert,
            textFieldBinding: newGameTitleBinding,
            textFieldConfiguration: { textField in
                textField.placeholder = "Game name"
                textField.clearButtonMode = .whileEditing
                textField.autocapitalizationType = .words
            }
        ) {
            VStack(spacing: 10) {
                RetroButton(title: "Save", isPrimary: true) {
                    if let game = viewModel.gameToRename, !viewModel.newGameTitle.isEmpty {
                        Task {
                            await viewModel.renameGame(game, to: viewModel.newGameTitle)
                            viewModel.gameToRename = nil
                            viewModel.newGameTitle = ""
                            viewModel.showingRenameAlert = false
                        }
                    }
                }

                RetroButton(title: "Cancel", isPrimary: false) {
                    viewModel.gameToRename = nil
                    viewModel.newGameTitle = ""
                    viewModel.showingRenameAlert = false
                }
            }
        }
        .sheet(item: $viewModel.systemMoveState) { state in
            SystemPickerView(
                game: state.game,
                isPresented: Binding(
                    get: { state.isPresenting },
                    set: { newValue in
                        if !newValue {
                            viewModel.systemMoveState = nil
                        }
                    }
                )
            )
        }
        .sheet(item: $saveBrowserContext) { context in
            RetroSaveStatesBrowserView(
                systemID: context.systemID,
                systemName: context.systemName,
                gameFilter: context.game
            )
            .environmentObject(themeManager)
        }
//            .fullScreenCover(item: $viewModel.continuesManagementState) { state in
//                let driver = RealmSaveStateDriver()
//                // Load save states for the specific game
//                driver.loadSaveStates(forGameId: state.game.id)
//
//                /// Create view model with mock driver
//                let viewModel = ContinuesMagementViewModel(
//                    driver: driver,
//                    gameTitle: driver.gameTitle,
//                    systemTitle: driver.systemTitle,
//                    numberOfSaves: driver.getAllSaveStates().count,
//                    gameUIImage: driver.gameUIImage,
//                    onLoadSave: { id in
//                        ILOG("load save \(id)")
//                    }
//                )
//
//                ContinuesManagementView(viewModel: viewModel)
//            }
        .retroAlert(
            "Choose Artwork Source",
            message: "Select artwork from your photo library or search online sources",
            isPresented: $viewModel.showArtworkSourceAlert
        ) {
            VStack(spacing: 10) {
                RetroButton(title: "Select from Photos", isPrimary: true) {
                    viewModel.showArtworkSourceAlert = false
                    viewModel.showImagePicker = true
                }

                RetroButton(title: "Search Online", isPrimary: true) {
                    let game = viewModel.gameToUpdateCover  // Preserve the game reference
                    viewModel.showArtworkSourceAlert = false
                    viewModel.gameToUpdateCover = game
                    viewModel.showArtworkSearch = true
                }

                RetroButton(title: NSLocalizedString("Cancel", comment: "Cancel"), isPrimary: false) {
                    viewModel.showArtworkSourceAlert = false
                }
            }
        }
    }

    /// Main content view that displays either the empty state or the game library
    @ViewBuilder
    private func mainContentView() -> some View {
        ZStack {
            // Background that respects safe areas
            RetroTheme.retroBackground

            if cachedGames.isEmpty {
                emptyLibraryView()
            } else {
                libraryContentView()
            }

            // Status message overlay at the top of the screen
            VStack {
                if viewModel.showStatusMessages {
                    StatusMessageView()
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                Spacer()
            }
        }
    }

    /// Background view with retro aesthetics
    @ViewBuilder
    private func retroBackgroundView() -> some View {
        ZStack {
            /// Base dark background with proper safe area handling
            RetroTheme.retroBlack.ignoresSafeArea(edges: [.horizontal, .bottom])

            /// Use single Shape for grid lines instead of 40 individual Rectangle views
            RetroGridShape(spacing: 20)
                .stroke(Color.retroBlue.opacity(0.2), lineWidth: 1)

            /// Sunset gradient at bottom
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.retroSunsetGradient)
                    .frame(height: 150)
                    .offset(y: 70)
                    .blur(radius: 20)
            }
        }
    }

    /// Content view for the library when games are present
    @ViewBuilder
    private func libraryContentView() -> some View {
        VStack(spacing: 0) {
            // Custom search bar with increased top padding for status bar
            searchBar
                .padding(.horizontal)
                .padding(.top, 16)

            // View mode and filter controls
            libraryControlsView()

            Divider()
                .padding(.horizontal)

                                    // Import progress view - now using the improved ImportProgressView
            importProgressView()
                .padding(.horizontal)
                .padding(.vertical, 8)

            // Games organized by system
            libraryScrollView()
        }
    }

    /// Controls for sorting and view mode
    @ViewBuilder
    private func libraryControlsView() -> some View {
        HStack(spacing: 12) {
            Text("\(filteredGames.count) Games")
                .font(.subheadline)
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.7))

            Spacer()
            #if !os(tvOS)
            // Import button
            Button(action: {
                showImportOptions()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.square")
                        .font(.system(size: 14, weight: .bold))
                    Text("IMPORT")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.retroBlack.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.retroPink, lineWidth: 1.5)
                        )
                )
                .foregroundColor(.retroPink)
                .shadow(color: Color.retroPink.opacity(0.5), radius: 3, x: 0, y: 0)
            }
            .buttonStyle(PlainButtonStyle())
            #endif
            // Sort button
            if #available(tvOS 17.0, *) {
                Menu {
                    ForEach(SortOptions.allCases, id: \.self) { option in
                        Button(action: {
                            viewModel.selectedSortOption = option
                        }) {
                            HStack {
                                Text(option.description)
                                if viewModel.selectedSortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                }
            } else {
                // Fallback on earlier versions
            }

            // View mode toggle
            if #available(tvOS 17.0, *) {
                Menu {
                    ForEach(ViewMode.allCases) { mode in
                        Button(action: {
                            withAnimation {
                                viewModel.selectedViewMode = mode
                            }
                        }) {
                            HStack {
                                Text(mode.rawValue.capitalized)
                                if viewModel.selectedViewMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: viewModel.selectedViewMode.iconName)
                        .foregroundColor(themeManager.currentPalette.defaultTintColor.swiftUIColor)
                }
            } else {
                // Fallback on earlier versions
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Main scroll view containing all game sections
    @ViewBuilder
    private func libraryScrollView() -> some View {
        ScrollView {
            // Use this ID to prevent unnecessary redraws when only search text changes
            // Only include the database update ID to stabilize during database changes
            // Don't include the import queue update ID to avoid redrawing the entire library
            let viewID = "library-\(viewModel.debouncedSearchText.isEmpty ? "all" : "search")"

            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                // Content is identified by the search state to prevent flickering
                if viewModel.debouncedSearchText.isEmpty {
                    // All Games section
                    allGamesSection()

                    // Divider between All Games and systems
                    Divider()
                        .padding(.horizontal)

                    // Individual system sections
                    systemSections()
                } else {
                    // Search results
                    searchResultsView()
                }
            }
            .id(viewID) // Stabilize view with ID
            .padding()
        }
    }

    /// Section displaying all games
    @ViewBuilder
    private func allGamesSection() -> some View {
        let isExpanded = viewModel.expandedSections.contains("all")

        SwiftUI.Section {
            if isExpanded {
                /// Use cached sorted games for better performance
                let games = viewModel.cachedAllGamesSorted(
                    games: cachedGames,
                    sortOption: viewModel.selectedSortOption
                )
                if viewModel.selectedViewMode == .grid {
                    systemGamesGrid(games: games)
                } else {
                    systemGamesList(games: games)
                }
            }
        } header: {
            sectionHeader(title: "All Games", count: gamesCount, systemId: "all")
        }
        .padding(.bottom, 8)
    }

    /// Sections for individual systems
    @ViewBuilder
    private func systemSections() -> some View {
        ForEach(cachedSystems, id: \.identifier) { system in
            /// Check if system has games without sorting (fast check)
            let hasGames = !system.games.isEmpty
            let isExpanded = viewModel.expandedSections.contains(system.systemIdentifier.rawValue)
            let sectionId = "section-\(system.identifier)"

            if hasGames {
                SwiftUI.Section {
                    if isExpanded {
                        VStack(spacing: 0) {
                            saveStatesStrip(for: system)
                            /// Only fetch and sort games when section is expanded
                            let systemGames = gamesForSystem(system)
                            if viewModel.selectedViewMode == .grid {
                                systemGamesGrid(games: systemGames)
                            } else {
                                systemGamesList(games: systemGames)
                            }
                        }
                        #if os(tvOS)
                        .focusSection()
                        #endif
                    }
                } header: {
                    sectionHeader(
                        title: system.name,
                        subtitle: system.shortName,
                        count: system.games.count,
                        systemId: system.systemIdentifier.rawValue
                    )
                }
                .id(sectionId)
            }
        }
    }

    /// View displaying search results
    @ViewBuilder
    private func searchResultsView() -> some View {
        if filteredGames.isEmpty {
            VStack(spacing: 20) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor.opacity(0.5))

                Text("No games found matching '\(viewModel.debouncedSearchText)'")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else {
            if viewModel.selectedViewMode == .grid {
                systemGamesGrid(games: filteredGames)
            } else {
                systemGamesList(games: filteredGames)
            }
        }
    }

    // Empty library view
    /// A retrowave-styled empty library view with VHS effect
    @ViewBuilder
    private func emptyLibraryView() -> some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.retroDarkBlue, Color.retroBlack]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            // Grid pattern
            RetroGridPattern()
                .opacity(0.3)

            // VHS static effect overlay
            VHSStaticEffect()
                .opacity(0.1)

            // Main content
            VStack(spacing: 30) {
                // Retrowave title with glowing effect
                RetroGlowText("NO GAMES FOUND", fontSize: 32)
                    .padding(.top, 20)

                // Arcade controller icon
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.retroPink)
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.retroBlue)
                            .offset(x: 2, y: 2)
                            .opacity(0.7)
                            .blendMode(.screen)
                    )
                    .shadow(color: .retroPink.opacity(0.8), radius: 15, x: 0, y: 0)
                    .padding(.bottom, 10)

                // Subtitle with scanline effect
                Text("INSERT GAMES TO CONTINUE")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.retroBlack.opacity(0.5))
                    .overlay(RetroScanlineEffect())

                // Add games button with retrowave styling
                Button(action: {
                    #if !os(tvOS)
                    isShowingDocumentPicker = true
                    #else
                    // On tvOS, show import options directly
                    showImportOptions()
                    #endif
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.square.fill.on.square.fill")
                            .font(.system(size: 18))
                        Text("ADD GAMES")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 24)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .cornerRadius(8)
                    .shadow(color: .retroBlue.opacity(0.7), radius: 10, x: 0, y: 0)
                }
                .padding(.top, 20)

                // Cloud sync CTA for premium users with empty libraries
                CloudSyncUpsellView(
                    hasCachedCloudData: CloudSyncUpsellView.detectCachedCloudData(),
                    onOpenSettings: {
                        SettingsNavigator.shared.navigate(to: .cloudSync)
                        showImportOptions()
                    },
                    onUpgrade: {
                        SettingsNavigator.shared.navigate(to: .cloudSync)
                        showImportOptions()
                    }
                )
                .padding(.horizontal)

                // Controller pairing guide recommendation
                ControllerGuideCardView()
                    .padding(.horizontal)

                // Web server status - show when server is running
                if isWebServerRunning {
                    webServerStatusView()
                        .padding(.horizontal, 20)
                        .padding(.top, 30)
                }

                // VHS tracking line
                RetroTrackingLine()
                    .frame(height: 4)
                    .padding(.top, 40)
            }
            .padding(30)
        }
    }

    /// Function to refresh the import queue items
    // Import queue refresh is now handled by ImportProgressView

    /// Shows import options alert with document picker and web server options
    private func showImportOptions() {
        showingImportOptionsAlert = true
    }

    /// Starts the web server for importing files
    private func startWebServer() {
        #if canImport(PVWebServer)
        // Start the web server
        ILOG("RetroGameLibraryView: Starting web server for imports")
        PVWebServer.shared.startServers()

        // Show the web server URL
        if let serverURL = PVWebServer.shared.urlString {
            // Open Safari with the web server URL
            #if canImport(SafariServices)
            if let url = URL(string: serverURL) {
                let safariVC = SFSafariViewController(url: url)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {
                    rootViewController.present(safariVC, animated: true)
                }
            }
            #endif
        } else {
            // Show error message if server URL is not available
            viewModel.importMessage = "Error: Could not start web server"
            viewModel.showingImportMessage = true
        }
        #endif
    }

    private func importFiles(urls: [URL]) {
        ILOG("RetroGameLibraryView: Importing \(urls.count) files")

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            ELOG("RetroGameLibraryView: Could not access documents directory")
            viewModel.importMessage = "Error: Could not access documents directory"
            viewModel.showingImportMessage = true
            return
        }

        let importsDirectory = documentsDirectory.appendingPathComponent("Imports", isDirectory: true)

        // Create Imports directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: importsDirectory, withIntermediateDirectories: true)
        } catch {
            ELOG("RetroGameLibraryView: Error creating Imports directory: \(error.localizedDescription)")
            viewModel.importMessage = "Error creating Imports directory: \(error.localizedDescription)"
            viewModel.showingImportMessage = true
            return
        }

        var successCount = 0
        var errorMessages = [String]()

        for url in urls {
            let destinationURL = importsDirectory.appendingPathComponent(url.lastPathComponent)

            do {
                // If file already exists, remove it first
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                // Copy file to Imports directory
                try FileManager.default.copyItem(at: url, to: destinationURL)
                ILOG("RetroGameLibraryView: Successfully copied \(url.lastPathComponent) to Imports directory")
                successCount += 1
            } catch {
                ELOG("RetroGameLibraryView: Error copying file \(url.lastPathComponent): \(error.localizedDescription)")
                errorMessages.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Prepare result message
        if successCount == urls.count {
            viewModel.importMessage = "Successfully imported \(successCount) file(s). The game importer will process them shortly."
        } else if successCount > 0 {
            viewModel.importMessage = "Imported \(successCount) of \(urls.count) file(s). Some files could not be imported."
        } else {
            viewModel.importMessage = "Failed to import any files. \(errorMessages.first ?? "Unknown error")"
        }

        viewModel.showingImportMessage = true
    }

    // Launch game
    private func launchGame(_ game: PVGame) {
        ILOG("RetroGameLibraryView: Launching game: \(game.title) (ID: \(game.id))")

        // Use the SceneCoordinator to launch the game
        sceneCoordinator.launchGame(game)
    }

    // MARK: - Data Refresh

    /// Refresh game and system data from Realm
    /// Called once on appear and can be triggered manually for refresh
    private func refreshGameData() {
        DLOG("RetroGameLibraryView: Refreshing game data")

        /// Fetch games sorted by title
        let games = RomDatabase.sharedInstance.all(PVGame.self, sortedByKeyPath: "title")
        cachedGames = Array(games)
        gamesCount = cachedGames.count

        /// Fetch systems sorted by name
        let systems = RomDatabase.sharedInstance.all(PVSystem.self, sortedByKeyPath: "name")
        cachedSystems = Array(systems)

        /// Invalidate ViewModel cache since data changed
        viewModel.invalidateGamesCache()

        /// Prefetch recent save states for visible systems to avoid UI hitching
        Task(priority: .utility) {
            await saveStatesStore.prefetchRecent(systemIDs: cachedSystems.map(\.identifier), limit: 6)
        }

        needsDataRefresh = false
        DLOG("RetroGameLibraryView: Loaded \(gamesCount) games and \(cachedSystems.count) systems")
    }

    /// Scans all local ROM files and updates games marked as iCloud-only
    /// that actually have local files present. Fixes race condition between CloudKit
    /// sync and local file scanning.
    private func scanAndFixAllLocalFileStatus() async {
        // Step 1: Collect game info on main thread (fast Realm query)
        let gameInfoList: [(md5: String, systemId: String, filenames: [String], title: String)] = await MainActor.run {
            let realm = RomDatabase.sharedInstance.realm
            let gamesNeedingCheck = realm.objects(PVGame.self)
                .filter("isDownloaded == false")

            guard !gamesNeedingCheck.isEmpty else {
                DLOG("[LOCAL FILE FIX] No games need local file check")
                return []
            }

            ILOG("[LOCAL FILE FIX] Checking \(gamesNeedingCheck.count) games for local files")

            return gamesNeedingCheck.map { game in
                let filenames: [String] = [
                    game.file?.fileName,
                    game.romPath.isEmpty ? nil : URL(fileURLWithPath: game.romPath).lastPathComponent
                ].compactMap { $0 }.filter { !$0.isEmpty }
                return (md5: game.md5Hash, systemId: game.systemIdentifier, filenames: filenames, title: game.title)
            }
        }

        guard !gameInfoList.isEmpty else { return }

        // Step 2: Do file system scanning on background thread (no Realm access)
        let gamesToFix: [(md5: String, systemId: String, filename: String, path: URL, title: String)] = await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            var results: [(md5: String, systemId: String, filename: String, path: URL, title: String)] = []

            // Group by system
            var gamesBySystem: [String: [(md5: String, filenames: [String], title: String)]] = [:]
            for info in gameInfoList {
                if gamesBySystem[info.systemId] == nil {
                    gamesBySystem[info.systemId] = []
                }
                gamesBySystem[info.systemId]?.append((md5: info.md5, filenames: info.filenames, title: info.title))
            }

            // Check each system
            for (systemId, games) in gamesBySystem {
                let systemRomsPath = Paths.romsPath(forSystemIdentifier: systemId)
                guard fileManager.fileExists(atPath: systemRomsPath.path) else { continue }

                // Build set of local files (fast)
                var localFiles: [String: URL] = [:]
                if let enumerator = fileManager.enumerator(at: systemRomsPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for case let fileURL as URL in enumerator {
                        var isDir: ObjCBool = false
                        if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue {
                            localFiles[fileURL.lastPathComponent.lowercased()] = fileURL
                        }
                    }
                }

                guard !localFiles.isEmpty else { continue }

                // Match games to local files
                for game in games {
                    for filename in game.filenames {
                        if let foundPath = localFiles[filename.lowercased()] {
                            results.append((md5: game.md5, systemId: systemId, filename: filename, path: foundPath, title: game.title))
                            break
                        }
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
                            let relativePath = "\(gameInfo.systemId)/\(gameInfo.filename)"
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
            ILOG("[LOCAL FILE FIX] Fixed \(fixedCount) games that had local files but were marked as iCloud-only")
            await MainActor.run {
                needsDataRefresh = true
                refreshGameData()
            }
        }
    }
}

// MARK: - GameContextMenuDelegate

extension RetroGameLibraryView: GameContextMenuDelegate {
#if !os(tvOS)
    @ViewBuilder
    internal func imagePickerView() -> some View {
        ImagePicker(sourceType: .photoLibrary) { image in
            if let game = viewModel.gameToUpdateCover {
                viewModel.saveArtwork(image: image, forGame: game)
            }
            viewModel.gameToUpdateCover = nil
            viewModel.showImagePicker = false
        }
    }
#endif

    // MARK: - Rename Methods
    public func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame) {
        viewModel.gameToRename = game.freeze()
        viewModel.newGameTitle = game.title
        viewModel.showingRenameAlert = true
    }

    private func submitRename() {
        if !viewModel.newGameTitle.isEmpty, let frozenGame = viewModel.gameToRename, viewModel.newGameTitle != frozenGame.title {
            do {
                guard let thawedGame = frozenGame.thaw() else {
                    throw NSError(domain: "ConsoleGamesView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to thaw game object"])
                }
                RomDatabase.sharedInstance.renameGame(thawedGame, toTitle: viewModel.newGameTitle)
                //                rootDelegate?.showMessage("Game renamed successfully.", title: "Success")
            } catch {
                DLOG("Failed to rename game: \(error.localizedDescription)")
                //                rootDelegate?.showMessage("Failed to rename game: \(error.localizedDescription)", title: "Error")
            }
        } else if viewModel.newGameTitle.isEmpty {
            //            rootDelegate?.showMessage("Cannot set a blank title.", title: "Error")
        }
        viewModel.showingRenameAlert = false
        viewModel.gameToRename = nil
    }

    // MARK: - Image Picker Methods

    public func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        viewModel.gameToUpdateCover = game
        viewModel.showImagePicker = true
    }

    // saveArtwork method has been moved to the ViewModel
    private func availableSystems(forGame game: PVGame) -> [PVSystem] {
        PVEmulatorConfiguration.systems.filter {
            $0.identifier != game.systemIdentifier &&
            !(AppState.shared.isAppStore && $0.appStoreDisabled && !Defaults[.unsupportedCores])
        }
    }

    public func gameContextMenu(_ menu: GameContextMenu, didRequestMoveToSystemFor game: PVGame) {
        DLOG("RetroGameLibraryView: Received request to move game to system")
        let frozenGame = game.isFrozen ? game : game.freeze()
        viewModel.systemMoveState = RetroGameLibrarySystemMoveState(game: frozenGame, availableSystems: availableSystems(forGame: frozenGame))
    }

    public func gameContextMenu(_ menu: GameContextMenu, didRequestShowSaveStatesFor game: PVGame) {
        DLOG("RetroGameLibraryView: Received request to show save states for game")
        viewModel.continuesManagementState = RetroGameLibraryContinuesManagementState(game: game)
        let frozenGame = game.isFrozen ? game : game.freeze()
        saveBrowserContext = SaveBrowserContext(
            systemID: game.systemIdentifier,
            systemName: game.system?.name ?? game.systemIdentifier,
            game: frozenGame
        )
    }

    public func gameContextMenu(_ menu: GameContextMenu, didRequestShowGameInfoFor gameId: String) {
        /// Show the GameMoreInfoView for the selected game
        DLOG("RetroGameLibraryView: Showing game info for game ID: \(gameId)")

        /// Delegate to the ViewModel to handle showing the game info
        /// This ensures proper state management and consistent presentation
        viewModel.showGameInfo(gameId: gameId, appState: appState)
    }

    public func gameContextMenu(_ menu: GameContextMenu, didRequestShowImagePickerFor game: PVGame) {
        viewModel.gameToUpdateCover = game
        viewModel.showImagePicker = true
    }

    public func gameContextMenu(_ menu: GameContextMenu, didRequestShowArtworkSearchFor game: PVGame) {
        viewModel.gameToUpdateCover = game
        viewModel.showArtworkSearch = true
    }

    public func gameContextMenu(_ menu: GameContextMenu, didRequestChooseArtworkSourceFor game: PVGame) {
        DLOG("Setting gameToUpdateCover with game: \(game.title)")
        viewModel.gameToUpdateCover = game
        viewModel.showArtworkSourceAlert = true
    }

    public func gameContextMenu(_ menu: GameContextMenu, didRequestDiscSelectionFor game: PVGame) {
        // gamesViewModel.presentDiscSelectionAlert(for: game, rootDelegate: rootDelegate)
    }
}

// MARK: - System Section Helpers

extension RetroGameLibraryView {
    // MARK: - Computed Properties

    /// Filtered games based on search text
    private var filteredGames: [PVGame] {
        viewModel.filterGames(cachedGames)
    }

    /// Import progress view with retrowave styling
    @ViewBuilder
    private func importProgressView() -> some View {
        ImportProgressView(
            gameImporter: viewModel.gameImporter,
            updatesController: AppState.shared.libraryUpdatesController!,
            onTap: {
                viewModel.showImportStatusView = true
            }
        )
        .sheet(isPresented: $viewModel.showImportStatusView) {
            ImportStatusView(
                updatesController: AppState.shared.libraryUpdatesController!,
                gameImporter: viewModel.gameImporter,
                delegate: self.importStatusDelegate,
                dismissAction: {
                    viewModel.showImportStatusView = false
                }
            )
            .onAppear {
                // Setup the delegate when the view appears
                setupImportStatusDelegate()
            }
        }
    }
    // statusCountView has been moved to ImportProgressView

    // ImportStatusDelegate implementation moved to ImportStatusDelegateHelper class

    /// Custom search bar view
    private var searchBar: some View {
        customSearchBar()
    }

    /// Creates a custom search bar
    @ViewBuilder
    private func customSearchBar() -> some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(viewModel.isSearching ? themeManager.currentPalette.defaultTintColor.swiftUIColor : .gray)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isSearching)

                TextField("Search Games", text: $viewModel.searchText, onEditingChanged: { editing in
                    withAnimation {
                        viewModel.isSearching = editing
                    }
                })
                .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.retroBlack.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.retroPink, lineWidth: 1.5)
                    )
            )
        }
    }

    /// Get games for a specific system using cached sorting
    private func gamesForSystem(_ system: PVSystem) -> [PVGame] {
        return viewModel.cachedGamesForSystem(
            system.identifier,
            games: system.games,
            sortOption: viewModel.selectedSortOption
        )
    }

    /// Recent save states for a system from the shared store
    private func recentSaveStates(for system: PVSystem) -> [RetroSaveStateItem] {
        saveStatesStore.recentBySystem[system.identifier] ?? []
    }

    /// Loads recent save states for a system with caching
    private func loadRecentSaveStates(for system: PVSystem) async {
        _ = await saveStatesStore.loadRecent(forSystemID: system.identifier, limit: 6)
    }

    /// Horizontal strip of recent save states for a system
    @ViewBuilder
    private func saveStatesStrip(for system: PVSystem) -> some View {
        let items = recentSaveStates(for: system)
        if items.isEmpty {
            Color.clear
                .frame(height: 0)
                .task {
                    await loadRecentSaveStates(for: system)
                }
        } else {
            RetroRecentSaveStatesStrip(
                systemName: system.name,
                systemId: system.identifier,
                items: items,
                store: saveStatesStore,
                onOpen: { item in
                    Task { await saveStatesStore.openSaveState(id: item.id) }
                },
                onViewAll: {
                    saveBrowserContext = SaveBrowserContext(systemID: system.identifier, systemName: system.name, game: nil)
                }
            )
            .transition(.opacity)
        }
    }

    /// Creates a focus binding for a game ID
    /// On tvOS, uses centralized focus state; on iOS, returns constant binding
    private func gameIsFocusedBinding(for gameID: String) -> Binding<Bool> {
        #if os(tvOS)
        return Binding(
            get: { focusedGameID == gameID },
            set: { if $0 { focusedGameID = gameID } }
        )
        #else
        return .constant(false)
        #endif
    }

    /// Creates a collapsible section header for a system
    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String? = nil, count: Int, systemId: String) -> some View {
        Button(action: {
            viewModel.toggleSection(systemId)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)

                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle.uppercased())
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(Color.retroBlue)
                            .shadow(color: Color.retroPink.opacity(0.5), radius: 1, x: 1, y: 1)
                    }
                }

                Spacer()

                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.retroPurple.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.retroBlue, lineWidth: 1)
                    )
                    .cornerRadius(12)

                Image(systemName: viewModel.expandedSections.contains(systemId) ? "chevron.up" : "chevron.down")
                    .foregroundColor(themeManager.currentPalette.gameLibraryText.swiftUIColor)
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.retroBlack.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Creates a grid of games for a system
    @ViewBuilder
    private func systemGamesGrid(games: [PVGame]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)], spacing: 16) {
            ForEach(games, id: \.id) { game in
                gameGridItem(game: game)
            }
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    /// Creates a single game grid item
    @ViewBuilder
    private func gameGridItem(game: PVGame) -> some View {
        let gameID = game.id

        GameItemView(
            game: game,
            constrainHeight: false,
            viewType: .cell,
            sectionContext: .allGames,
            isFocused: gameIsFocusedBinding(for: gameID)
        ) {
            launchGame(game)
        }
        .contextMenu {
            GameContextMenu(
                game: game,
                rootDelegate: nil,
                contextMenuDelegate: self
            )
        }
        #if os(tvOS)
        .focused($focusedGameID, equals: gameID)
        #endif
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .id("grid-item-\(gameID)")
    }

    /// Creates a list of games for a system
    @ViewBuilder
    private func systemGamesList(games: [PVGame]) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(games, id: \.id) { game in
                gameListItem(game: game)
            }
        }
        #if os(tvOS)
        .focusSection()
        #endif
    }

    /// Creates a single game list item
    @ViewBuilder
    private func gameListItem(game: PVGame) -> some View {
        let gameID = game.id

        GameItemView(
            game: game,
            constrainHeight: true,
            viewType: .row,
            sectionContext: .allGames,
            isFocused: gameIsFocusedBinding(for: gameID)
        ) {
            launchGame(game)
        }
        .contextMenu {
            GameContextMenu(
                game: game,
                rootDelegate: nil,
                contextMenuDelegate: self
            )
        }
        #if os(tvOS)
        .focused($focusedGameID, equals: gameID)
        #endif
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .id("list-item-\(gameID)")
    }

    // MARK: - Web Server Status

    /// Updates the web server status
    /// Only fetches IP address when server is running to avoid expensive network interface enumeration
    private func updateWebServerStatus() {
        #if canImport(PVWebServer)
        DispatchQueue.main.async {
            let webServer = PVWebServer.shared
            let newRunningState = webServer.isWWWUploadServerRunning

            // Only update URLs (which trigger IP address lookup) if server is running
            // and status changed or URLs are not cached
            if newRunningState {
                // Only fetch URLs if status changed or we don't have them cached
                if newRunningState != self.isWebServerRunning || self.webServerURL == nil {
                    self.webServerURL = webServer.urlString
                    self.webDavURL = webServer.webDavURLString
                }
            } else {
                // Clear URLs when server stops
                self.webServerURL = nil
                self.webDavURL = nil
            }

            self.isWebServerRunning = newRunningState
        }
        #endif
    }

    /// Web server status view with retrowave styling
    @ViewBuilder
    private func webServerStatusView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with icon
            HStack(spacing: 8) {
                                Image(systemName: "wifi")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(RetroTheme.retroBlue)
                    .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 2, x: 0, y: 0)

                Text("WEB SERVER ACTIVE")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(RetroTheme.retroBlue)
                    .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 1, x: 0, y: 0)

                Spacer()

                // Running indicator
                Circle()
                    .fill(RetroTheme.retroBlue)
                    .frame(width: 8, height: 8)
                    .shadow(color: RetroTheme.retroBlue.opacity(0.8), radius: 3, x: 0, y: 0)
            }

            // URL Information
            VStack(alignment: .leading, spacing: 6) {
                if let webURL = webServerURL {
                    HStack(spacing: 6) {
                        Text("WEB:")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(RetroTheme.retroPink)
                            .frame(width: 50, alignment: .leading)

                        Text(webURL)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let webDavURL = webDavURL {
                    HStack(spacing: 6) {
                        Text("DAV:")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(RetroTheme.retroPink)
                            .frame(width: 50, alignment: .leading)

                        Text(webDavURL)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // Helper text
                Text("Upload files via browser or WebDAV client")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(RetroTheme.retroBlue.opacity(0.7))
                    .italic()
            }
            .padding(.leading, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(RetroTheme.retroBlack.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: RetroTheme.retroBlue.opacity(0.5), radius: 5, x: 0, y: 0)
    }
}

// MARK: - RetroGridShape

/// Efficient grid shape that draws all lines in a single path
/// instead of creating 40+ individual Rectangle views
struct RetroGridShape: Shape {
    let spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        /// Draw horizontal lines
        var y: CGFloat = 0
        while y < rect.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }

        /// Draw vertical lines
        var x: CGFloat = 0
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }

        return path
    }
}

/// Context for presenting the save-state browser
private struct SaveBrowserContext: Identifiable {
    let systemID: String
    let systemName: String
    let game: PVGame?

    var id: String { game?.id ?? systemID }
}
