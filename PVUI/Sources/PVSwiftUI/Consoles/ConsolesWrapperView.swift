//
//  ConsolesWrapperView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/26/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
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
            // importStatusOverlayView
            
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

            Task(priority: .userInitiated) {
                // Preload artwork for visible consoles
                if let selectedConsole = consoles.first(where: { $0.identifier == delegate.selectedTab }) {
                    preloadArtworkForConsole(selectedConsole)
                }
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

    private func sortedConsoles() -> [PVSystem] {
        viewModel.sortConsolesAscending ? consoles.map { $0 } : consoles.reversed()
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

    /// Preload artwork for a console's games
    private func preloadArtworkForConsole(_ console: PVSystem) {
        Task(priority: .low) {
            // Get the first 20 games for this console
            let games = Array(console.games.prefix(20))

            // Preload their artwork
            ArtworkLoader.shared.preloadArtwork(for: games)
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

    @ViewBuilder
    var consolesList: some View {
        ForEach(sortedConsoles(), id: \.self) { console in
            ConsoleGamesView(
                console: console,
                viewModel: viewModel,
                rootDelegate: rootDelegate,
                showGameInfo: showGameInfo
            )
            .tabItem {
                if #available(iOS 17.0, tvOS 17.0, *) {
                    // Simplified tab item to reduce rendering overhead
                    Label(console.name, image: ImageResource(name: console.iconName, bundle: PVUIBase.BundleLoader.myBundle))
                } else {
                    // Fallback for older iOS versions
                    Label(console.name, systemImage: "gamecontroller")
                }
            }
            .tag(console.identifier)
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }

    var importStatusOverlayView: some View {
        // Import Progress View at the top
        VStack {
            ImportProgressView(
                gameImporter: GameImporter.shared,
                updatesController: AppState.shared.libraryUpdatesController!,
                onTap: {
                    showImportStatusView = true
                }
            )
//            .padding(.horizontal)
//            .padding(.top, 8)
        }
        .sheet(isPresented: $showImportStatusView) {
            ImportStatusView(
                updatesController: AppState.shared.libraryUpdatesController!,
                gameImporter: GameImporter.shared,
                dismissAction: {
                    showImportStatusView = false
                }
            )
        }
        .onChange(of: delegate.selectedTab) { newValue in
            DLOG("Tab changed in view: \(newValue)")
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(consoles.count)
        .tint(themeManager.currentPalette.defaultTintColor.swiftUIColor)
        .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
    }
    
    @ViewBuilder
    var consolesTabView: some View {
        let binding = Binding(
            get: { delegate.selectedTab },
            set: { newTab in
                Task {
                    // Store the previous tab before changing
                    previousTab = delegate.selectedTab

                    // Set the new tab
                    delegate.setTab(newTab)

                    // Preload artwork for the selected console
                    if let selectedConsole = consoles.first(where: { console in console.identifier == newTab }) {
                        preloadArtworkForConsole(selectedConsole)
                    }
                }
                
                Task {
                    // Trigger haptic feedback for user-initiated tab changes
                    #if !os(tvOS)
                    if isVisible && previousTab != newTab {
                        Haptics.impact(style: .soft)
                    }
                    #endif
                }
            }
        )

        return TabView(selection: binding) {
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
        .onChange(of: delegate.selectedTab) { newValue in
            DLOG("Tab changed in view: \(newValue)")
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(consoles.count)
        .tint(themeManager.currentPalette.defaultTintColor.swiftUIColor)
        .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
    }
}

#endif
