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

    @State private var continuousNavigationTask: Task<Void, Never>?

    @ObservedObject private var gamepadManager = GamepadManager.shared

    @State private var delayTask: Task<Void, Never>?

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
        let gitBranch = PackageBuild.info.branch ?? Bundle.main.infoDictionary?["GIT_BRANCH"] as? String ?? ""
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

    private func setupGamepadHandling(proxy: ScrollViewProxy? = nil) {
        // Cancel any existing subscriptions first
        gamepadCancellable?.cancel()

        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .filter { _ in
                print("viewModel.isMenuVisible: \(viewModel.isMenuVisible)")
                return viewModel.isMenuVisible
            }
            .sink { event in
                switch event {
                case .buttonPress(let isPressed):
                    if isPressed {
                        handleButtonPress()
                    }
                case .buttonB(let isPressed):
                    if isPressed {
                        delegate.closeMenu()
                    }
                case .verticalNavigation(let value, let isPressed):
                    if isPressed {
                        handleVerticalNavigation(value, proxy: proxy)
                    } else {
                        continuousNavigationTask?.cancel()
                    }
                default:
                    break
                }
            }
    }

    private func handleButtonPress() {
        guard let focusedItem = focusedItem else { return }
        print("Handling button press for item: \(focusedItem)")

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

    private func handleVerticalNavigation(_ value: Float, proxy: ScrollViewProxy? = nil) {
        let items = ["home", "settings", "imports"] + sortedConsoles().map(\.identifier)

        if let currentIndex = items.firstIndex(of: focusedItem ?? "") {
            let newIndex: Int
            if value > 0 { // Going up
                newIndex = currentIndex == 0 ? items.count - 1 : currentIndex - 1
            } else { // Going down
                newIndex = currentIndex == items.count - 1 ? 0 : currentIndex + 1
            }
            focusedItem = items[newIndex]

            // Force scroll to top for the first few items
            if newIndex <= 2 { // home, settings, imports
                withAnimation {
                    proxy?.scrollTo(menuNamespace, anchor: .top)
                }
            }
        } else {
            focusedItem = items.first
        }
    }

    private func startContinuousNavigation(value: Float, proxy: ScrollViewProxy? = nil) {
        continuousNavigationTask?.cancel()

        // Perform initial navigation
        handleVerticalNavigation(value, proxy: proxy)

        // Start continuous navigation
        continuousNavigationTask = Task { [self] in
            try? await Task.sleep(for: .milliseconds(500)) // Initial delay
            while !Task.isCancelled {
                self.handleVerticalNavigation(value, proxy: proxy)
                try? await Task.sleep(for: .milliseconds(150)) // Repeat delay
            }
        }
    }

    // MARK: - View Builders
    @ViewBuilder
    private func headerItems() -> some View {
        Group {
            Divider()
                .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)

            MenuItemView(icon: .named("prov_settings_gear", PVUIBase.BundleLoader.myBundle), rowTitle: "Settings", isFocused: focusedItem == "settings") {
                delegate.didTapSettings()
            }
            .focusableIfAvailable()
            .focused($focusedItem, equals: "settings")
        }
    }

    @ViewBuilder
    private func addGamesSection() -> some View {
        Group {
            Divider()
                .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)

            MenuItemView(icon: .named("prov_add_games_icon", PVUIBase.BundleLoader.myBundle), rowTitle: "Add Games", isFocused: focusedItem == "addgames") {
                delegate?.didTapAddGames()
            }
            .focusableIfAvailable()
            .focused($focusedItem, equals: "addgames")
            .id("addgames")
        }
    }

    @ViewBuilder
    private func importQueueSection() -> some View {
        Group {
            Divider()
                .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)

            MenuItemView(icon: .sfSymbol("checklist"), rowTitle: "Import Queue", isFocused: focusedItem == "imports") {
                delegate.didTapImports()
            }
            .focusableIfAvailable()
            .focused($focusedItem, equals: "imports")
        }
    }

    @ViewBuilder
    private func consolesSection() -> some View {
        Group {
            if consoles.count > 0 {
                MenuSectionHeaderView(sectionTitle: "CONSOLES", sortable: consoles.count > 1, sortAscending: viewModel.sortConsolesAscending) {
                    viewModel.sortConsolesAscending.toggle()
                }
                
                Divider()
                    .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)

                // Home first
                
                MenuItemView(icon: .named("prov_home_icon", PVUIBase.BundleLoader.myBundle), rowTitle: "Home", isFocused: focusedItem == "home") {
                    delegate.didTapHome()
                }
                .focusableIfAvailable()
                .focused($focusedItem, equals: "home")
                .id("home")
                
                ForEach(sortedConsoles(), id: \.self) { console in
                    Divider()
                        .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)
                    MenuItemView(icon: .named(console.iconName, PVUIBase.BundleLoader.myBundle), rowTitle: console.name, isFocused: focusedItem == console.identifier) {
                        delegate.didTapConsole(with: console.identifier)
                    }
                    .focusableIfAvailable()
                    .focused($focusedItem, equals: console.identifier)
                    .id(console.identifier)
                }
            }
        }
    }

    @ViewBuilder
    private func footerSection() -> some View {
        Group {
            MenuSectionHeaderView(sectionTitle: "Provenance \(versionText())", sortable: false) {}
            Spacer()
        }
    }

    @ViewBuilder
    private func searchResultsList() -> some View {
        LazyVStack {
            ForEach(filteredSearchResults(), id: \.self) { game in
                GameItemView(
                    game: game,
                    constrainHeight: false,
                    viewType: .row,
                    sectionContext: .allGames,
                    isFocused: .constant(false) ,
                    action: {
                        Task.detached { @MainActor in
                            await rootDelegate.root_load(game, sender: self, core: nil, saveState: nil)
                        }
                    }
                )
                .contextMenu {
                    GameContextMenu(
                        game: game,
                        rootDelegate: rootDelegate,
                        contextMenuDelegate: nil
                    )
                }
                GamesDividerView()
            }
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Body
    public var body: some SwiftUI.View {
        StatusBarProtectionWrapper {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            headerItems()
                            addGamesSection()
                            importQueueSection()

                            #if canImport(FreemiumKit)
                            Divider()
                                .foregroundStyle(themeManager.currentPalette.menuDivider.swiftUIColor)
                            PaidStatusView(style: .plain)
                                .listRowBackground(Color.accentColor)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                            #endif

                            consolesSection()
                            footerSection()
                        }
                    }
                    .onChange(of: focusedItem) { newValue in
                        handleFocusChange(newValue, proxy: proxy)
                    }
                }
                .onAppear {
                    setupGamepadHandling(proxy: proxy)
                }
            }
        }
#if canImport(Introspect)
        .introspectNavigationController(customize: { navController in
#if !os(tvOS)
            if #available(iOS 17.0, tvOS 17.0, * ) {
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = themeManager.currentPalette.menuHeaderBackground
                appearance.titleTextAttributes = [.foregroundColor: themeManager.currentPalette.menuHeaderText]
                appearance.largeTitleTextAttributes = [.foregroundColor: themeManager.currentPalette.menuHeaderText ]

                navController.navigationBar.standardAppearance = appearance
                navController.navigationBar.scrollEdgeAppearance = appearance
                navController.navigationBar.compactAppearance = appearance
                navController.navigationBar.tintColor = themeManager.currentPalette.menuIconTint
            }
#endif

            navController.navigationBar.tintColor = themeManager.currentPalette.menuHeaderIconTint
        })
        .introspectViewController(customize: { vc in
            let image = UIImage(named: "provnavicon", in: PVUIBase.BundleLoader.myBundle, with: nil)
            let menuIconTint = themeManager.currentPalette.menuIconTint

            if menuIconTint != .clear {
                    image?.applyTintEffectWithColor(menuIconTint)
            }
            let provenanceLogo = UIBarButtonItem(image: image)
            provenanceLogo.tintColor = themeManager.currentPalette.menuIconTint
            vc.navigationItem.leftBarButtonItem = provenanceLogo
            vc.navigationItem.leftBarButtonItem?.tintColor = menuIconTint
            vc.navigationController?.navigationBar.tintColor = menuIconTint
        })
        .foregroundStyle(themeManager.currentPalette.menuIconTint.swiftUIColor)
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
                                searchResultsList()
                            }
                            .background(themeManager.currentPalette.menuBackground.swiftUIColor)
                        }
                    }
                }
            )
        }
        .onDisappear {
            delayTask?.cancel()
            continuousNavigationTask?.cancel()
            gamepadCancellable?.cancel()
        }
        .task {
            // Set initial focus to home when menu appears
            focusedItem = "home"
        }
        .onChange(of: gamepadManager.isControllerConnected) { isConnected in
            if isConnected {
                focusedItem = "home"
            }
        }
    }

    private func handleFocusChange(_ newValue: String?, proxy: ScrollViewProxy) {
        print("Focus changed from \(String(describing: lastFocusedItem)) to \(String(describing: newValue))")
        lastFocusedItem = newValue

        // Scroll to the focused item with animation
        if let focused = newValue {
            withAnimation {
                proxy.scrollTo(focused, anchor: .center)
            }
        }
    }
}


#endif
