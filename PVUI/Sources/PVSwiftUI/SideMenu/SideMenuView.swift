//
//  SideMenuView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import Combine
@_exported import PVUIBase

#if canImport(Introspect)
import Introspect
#endif
#if canImport(FreemiumKit)
import FreemiumKit
#endif

// Add at the top of the file, after imports
extension View {
    @ViewBuilder
    func focusableIfAvailable() -> some View {
        if #available(iOS 17, tvOS 17, *) {
            self.focusable(true)
        } else {
            self
        }
    }
}

// generate a preview

extension PVSystem {
    var iconName: String {
        // Take the last segment of identifier seperated by .
        return self.identifier.components(separatedBy: ".").last?.lowercased() ?? "prov_snes_icon"
    }
}

@available(iOS 14, tvOS 14, *)
public struct
SideMenuView: SwiftUI.View {

    weak var delegate: PVMenuDelegate!

	@ObservedObject
	var viewModel: PVRootViewModel

	weak var rootDelegate: PVRootDelegate!
    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>

    @State private var showEmptySystems: Bool
    @ObservedResults(PVSystem.self) private var consoles: Results<PVSystem>

    @ObservedObject var searchBar: SearchBar

    @ObservedObject private var themeManager = ThemeManager.shared

#if canImport(FreemiumKit)
    @State var showPaywall: Bool = false
    @EnvironmentObject var freemiumKit: FreemiumKit
#endif

    @State private var gamepadHandler: Any?

    @FocusState private var focusedItem: String?

    @Namespace private var menuNamespace

    @State private var lastFocusedItem: String?

    @State private var gamepadCancellable: AnyCancellable?

    public init(gameLibrary: PVGameLibrary<RealmDatabaseDriver>, viewModel: PVRootViewModel, delegate: PVMenuDelegate, rootDelegate: PVRootDelegate) {
        self.gameLibrary = gameLibrary
        self.viewModel = viewModel
        self.delegate = delegate
        self.rootDelegate = rootDelegate

        #if os(tvOS)
        searchBar = SearchBar(searchResultsController: rootDelegate as! UIViewController)
        #else
        searchBar = SearchBar(searchResultsController: nil)
        #endif

        #if targetEnvironment(simulator)
        _showEmptySystems = State(initialValue: true)
        #else
        _showEmptySystems = State(initialValue: false)
        #endif

        // Set the filter for consoles based on showEmptySystems
        let filter = showEmptySystems ? nil : NSPredicate(format: "games.@count > 0")
        _consoles = ObservedResults(PVSystem.self, filter: filter)

        setupGamepadHandling()
    }

    public static func instantiate(gameLibrary: PVGameLibrary<RealmDatabaseDriver>, viewModel: PVRootViewModel, delegate: PVMenuDelegate, rootDelegate: PVRootDelegate) -> UIViewController {
        let view = SideMenuView(gameLibrary: gameLibrary, viewModel: viewModel, delegate: delegate, rootDelegate: rootDelegate)
        let hostingView = UIHostingController(rootView: view)
        let nav = UINavigationController(rootViewController: hostingView)
        return nav
    }

    func versionText() -> String {
        let gitBranch = PackageBuild.info.builtBy ?? Bundle.main.infoDictionary?["GIT_BRANCH"] as? String ?? ""
        let masterBranch: Bool = gitBranch.lowercased() == "master"
        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        if AppState.shared.isAppStore {
            versionText = "\(versionText ?? "")"
        } else if !masterBranch {
            versionText = "\(versionText ?? "") Experimental"
        }
        return versionText ?? ""
    }

    func sortedConsoles() -> Results<PVSystem> {
        return self.consoles.sorted(by: [SortDescriptor(keyPath: #keyPath(PVSystem.name), ascending: viewModel.sortConsolesAscending)])
    }

    func filteredSearchResults() -> Results<PVGame> {
        return self.gameLibrary.searchResults(for: self.searchBar.text)
    }

    private func setupGamepadHandling() {
        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { event in
                switch event {
                case .buttonPress:
                    handleButtonPress()
                case .buttonB:
                    delegate.closeMenu()
                case .verticalNavigation(let value):
                    handleVerticalNavigation(value)
                default:
                    break
                }
            }
    }

    private func handleButtonPress() {
        guard let focusedItem = focusedItem else { return }

        switch focusedItem {
        case "home":
            delegate.didTapHome()
        case "settings":
            delegate.didTapSettings()
        case "imports":
            delegate.didTapImports()
        default:
            // Handle console selection
            delegate.didTapConsole(with: focusedItem)
        }
    }

    private func handleVerticalNavigation(_ value: Float) {
        let items = ["home", "settings", "imports"] + consoles.map(\.identifier)

        if let currentItem = focusedItem,
           let currentIndex = items.firstIndex(of: currentItem) {
            let newIndex = value > 0 ?
                max(0, currentIndex - 1) :
                min(items.count - 1, currentIndex + 1)
            focusedItem = items[newIndex]
        } else {
            focusedItem = items.first
        }
    }

    public var body: some SwiftUI.View {
        StatusBarProtectionWrapper {
            ScrollView {
                VStack {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Divider()
                            .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)

                        MenuItemView(icon: .named("prov_home_icon"), rowTitle: "Home", isFocused: focusedItem == "home") {
                            delegate.didTapHome()
                        }
                        .focusableIfAvailable()
                        .focused($focusedItem, equals: "home")

                        Divider()
                            .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)

                        MenuItemView(icon: .named("prov_settings_gear"), rowTitle: "Settings", isFocused: focusedItem == "settings") {
                            delegate.didTapSettings()
                        }
                        .focusableIfAvailable()
                        .focused($focusedItem, equals: "settings")

    //                    Divider()
    //                        .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)
    //
    //                    MenuItemView(icon: .named("prov_add_games_icon"), rowTitle: "Add Games") {
    //                        delegate?.didTapAddGames()
    //                    }
                        Divider()
                            .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)

                        MenuItemView(icon: .sfSymbol("checklist"), rowTitle: "Add Games", isFocused: focusedItem == "imports") {
                            delegate.didTapImports()
                        }
                        .focusableIfAvailable()
                        .focused($focusedItem, equals: "imports")
    #if canImport(FreemiumKit)
                        Divider()
                            .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)
                        PaidStatusView(style: .plain)
                            .listRowBackground(Color.accentColor)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
    #endif
                        if consoles.count > 0 {
                            MenuSectionHeaderView(sectionTitle: "CONSOLES", sortable: consoles.count > 1, sortAscending: viewModel.sortConsolesAscending) {
                                viewModel.sortConsolesAscending.toggle()
                            }
                            ForEach(sortedConsoles(), id: \.self) { console in
                                Divider()
                                    .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)
                                MenuItemView(icon: .named(console.iconName, PVUIBase.BundleLoader.myBundle), rowTitle: console.name, isFocused: focusedItem == console.identifier) {
                                    delegate.didTapConsole(with: console.identifier)
                                }
                                .focusableIfAvailable()
                                .focused($focusedItem, equals: console.identifier)
                            }
                        }
                        MenuSectionHeaderView(sectionTitle: "Provenance \(versionText())", sortable: false) {}
                        Spacer()
                    }
                }
            }
        }
#if canImport(Introspect)
        .introspectNavigationController(customize: { navController in

            if #available(iOS 17.0, tvOS 17.0, * ) {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = themeManager.currentPalette.menuHeaderBackground
                appearance.titleTextAttributes = [.foregroundColor: themeManager.currentPalette.menuHeaderText]
                appearance.largeTitleTextAttributes = [.foregroundColor: themeManager.currentPalette.menuHeaderText ]

                navController.navigationBar.standardAppearance = appearance
                navController.navigationBar.scrollEdgeAppearance = appearance
                navController.navigationBar.compactAppearance = appearance
            }

            navController.navigationBar.tintColor = themeManager.currentPalette.menuHeaderIconTint
        })
        .introspectViewController(customize: { vc in
            let image = UIImage(named: "provnavicon")
            let menuHeaderIconTint = themeManager.currentPalette.menuHeaderIconTint

            if menuHeaderIconTint != .clear {
                    image?.applyTintEffectWithColor(menuHeaderIconTint)
            }
            let provenanceLogo = UIBarButtonItem(image: image)
            provenanceLogo.tintColor = themeManager.currentPalette.menuHeaderIconTint
            vc.navigationItem.leftBarButtonItem = provenanceLogo
            vc.navigationItem.leftBarButtonItem?.tintColor = menuHeaderIconTint
        })
#endif
        .background(themeManager.currentPalette.menuBackground.swiftUIColor)
        .add(self.searchBar)
        // search results
        .if(!searchBar.text.isEmpty) { view in
            view.overlay(
                StatusBarProtectionWrapper {
                    ApplyBackgroundWrapper {
                        ScrollView {
                            VStack {
                                LazyVStack {
                                    ForEach(filteredSearchResults(), id: \.self) { game in
                                        GameItemView(game: game, viewType: .row) {
                                            Task.detached { @MainActor in
                                                await rootDelegate.root_load(game, sender: self, core: nil, saveState: nil)
                                            }
                                        }
                                        .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                                        GamesDividerView()
                                    }
                                }
                                .padding(.horizontal, 10)
                            }
                            .background(themeManager.currentPalette.menuBackground.swiftUIColor)
                        }
                    }
                }
            )
        }
        .onAppear {
            setupGamepadHandling()
        }
        .onDisappear {
            if let handler = gamepadHandler {
                NotificationCenter.default.removeObserver(handler)
            }
        }
        .task {
            // Set initial focus to home when menu appears
            focusedItem = "home"
        }
        .onChange(of: focusedItem) { newValue in
            print("Focus changed from \(String(describing: lastFocusedItem)) to \(String(describing: newValue))")
            lastFocusedItem = newValue
        }
    }
}


#endif
