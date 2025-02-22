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
            UserDefaults.standard.set(selectedTab, forKey: Self.tabKey)
            print("Tab saved to UserDefaults: \(selectedTab)")
        }
    }

    init() {
        // Load the saved tab on init
        selectedTab = UserDefaults.standard.string(forKey: Self.tabKey) ?? "home"
        print("ConsolesWrapperViewDelegate initialized with tab: \(selectedTab)")
    }

    func setTab(_ tab: String) {
        selectedTab = tab
        print("Tab changed to: \(tab)")
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
        AnyView(
            Group {
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
        )
        .environment(\.rootDelegate, rootDelegate)
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
            return .purple
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
                    Label(console.name, image: ImageResource(name: console.iconName, bundle: PVUIBase.BundleLoader.myBundle))
                        .blur(radius: 10)
                        .opacity(0.3)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .clear,
                                    glowColor.opacity(0.3),
                                    .clear
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .blendMode(.screen)
                        )
                } else {
//                    Label(console.name, image: Image(console.iconName, bundle: PVUIBase.BundleLoader.myBundle))
                }
            }
            .tag(console.identifier)
            .ignoresSafeArea(.all, edges: .bottom)
        }
    }

    @ViewBuilder
    var consolesTabView: some View {
        let binding = Binding(
            get: { delegate.selectedTab },
            set: { delegate.setTab($0) }
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
            print("Tab changed in view: \(newValue)")
            #if !os(tvOS)
            Haptics.impact(style: .soft)
            #endif
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(consoles.count)
        .tint(themeManager.currentPalette.defaultTintColor?.swiftUIColor)
        .foregroundStyle(themeManager.currentPalette.gameLibraryText.swiftUIColor)
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
    }
}

#endif
