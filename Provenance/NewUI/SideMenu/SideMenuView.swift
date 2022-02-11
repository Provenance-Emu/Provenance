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
import Introspect

@available(iOS 14, tvOS 14, *)
struct SideMenuView: SwiftUI.View {
    
    var delegate: PVMenuDelegate?
    var rootDelegate: PVRootDelegate
    var gameLibrary: PVGameLibrary
    
    @ObservedResults(
        PVSystem.self,
        configuration: RealmConfiguration.realmConfig,
        filter: NSPredicate(format: "games.@count > 0")
    ) var consoles
    
    @State var sortAscending = true
    
    @ObservedObject var searchBar: SearchBar = SearchBar()
    
    init(gameLibrary: PVGameLibrary, delegate: PVMenuDelegate, rootDelegate: PVRootDelegate) {
        self.gameLibrary = gameLibrary
        self.delegate = delegate
        self.rootDelegate = rootDelegate
    }
    
    static func instantiate(gameLibrary: PVGameLibrary, delegate: PVMenuDelegate, rootDelegate: PVRootDelegate) -> UIViewController {
        let view = SideMenuView(gameLibrary: gameLibrary, delegate: delegate, rootDelegate: rootDelegate)
        let hostingView = UIHostingController(rootView: view)
        let nav = UINavigationController(rootViewController: hostingView)
        return nav
    }
    
    func versionText() -> String {
        let masterBranch: Bool = kGITBranch.lowercased() == "master"
        var versionText = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        versionText = versionText ?? "" + (" (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? ""))")
        if !masterBranch {
            versionText = "\(versionText ?? "") Beta"
        }
        return versionText ?? ""
    }
    
    func sortedConsoles() -> Results<PVSystem> {
        return self.consoles.sorted(by: [SortDescriptor(keyPath: #keyPath(PVSystem.name), ascending: sortAscending)])
    }
    
    func filteredSearchResults() -> Results<PVGame> {
        return self.gameLibrary.searchResults(for: self.searchBar.text)
    }
    
    var body: some SwiftUI.View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Group {
                    MenuItemView(imageName: "prov_settings_gear", rowTitle: "Settings") {
                        delegate?.didTapSettings()
                    }
                    Divider()
                    MenuItemView(imageName: "prov_home_icon", rowTitle: "Home") {
                        delegate?.didTapHome()
                    }
                    Divider()
                    MenuItemView(imageName: "prov_add_games_icon", rowTitle: "Add Games") {
                        delegate?.didTapAddGames()
                    }
                }
                Group {
                    if consoles.count > 0 {
                        MenuSectionHeaderView(sectionTitle: "CONSOLES", sortable: consoles.count > 1, sortAscending: sortAscending) {
                            self.sortAscending.toggle()
                        }
                        ForEach(sortedConsoles(), id: \.self) { console in
                            Divider()
                            MenuItemView(imageName: "prov_snes_icon", rowTitle: console.name) {
                                delegate?.didTapConsole(with: console.identifier)
                            }
                        }
                    }
                }
                // TODO: flesh out collections later
                Group {
                    MenuSectionHeaderView(sectionTitle: "Provenance \(versionText())", sortable: false) {}
                }
                Spacer()
            }
        }
        .introspectViewController(customize: { vc in
            vc.navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(named: "provnavicon"))
        })
        .background(Color.black)
        .add(self.searchBar)
        // search results
        .if(!searchBar.text.isEmpty) { view in
            view.overlay(
                ApplyBackgroundWrapper {
                    ScrollView {
                        VStack {
                            LazyVStack {
                                ForEach(filteredSearchResults(), id: \.self) { game in
                                    GameItemView(game: game, viewType: .row) {
                                        rootDelegate.root_load(game, sender: self, core: nil, saveState: nil)
                                    }
                                    .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                                    GamesDividerView()
                                }
                            }
                            .padding(.horizontal, 10)
                        }
                        .background(Color.black)
                    }
                }
            )
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct MenuSectionHeaderView: SwiftUI.View {
    
    var sectionTitle: String
    var sortable: Bool
    var sortAscending: Bool = false
    var action: () -> Void
    
    var body: some SwiftUI.View {
        VStack(spacing: 0) {
            Divider().frame(height: 2).background(Color.gray)
            Spacer()
            HStack(alignment: .bottom) {
                Text(sectionTitle).foregroundColor(Color.gray).font(.system(size: 13))
                Spacer()
                if sortable {
                    OptionsIndicator(pointDown: sortAscending, action: action) {
                        Text("Sort").foregroundColor(Color.gray).font(.system(.caption))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .frame(height: 40.0)
        .background(Color.black)
    }
}

@available(iOS 14, tvOS 14, *)
struct MenuItemView: SwiftUI.View {
    
    var imageName: String
    var rowTitle: String
    var action: () -> Void
    
    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 0) {
                Image(imageName).resizable().scaledToFit().cornerRadius(4).padding(8)
                Text(rowTitle).foregroundColor(Color.white)
                Spacer()
            }
            .frame(height: 40.0)
            .background(Color.black)
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct ApplyBackgroundWrapper<Content: SwiftUI.View>: SwiftUI.View {
    @ViewBuilder var content: () -> Content
    var body: some SwiftUI.View {
        if #available(iOS 15, tvOS 15, *) {
            content().background(Material.ultraThinMaterial)
        } else {
            content().background(Color.black)
        }
    }
}

#endif
