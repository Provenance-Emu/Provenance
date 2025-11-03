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

    @AppStorage("showFeatureFlagsDebug") private var showFeatureFlagsDebug = false

    @State private var showEmptySystems: Bool
    @State private var gameInfoState: GameInfoState?
    @ObservedResults(PVSystem.self) private var consoles: Results<PVSystem>
    @ObservedObject private var themeManager = ThemeManager.shared

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
                playGameCallback: { [weak rootDelegate] md5 in
                    await rootDelegate?.root_loadGame(byMD5Hash: md5)
                }
            )
            return AnyView(PagedGameMoreInfoView(viewModel: viewModel))
        } catch {
            return AnyView(Text("Failed to load game info: \(error.localizedDescription)"))
        }
    }

    var body: some View {
        Group {
            // Add a glowing border line using glowColor
            RetroDividerView()
                .shadow(color: .retroPink, radius: 4, x: 0, y: 1)

            if consoles.isEmpty || (consoles.count == 1 && consoles.first!.identifier == SystemIdentifier.RetroArch.rawValue) {
                noConsolesView
            } else {
                consolesTabView
                    .sheet(item: $gameInfoState) { state in
                        NavigationView {
                            makeGameMoreInfoView(for: state)
                            #if !os(tvOS)
                                .navigationBarTitleDisplayMode(.inline)
                            #endif
                        }
                    }
            }
        }
        .environment(\.rootDelegate, rootDelegate)
        .onAppear {
            isVisible = true

            // Initialize cached sorted consoles
            cachedSortedConsoles = viewModel.sortConsolesAscending ? Array(consoles) : Array(consoles.reversed())

            Task(priority: .userInitiated) {
                // Preload artwork for visible console only (lazy loading)
                if let selectedConsole = consoles.first(where: { $0.identifier == delegate.selectedTab }) {
                    preloadArtworkForConsole(selectedConsole)
                }
            }
        }
        .onChange(of: viewModel.sortConsolesAscending) { _ in
            // Invalidate cache when sort order changes
            cachedSortedConsoles = viewModel.sortConsolesAscending ? Array(consoles) : Array(consoles.reversed())
        }
        .onChange(of: consoles.count) { _ in
            // Invalidate cache when consoles change
            cachedSortedConsoles = viewModel.sortConsolesAscending ? Array(consoles) : Array(consoles.reversed())
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

    /// Optimized sorted consoles with caching
    private func sortedConsoles() -> [PVSystem] {
        let sorted = viewModel.sortConsolesAscending ? Array(consoles) : Array(consoles.reversed())
        // Only update cache if consoles actually changed
        if cachedSortedConsoles.count != sorted.count ||
           cachedSortedConsoles.map(\.identifier) != sorted.map(\.identifier) {
            cachedSortedConsoles = sorted
        }
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

    /// Optimized artwork preloading - only loads visible games first
    private func preloadArtworkForConsole(_ console: PVSystem) {
        Task(priority: .utility) {
            // Only preload first 10 games initially for faster tab switching
            // Remaining artwork will load lazily as user scrolls
            let games = Array(console.games.prefix(10))

            if !games.isEmpty {
                ArtworkLoader.shared.preloadArtwork(for: games)
            }
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
        ForEach(sortedConsoles(), id: \.identifier) { (console: PVSystem) in
            if console.identifier != SystemIdentifier.RetroArch.rawValue || forceRetroarchConsole { // Skip RetroArch unless in forced
                ConsoleGamesView(
                    console: console,
                    viewModel: viewModel,
                    rootDelegate: rootDelegate,
                    showGameInfo: showGameInfo
                )
                .id(console.identifier) // Keep ConsoleGamesView instance stable
                .background(RetroTheme.retroBackground)
                .toolbarColorScheme(SwiftUI.ColorScheme.dark, for: SwiftUI.ToolbarPlacement.tabBar)
                .tag(console.identifier)
                .tabItem {
                    let iconName = console.iconName
                    if let icon = rasterizedTabIcon(named: iconName) {
                        Label {
                            Text(console.name)
                        } icon: { icon }
                    } else {
                        // Generic fallback
                        Label(console.name, systemImage: "gamecontroller")
                            .imageScale(.medium)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var consolesTabView: some View {
        let binding = Binding(
            get: { delegate.selectedTab },
            set: { newTab in
                // Store the previous tab before changing
                let oldTab = previousTab
                previousTab = delegate.selectedTab

                // Set the new tab immediately (main thread operation)
                delegate.setTab(newTab)

                // Combine operations into a single Task to reduce overhead
                Task { @MainActor in
                    // Trigger haptic feedback for user-initiated tab changes
                    #if !os(tvOS)
                    if isVisible && oldTab != newTab {
                        Haptics.impact(style: .soft)
                    }
                    #endif

                    // Preload artwork for the selected console (deferred to avoid blocking)
                    if let selectedConsole = consoles.first(where: { $0.identifier == newTab }) {
                        preloadArtworkForConsole(selectedConsole)
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
    /// Cached icon rasterization to avoid repeated image processing
    private func rasterizedTabIcon(named name: String) -> Image? {
        if name.isEmpty { return nil }

        // Check cache first
        if let cached = Self.iconCache[name] {
            return cached
        }

        #if canImport(UIKit)
        // Derive a conservative size based on tab bar metrics to prevent page style from upscaling
        let defaultPointSize: CGFloat = 12
        let font = UIFont.systemFont(ofSize: defaultPointSize, weight: .regular)
        let metrics = UIFontMetrics(forTextStyle: .footnote)
        let clamped = metrics.scaledValue(for: font.pointSize)
        let side = max(36, min(42, clamped))
        let targetSize = CGSize(width: side, height: side)
        guard let source = UIImage(named: name, in: PVUIBase.BundleLoader.myBundle, compatibleWith: nil) else {
            return nil
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

#endif
