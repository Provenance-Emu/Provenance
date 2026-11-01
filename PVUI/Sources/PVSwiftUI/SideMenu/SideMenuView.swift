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
import PVFeatureFlags
import Combine
import Defaults
import PVSettings
@_exported import PVUIBase

#if canImport(UIKit)
import UIKit
#endif
#if canImport(FreemiumKit)
import FreemiumKit
#endif

@available(iOS 14, tvOS 14, *)
public struct
SideMenuView: SwiftUI.View {

    private weak var delegate: PVMenuDelegate?

    @ObservedObject
    var viewModel: PVRootViewModel

    @ObservedObject private var drawerState: LibraryDrawerState

    private weak var rootDelegate: PVRootDelegate?
    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>

    @State private var showEmptySystems: Bool
    @ObservedResults(PVSystem.self) private var consoles: Results<PVSystem>

    @State private var searchText = ""

    @ObservedObject private var themeManager = ThemeManager.shared

#if canImport(FreemiumKit)
    @State var showPaywall: Bool = false
    @EnvironmentObject var freemiumKit: FreemiumKit
#endif


    @FocusState private var focusedItem: String?

    @Namespace private var menuNamespace


    @State private var gamepadCancellable: AnyCancellable?



    @ObservedObject private var featureFlags = PVFeatureFlagsManager.shared

    @State private var showNearbyLibraries = false

    /// Focus id of the Nearby Libraries row (gamepad navigation).
    private static let nearbyItem = "nearby"

    /// Nearby Libraries lives in Settings too; the library gets its own row so
    /// shared libraries on this network are one tap away.
    private var showsNearbyLibraries: Bool {
        #if os(iOS) || os(tvOS)
        return featureFlags.nearbyLibraries
        #else
        return false
        #endif
    }


    /// The library's netplay lobby (rooms nearby, host a game).
    @State private var showNetplayLobby = false
    @Default(.netplayEnabled) private var netplayEnabled

    public init(gameLibrary: PVGameLibrary<RealmDatabaseDriver>, viewModel: PVRootViewModel, delegate: PVMenuDelegate, rootDelegate: PVRootDelegate) {
        self.gameLibrary = gameLibrary
        self.viewModel = viewModel
        self.drawerState = viewModel.drawerState
        self.delegate = delegate
        self.rootDelegate = rootDelegate

        #if targetEnvironment(simulator)
        _showEmptySystems = State(initialValue: ProcessInfo.processInfo.arguments.contains("-PVShowEmptySystems"))
        #else
        _showEmptySystems = State(initialValue: false)
        #endif

        // Set the filter for consoles based on showEmptySystems
        let filter = showEmptySystems ? nil : NSPredicate(format: "games.@count > 0")
        _consoles = ObservedResults(PVSystem.self, filter: filter)

    }

    func versionText() -> String {
        AppVersionLabel.current
    }

    func sortedConsoles() -> Results<PVSystem> {
        return self.consoles.sorted(by: [SortDescriptor(keyPath: #keyPath(PVSystem.name), ascending: viewModel.sortConsolesAscending)])
    }

    func filteredSearchResults() -> Results<PVGame> {
        return self.gameLibrary.searchResults(for: searchText)
    }

    private func setupGamepadHandling(proxy: ScrollViewProxy? = nil) {
        // Cancel any existing subscriptions first
        gamepadCancellable?.cancel()

        gamepadCancellable = GamepadManager.shared.eventPublisher
            .receive(on: DispatchQueue.main)
            .filter { _ in
                // The Nearby Libraries sheet owns the controller while it is up.
                return viewModel.isMenuVisible && !showNearbyLibraries && !showNetplayLobby
            }
            .sink { event in
                // Suppress while a full-screen retrowave alert is on top.
                if GamepadManager.shared.isModalAlertPresented { return }
                switch event {
                case .buttonPress(let isPressed):
                    if isPressed {
                        handleButtonPress()
                    }
                case .buttonB(let isPressed):
                    if isPressed {
                        delegate?.closeMenu()
                    }
                case .verticalNavigation(let value, let isPressed):
                    if isPressed {
                        handleVerticalNavigation(value, proxy: proxy)
                    }
                default:
                    break
                }
            }
    }

    private func handleButtonPress() {
        guard let focusedItem = focusedItem else { return }

        switch focusedItem {
        case "home":
            delegate?.didTapHome()
        case "favorites", "recentlyPlayed":
            delegate?.didTapHome()
            viewModel.libraryDestination = focusedItem == "favorites" ? .favorites : .recentlyPlayed
        case "settings":
            delegate?.didTapSettings()
        case "imports":
            delegate?.didTapImports()
        case "addgames":
            delegate?.didTapAddGames()
        case Self.nearbyItem:
            showNearbyLibraries = true
        case "netplay":
            showNetplayLobby = true
        default:
            // Handle console selection
            delegate?.didTapConsole(with: focusedItem)
        }
    }

    private func handleVerticalNavigation(_ value: Float, proxy: ScrollViewProxy? = nil) {
        var fixedItems = ["settings", "addgames", "imports"]
        if showsNearbyLibraries {
            fixedItems.append(Self.nearbyItem)
        }
        if netplayEnabled {
            fixedItems.append("netplay")
        }
        if !consoles.isEmpty { fixedItems.append(contentsOf: ["home", "favorites", "recentlyPlayed"]) }
        let items = fixedItems + sortedConsoles().map(\.identifier)

        if let currentIndex = items.firstIndex(of: focusedItem ?? "") {
            let newIndex: Int
            if value > 0 { // Going up
                newIndex = currentIndex == 0 ? items.count - 1 : currentIndex - 1
            } else { // Going down
                newIndex = currentIndex == items.count - 1 ? 0 : currentIndex + 1
            }
            focusedItem = items[newIndex]

            // Force scroll to top for the first few items
            if newIndex < fixedItems.count {
                withAnimation {
                    proxy?.scrollTo(menuNamespace, anchor: .top)
                }
            }
        } else {
            focusedItem = items.first
        }
    }

    // MARK: - View Builders
    @ViewBuilder
    private func headerItems() -> some View {
        MenuItemView(icon: .named("prov_settings_gear", PVUIBase.BundleLoader.myBundle), rowTitle: "Settings", isFocused: focusedItem == "settings") {
            delegate?.didTapSettings()
        }
        .focusable()
        .focused($focusedItem, equals: "settings")
    }

    @ViewBuilder
    private func addGamesSection() -> some View {
        Group {
            Rectangle()
                .fill(Color.retroCyan.opacity(0.15))
                .frame(height: 1)

            MenuItemView(icon: .named("prov_add_games_icon", PVUIBase.BundleLoader.myBundle), rowTitle: "Add Games", isFocused: focusedItem == "addgames") {
                delegate?.didTapAddGames()
            }
            .focusable()
            .focused($focusedItem, equals: "addgames")
            .id("addgames")
        }
    }

    @ViewBuilder
    private func importQueueSection() -> some View {
        Group {
            Rectangle()
                .fill(Color.retroCyan.opacity(0.15))
                .frame(height: 1)

            MenuItemView(icon: .sfSymbol("checklist"), rowTitle: "Import Queue", isFocused: focusedItem == "imports") {
                delegate?.didTapImports()
            }
            .focusable()
            .focused($focusedItem, equals: "imports")
        }
    }

    @ViewBuilder
    private func nearbyLibrariesSection() -> some View {
        if showsNearbyLibraries {
            Group {
                Rectangle()
                    .fill(Color.retroCyan.opacity(0.15))
                    .frame(height: 1)

                MenuItemView(icon: .sfSymbol("antenna.radiowaves.left.and.right"), rowTitle: "Nearby Libraries",
                             isFocused: focusedItem == Self.nearbyItem) {
                    showNearbyLibraries = true
                }
                .focusable()
                .focused($focusedItem, equals: Self.nearbyItem)
            }
        }
    }

    @ViewBuilder
    private func networkPlaySection() -> some View {
        if netplayEnabled {
            Rectangle()
                .fill(Color.retroCyan.opacity(0.15))
                .frame(height: 1)

            MenuItemView(icon: .sfSymbol("network"), rowTitle: "Network Play", isFocused: focusedItem == "netplay") {
                showNetplayLobby = true
            }
            .focusable()
            .focused($focusedItem, equals: "netplay")
        }
    }

    @ViewBuilder
    private func consolesSection() -> some View {
        Group {
            if !consoles.isEmpty {
                MenuSectionHeaderView(sectionTitle: "CONSOLES", sortable: consoles.count > 1, sortAscending: viewModel.sortConsolesAscending) {
                    viewModel.sortConsolesAscending.toggle()
                }

                Rectangle()
                    .fill(Color.retroCyan.opacity(0.15))
                    .frame(height: 1)

                // Home first

                MenuItemView(icon: .named("prov_home_icon", PVUIBase.BundleLoader.myBundle), rowTitle: "Home", isFocused: focusedItem == "home", isActive: viewModel.selectedConsole == nil && viewModel.libraryDestination == .home) {
                    delegate?.didTapHome()
                }
                .focusable()
                .focused($focusedItem, equals: "home")
                .id("home")
                ForEach([LibraryDestination.favorites, .recentlyPlayed]) { destination in
                    MenuItemView(icon: .sfSymbol(destination.symbol), rowTitle: destination.title,
                                 isFocused: focusedItem == destination.rawValue,
                                 isActive: viewModel.selectedConsole == nil && viewModel.libraryDestination == destination) {
                        delegate?.didTapHome()
                        viewModel.libraryDestination = destination
                    }
                    .focusable()
                    .focused($focusedItem, equals: destination.rawValue)
                }

                ForEach(sortedConsoles(), id: \.identifier) { console in
                    Rectangle()
                        .fill(Color.retroCyan.opacity(0.15))
                        .frame(height: 1)
                    MenuItemView(
                        icon: .named(console.iconName, PVUIBase.BundleLoader.myBundle),
                        rowTitle: console.name,
                        isFocused: focusedItem == console.identifier,
                        isActive: viewModel.selectedConsole?.identifier == console.identifier
                    ) {
                        delegate?.didTapConsole(with: console.identifier)
                    }
                    .focusable()
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
        let results = filteredSearchResults()
        if results.isEmpty {
            ContentUnavailableView.search(text: searchText)
                .foregroundStyle(themeManager.currentPalette.dark ? Color.white : Color.black)
                .padding(.vertical, 24)
        }
        LazyVStack {
            ForEach(results, id: \.md5Hash) { game in
                GameItemView(
                    game: game,
                    constrainHeight: false,
                    viewType: .row,
                    sectionContext: .allGames,
                    isFocused: .constant(false),
                    action: {
                        Task.detached { @MainActor in
                            SceneCoordinator.shared.launchGame(game.freeze())
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
        VStack(spacing: 0) {
            HStack {
                Image("provnavicon", bundle: PVUIBase.BundleLoader.myBundle)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(themeManager.currentPalette.menuHeaderIconTint.swiftUIColor)
                    .frame(maxWidth: 180, maxHeight: 36)
                    .accessibilityLabel("Provenance")
                Spacer(minLength: 8)
                Button {
                    delegate?.closeMenu()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Library Menu")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(themeManager.currentPalette.menuHeaderBackground.swiftUIColor)

            LibraryMenuSearchField(
                text: $searchText,
                accent: themeManager.currentPalette.menuIconTint.swiftUIColor,
                background: themeManager.currentPalette.menuBackground.swiftUIColor,
                foreground: themeManager.currentPalette.dark ? .white : .black,
                isMenuVisible: drawerState.isPresented
            )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(themeManager.currentPalette.menuHeaderBackground.swiftUIColor)

            ScrollViewReader { proxy in
                ScrollView {
                    if searchText.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            headerItems()
                                .id(menuNamespace)
                            addGamesSection()
                            importQueueSection()
                            nearbyLibrariesSection()
                            networkPlaySection()
                            #if canImport(FreemiumKit)
                            PaidStatusView(style: .plain)
                                .freemiumKitColorReset()
                                .padding(10)
                            #endif
                            consolesSection()
                            footerSection()
                        }
                    } else {
                        searchResultsList()
                    }
                }
                .onChange(of: focusedItem) { _, newValue in
                    handleFocusChange(newValue, proxy: proxy)
                }
                .onAppear { setupGamepadHandling(proxy: proxy) }
                .onChange(of: drawerState.isPresented) { _, visible in
                    if visible {
                        focusedItem = consoles.isEmpty ? "settings" : (viewModel.selectedConsole?.identifier ?? "home")
                    } else {
                        focusedItem = nil
                    }
                }
            }
        }
        .foregroundStyle(themeManager.currentPalette.menuIconTint.swiftUIColor)
        .background(themeManager.currentPalette.menuBackground.swiftUIColor)
        #if os(iOS) || os(tvOS)
        .sheet(isPresented: $showNearbyLibraries) { NearbyLibrariesSheet() }
        #endif
        .sheet(isPresented: $showNetplayLobby) { NetplayLibraryLobbyView() }
        .onDisappear {
            gamepadCancellable?.cancel()
        }
    }

    private func handleFocusChange(_ newValue: String?, proxy: ScrollViewProxy) {

        // Scroll to the focused item with animation
        if let focused = newValue {
            withAnimation {
                if focused == "home" || focused == "settings" {
                    proxy.scrollTo(menuNamespace, anchor: .top)
                } else {
                    proxy.scrollTo(focused, anchor: .center)
                }
            }
        }
    }
}

private struct LibraryMenuSearchField: View {
    @Binding var text: String
    let accent: Color
    let background: Color
    let foreground: Color
    let isMenuVisible: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(accent)
                .accessibilityHidden(true)
            TextField("Search Games", text: $text, prompt: Text("Search Games").foregroundStyle(foreground.opacity(0.6)))
                .focused($isFocused)
                .textFieldStyle(.plain)
                .foregroundStyle(foreground)
                .submitLabel(.search)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(foreground.opacity(0.65))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Search")
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(accent.opacity(0.4), lineWidth: 1)
        }
        .onChange(of: isMenuVisible) { _, visible in
            if !visible { isFocused = false }
        }
    }
}

#endif
