//
//  ConsoleGamesView.swift
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

// TODO: might be able to reuse this view for collections.
@available(iOS 14, tvOS 14, *)
struct ConsoleGamesView: SwiftUI.View {
    
//    @ObservedRealmObject var console: PVSystem
    var console: PVSystem
    
    var rootDelegate: PVRootDelegate?
    
    @ObservedResults(
        PVGame.self,
        configuration: RealmConfiguration.realmConfig,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var games
    
    init(console: PVSystem, rootDelegate: PVRootDelegate) {
        self.console = console
        self.rootDelegate = rootDelegate
    }
    
    func filteredAndSortedGames() -> Results<PVGame> {
        return games
            .filter(NSPredicate(format: "systemIdentifier == %@", argumentArray: [console.identifier]))
            .sorted(by: [SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: sortAscending)])
    }
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    @State var sortAscending = true // TODO: this will likely be a keypath on a game attribute, not just on title
    @State var isGrid = true
    
    var body: some SwiftUI.View {
        ScrollView {
            GamesDisplayOptionsView(
                sortAscending: sortAscending,
                isGrid: isGrid,
                toggleSortAction: { sortAscending.toggle() },
                toggleViewTypeAction: { isGrid.toggle() })
                .padding(.top, 16)
            if isGrid {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(filteredAndSortedGames(), id: \.self) { game in
                        GameItemView(game: game) {
                            rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                        }
                        .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                    }
                }
                .padding(.horizontal, 10)
            } else {
                LazyVStack {
                    ForEach(filteredAndSortedGames(), id: \.self) { game in
                        GameItemView(game: game, viewType: .row) {
                            rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                        }
                        .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                        GamesDividerView()
                    }
                }
                .padding(.horizontal, 10)
            }
            // TODO: bios if applicable
        }
        .background(Color.black)
    }
}

@available(iOS 14, tvOS 14, *)
struct GamesDividerView: SwiftUI.View {
    var body: some SwiftUI.View {
        Divider()
            .frame(height: 1)
            .background(Color.gray)
            .opacity(0.1)
    }
}

@available(iOS 14, tvOS 14, *)
struct GamesDisplayOptionsView: SwiftUI.View {
    
    var sortAscending = true
    var isGrid = true
    
    var toggleSortAction: () -> Void
    var toggleViewTypeAction: () -> Void
    
    var body: some SwiftUI.View {
        HStack(spacing: 12) {
            Spacer()
            OptionsIndicator(pointDown: true, action: { /* TODO: this */ }) {
                Text("Filter").foregroundColor(Color.gray).font(.system(size: 12))
            }
            OptionsIndicator(pointDown: sortAscending, action: { toggleSortAction() }) {
                Text("Sort").foregroundColor(Color.gray).font(.system(size: 13))
            }
            OptionsIndicator(pointDown: true, action: { toggleViewTypeAction() }) {
                Image(systemName: isGrid == true ? "square.grid.3x3.fill" : "line.3.horizontal")
                    .foregroundColor(Color.gray)
                    .font(.system(size: 13, weight: .light))
            }
            .padding(.trailing, 10)
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct OptionsIndicator<Content: SwiftUI.View>: SwiftUI.View {
    
    var pointDown: Bool = true
    var chevronSize: CGFloat = 12.0
    
    var action: () -> Void
    
    @ViewBuilder var label: () -> Content
    
    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            HStack(spacing: 3) {
                label()
                Image(systemName: pointDown == true ? "chevron.down" : "chevron.up")
                    .foregroundColor(.gray)
                    .font(.system(size: chevronSize, weight: .ultraLight))
            }
        }
    }
}

//@available(iOS 14, tvOS 14, *)
//struct HomeView_Previews: PreviewProvider {
//    static var previews: some SwiftUI.View {
//        HomeView()
//    }
//}

#endif
