//
//  ConsolesWrapperView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/26/22.
//  Copyright 2022 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVUIBase
import PVRealm
import PVThemes
import Combine
#if !os(tvOS)
import UIKit
#endif

private struct PVRootDelegateKey: EnvironmentKey {
    static let defaultValue: PVRootDelegate? = nil
}

extension EnvironmentValues {
    var rootDelegate: PVRootDelegate? {
        get { self[PVRootDelegateKey.self] }
        set { self[PVRootDelegateKey.self] = newValue }
    }
}

@available(iOS 14, tvOS 14, *)
class ConsolesWrapperViewDelegate: ObservableObject {
    private static let tabKey = "PVLastSelectedConsoleTab"

    @Published var selectedTab: String {
        didSet {
            Task.detached(priority: .low) { [self] in
                UserDefaults.standard.set(selectedTab, forKey: Self.tabKey)
                DLOG("Tab saved to UserDefaults: \(selectedTab)")
            }
        }
    }

    init() {
        // Load the saved tab on init
        selectedTab = UserDefaults.standard.string(forKey: Self.tabKey) ?? "home"
        DLOG("ConsolesWrapperViewDelegate initialized with tab: \(selectedTab)")
    }

    func setTab(_ tab: String) {
        selectedTab = tab
        DLOG("Tab changed to: \(tab)")
    }
}

@available(iOS 14, tvOS 14, *)
struct ConsolesWrapperView: SwiftUI.View {

    // MARK: - Properties

    @ObservedObject var delegate: ConsolesWrapperViewDelegate
    @ObservedObject var viewModel: PVRootViewModel
    weak var rootDelegate: (PVRootDelegate & PVMenuDelegate)!

    @ObservedObject private var bootupStateManager = AppState.shared.bootupStateManager

    @AppStorage("showFeatureFlagsDebug") private var showFeatureFlagsDebug = false

    @State private var showEmptySystems: Bool
    @State private var gameInfoState: GameInfoState?
    @ObservedResults(PVSystem.self) private var consoles: Results<PVSystem>
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Observe the sync status manager for download progress overlay
    @ObservedObject private var syncStatusManager = SceneCoordinator.shared.syncStatusManager

    /// Track if view is currently visible
    @State private var isVisible: Bool = false

    /// Track the previous tab for comparison
    @State private var previousTab: String = ""

    /// State to control the presentation of ImportStatusView
    @State private var showImportStatusView = false

    /// Cache for sorted consoles to avoid repeated array conversions
    @State private var cachedSortedConsoles: [PVSystem] = []

    /// Cache for rasterized tab icons to avoid repeated image processing
    private static var iconCache: [String: Image] = [:]

    /// State to track loaded icons asynchronously
    @State private var loadedIcons: [String: Image] = [:]
    /// Track consoles whose views have been instantiated to keep them alive after first load
    @State private var loadedConsoleIDs: Set<String> = []

    /// State for game info presentation
    struct GameInfoState: Identifiable {
        let id: String
    }

    // MARK: - Initializer

    init(
        consolesWrapperViewDelegate: ConsolesWrapperViewDelegate,
        viewModel: PVRootViewModel,
        rootDelegate: PVRootDelegate & PVMenuDelegate
    ) {
        self.delegate = consolesWrapperViewDelegate
        self.viewModel = viewModel
        self.rootDelegate = rootDelegate

        #if targetEnvironment(simulator)
        _showEmptySystems = State(initialValue: true)
        #else
        _showEmptySystems = State(initialValue: false)
        #endif

        // Set the filter for consoles based on showEmptySystems
        let filter = showEmptySystems ? nil : NSPredicate(format: "games.@count > 0")
        _consoles = ObservedResults(PVSystem.self, filter: filter, sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSystem.name), ascending: true))
    }

    // MARK: - Body
    @ViewBuilder
    private func makeGameMoreInfoView(for state: GameInfoState) -> some View {
        do {
            let driver = try RealmGameLibraryDriver()
            let viewModel = PagedGameMoreInfoViewModel(
                driver: driver,
                initialGameId: state.id,
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
            return AnyView(Text("Failed to load game info: \(error.localizedDescription)"))
        }
    }

    var body: some View {
        ZStack {
            Group {
                // Add a glowing border line using glowColor
                RetroDividerView()
                    .shadow(color: .retroPink, radius: 4, x: 0, y: 1)

                if bootupStateManager.isBootupCompleted && (consoles.isEmpty || (consoles.count == 1 && consoles.first!.identifier == SystemIdentifier.RetroArch.rawValue)) {
                    noConsolesView
                } else if !bootupStateManager.isBootupCompleted {
                    // Still loading — show nothing to avoid a jarring empty-state flash on launch
                    Color.clear
                } else {
                    consolesTabView
                        .sheet(item: $gameInfoState) { state in
                            NavigationStack {
                                makeGameMoreInfoView(for: state)
                                #if !os(tvOS)
                                    .navigationBarTitleDisplayMode(.inline)
                                #endif
                            }
                            #if !os(tvOS)
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                            #endif
                        }
                }
            }

            // Sync status overlay for cloud downloads
            if syncStatusManager.isVisible {
                GameSyncStatusView(
                    gameTitle: syncStatusManager.gameTitle,
                    statusMessage: syncStatusManager.statusMessage,
                    isComplete: syncStatusManager.isComplete,
                    hasError: syncStatusManager.hasError,
                    onCancel: syncStatusManager.onCancel
                )
                .transition(.opacity)
                .animation(.easeInOut, value: syncStatusManager.isVisible)
            }

            // RetroWave styled alert overlay
            RetroAlertStateView(alertState: SceneCoordinator.shared.alertState)
        }
        .environment(\.rootDelegate, rootDelegate)
        .onAppear {
            isVisible = true

            // Defer non-critical operations to background
            Task.detached(priority: .utility) {
                // Initialize cached sorted consoles off main thread
                await MainActor.run {
                    self.updateCachedSortedConsoles()
                }

                // Preload artwork for visible console off main thread (lazy loading)
                let selectedConsole = await MainActor.run {
                    self.consoles.first(where: { $0.identifier == self.delegate.selectedTab })
                }
                if let console = selectedConsole {
                    await self.preloadArtworkForConsole(console)
                }

                // Load tab icons asynchronously off main thread
                await self.loadTabIconsAsync()
            }
        }
        .onChange(of: viewModel.sortConsolesAscending) { _ in
            // Update cache off main thread
            Task.detached(priority: .utility) {
                await MainActor.run {
                    self.updateCachedSortedConsoles()
                }
            }
        }
        .onChange(of: consoles.count) { _ in
            // Update cache off main thread
            Task.detached(priority: .utility) {
                await MainActor.run {
                    self.updateCachedSortedConsoles()
                }
                // Reload icons for new consoles
                await self.loadTabIconsAsync()
            }
        }
        .onDisappear {
            isVisible = false
        }
        .ignoresSafeArea(edges: .all)
        .padding(.top, 14)
    }

    // MARK: - Helper Methods

    func showGameInfo(for gameId: String) {
        gameInfoState = GameInfoState(id: gameId)
    }

    /// Update the cached sorted consoles (thread-safe)
    private func updateCachedSortedConsoles() {
        let ascending = viewModel.sortConsolesAscending
        let consolesArray = Array(consoles)
        cachedSortedConsoles = ascending ? consolesArray : consolesArray.reversed()
    }

    /// Optimized sorted consoles with caching
    private func sortedConsoles() -> [PVSystem] {
        return cachedSortedConsoles
    }

    private var glowColor: Color {
        switch themeManager.currentPalette {
        case is DarkThemePalette:
            return .cyan
        case is LightThemePalette:
            return .blue
        default:
            return themeManager.currentPalette.defaultTintColor.swiftUIColor ?? .purple
        }
    }

    /// Optimized artwork preloading - only loads visible games first (non-blocking)
    private func preloadArtworkForConsole(_ console: PVSystem) async {
        // Only preload first 10 games initially for faster tab switching
        // Remaining artwork will load lazily as user scrolls
        let games = await MainActor.run {
            Array(console.games.prefix(10))
        }

        if !games.isEmpty {
            // ArtworkLoader.preloadArtwork already spawns a Task internally, so we don't need to await
            // Just call it off main thread - it will handle its own async work
            ArtworkLoader.shared.preloadArtwork(for: games, priority: .utility)
        }
    }

    @ViewBuilder
    private var noConsolesView: some View {
        NoConsolesView(delegate: rootDelegate as! PVMenuDelegate)
            .tabItem {
                Label("No Consoles", systemImage: "xmark.circle")
            }
            .tag("noConsoles")
    }

    var forceRetroarchConsole: Bool {
        return true
    }

    @ViewBuilder
    var consolesList: some View {
        let consoles = sortedConsoles()
        ForEach(consoles, id: \.identifier) { (console: PVSystem) in
            if console.identifier != SystemIdentifier.RetroArch.rawValue || forceRetroarchConsole { // Skip RetroArch unless in forced
                let isRenderable = shouldRenderConsoleTab(console.identifier, consoles: consoles) || loadedConsoleIDs.contains(console.identifier)
                ZStack {
                    if isRenderable {
                        ConsoleGamesView(
                            console: console,
                            viewModel: viewModel,
                            rootDelegate: rootDelegate,
                            showGameInfo: showGameInfo
                        )
                        .id(console.identifier) // Keep ConsoleGamesView instance stable
                        .onAppear {
                            loadedConsoleIDs.insert(console.identifier)
                        }
                    }

                    if !loadedConsoleIDs.contains(console.identifier) {
                        ConsolePlaceholderView(systemName: console.name)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .background(RetroTheme.retroBackground)
                .toolbarColorScheme(SwiftUI.ColorScheme.dark, for: SwiftUI.ToolbarPlacement.tabBar)
                .tag(console.identifier)
                .tabItem {
                    let iconName = console.iconName
                    if let icon = loadedIcons[iconName] {
                        Label {
                            Text(console.name)
                        } icon: { icon }
                    } else {
                        // Generic fallback while loading
                        Label(console.name, systemImage: "gamecontroller")
                            .imageScale(.medium)
                    }
                }
            }
        }
    }

    private func shouldRenderConsoleTab(_ identifier: String, consoles: [PVSystem]) -> Bool {
        if identifier == delegate.selectedTab { return true }
        if identifier == previousTab { return true }

        guard let selectedIndex = consoles.firstIndex(where: { $0.identifier == delegate.selectedTab }) else {
            return false
        }

        let neighborIndices = [selectedIndex - 1, selectedIndex + 1].filter { $0 >= 0 && $0 < consoles.count }
        return neighborIndices.contains { consoles[$0].identifier == identifier }
    }

    @ViewBuilder
    var consolesTabView: some View {
        let binding = Binding<String>(
            get: { delegate.selectedTab },
            set: { newTab in
                previousTab = delegate.selectedTab
                // Set the new tab immediately (main thread operation)
                delegate.setTab(newTab)

                // Preload artwork off main thread to avoid blocking tab switch
                Task.detached(priority: .utility) {
                    let selectedConsole = await MainActor.run {
                        self.consoles.first(where: { $0.identifier == newTab })
                    }
                    if let console = selectedConsole {
                        await self.preloadArtworkForConsole(console)
                    }
                }
            }
        )

        return TabView(selection: binding) {
            if showFeatureFlagsDebug {
                RetroDebugView()
                    .tabItem {
                        Label("Debug", systemImage: "bug")
                    }
                    .tag("debug")
                    .ignoresSafeArea(.all, edges: .bottom)
                    .navigationTitle(Text("Debug"))

                ScrollView {
                    VStack {
                        RetroStatusControlView()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)

                        FileRecoveryTestView()
                    }
                }
                .tabItem {
                    Label("Test", systemImage: "test")
                }
                .tag("test")
                .ignoresSafeArea(.all, edges: .bottom)
            }
            HomeView(
                gameLibrary: rootDelegate.gameLibrary!,
                delegate: rootDelegate,
                viewModel: viewModel,
                showGameInfo: showGameInfo
            )
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag("home")
            .ignoresSafeArea(.all, edges: .bottom)

            consolesList
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .onChange(of: delegate.selectedTab) { newValue in
            DLOG("Tab changed in view: \(newValue)")
        }
        .tint(themeManager.currentPalette.defaultTintColor.swiftUIColor)
        .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
    }

    // MARK: - Icon Rasterization
    /// Load tab icons asynchronously off the main thread
    private func loadTabIconsAsync() async {
        let consolesToLoad = await MainActor.run {
            sortedConsoles()
        }

        var newIcons: [String: Image] = [:]

        for console in consolesToLoad {
            let iconName = console.iconName
            if iconName.isEmpty { continue }

            // Check static cache first (thread-safe read)
            if let cached = Self.iconCache[iconName] {
                newIcons[iconName] = cached
                continue
            }

            // Load and rasterize icon off main thread
            if let icon = await rasterizeTabIconAsync(named: iconName) {
                newIcons[iconName] = icon
                // Update static cache
                await MainActor.run {
                    Self.iconCache[iconName] = icon
                }
            }
        }

        // Update UI on main thread
        await MainActor.run {
            loadedIcons.merge(newIcons) { _, new in new }
        }
    }

    /// Async icon rasterization to avoid blocking main thread
    private func rasterizeTabIconAsync(named name: String) async -> Image? {
        if name.isEmpty { return nil }

        #if canImport(UIKit)
        // Load image off main thread
        guard let source = UIImage(named: name, in: PVUIBase.BundleLoader.myBundle, compatibleWith: nil) else {
            return nil
        }

        // Derive a conservative size based on tab bar metrics to prevent page style from upscaling
        let defaultPointSize: CGFloat = 12
        let font = UIFont.systemFont(ofSize: defaultPointSize, weight: .regular)
        let metrics = UIFontMetrics(forTextStyle: .footnote)
        let clamped = metrics.scaledValue(for: font.pointSize)
        let maxSide = max(36, min(42, clamped))

        // Preserve aspect ratio of original image
        let sourceSize = source.size
        let aspectRatio = sourceSize.width / sourceSize.height

        // Calculate target size maintaining aspect ratio
        let targetSize: CGSize
        if aspectRatio > 1.0 {
            // Wider than tall - constrain by width
            targetSize = CGSize(width: maxSide, height: maxSide / aspectRatio)
        } else {
            // Taller than wide or square - constrain by height
            targetSize = CGSize(width: maxSide * aspectRatio, height: maxSide)
        }

        // Perform rasterization off main thread
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaled = renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return Image(uiImage: scaled).renderingMode(.template)
        #else
        return nil
        #endif
    }

    /// Cached icon rasterization to avoid repeated image processing (deprecated - use async version)
    private func rasterizedTabIcon(named name: String) -> Image? {
        if name.isEmpty { return nil }

        // Check cache first
        if let cached = Self.iconCache[name] {
            return cached
        }

        #if canImport(UIKit)
        guard let source = UIImage(named: name, in: PVUIBase.BundleLoader.myBundle, compatibleWith: nil) else {
            return nil
        }

        // Derive a conservative size based on tab bar metrics to prevent page style from upscaling
        let defaultPointSize: CGFloat = 12
        let font = UIFont.systemFont(ofSize: defaultPointSize, weight: .regular)
        let metrics = UIFontMetrics(forTextStyle: .footnote)
        let clamped = metrics.scaledValue(for: font.pointSize)
        let maxSide = max(36, min(42, clamped))

        // Preserve aspect ratio of original image
        let sourceSize = source.size
        let aspectRatio = sourceSize.width / sourceSize.height

        // Calculate target size maintaining aspect ratio
        let targetSize: CGSize
        if aspectRatio > 1.0 {
            // Wider than tall - constrain by width
            targetSize = CGSize(width: maxSide, height: maxSide / aspectRatio)
        } else {
            // Taller than wide or square - constrain by height
            targetSize = CGSize(width: maxSide * aspectRatio, height: maxSide)
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaled = renderer.image { _ in
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        let image = Image(uiImage: scaled).renderingMode(.template)

        // Cache the result
        Self.iconCache[name] = image
        return image
        #else
        return nil
        #endif
    }
}

private struct ConsolePlaceholderView: View {
    let systemName: String

    var body: some View {
        ZStack {
            RetroTheme.retroBackground
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Loading \(systemName)…")
                    .foregroundColor(.retroPink)
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#endif
