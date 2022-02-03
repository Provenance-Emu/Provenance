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

@available(iOS 14, tvOS 14, *)
struct ConsoleGamesView: SwiftUI.View {
    
    @ObservedRealmObject var console: PVSystem
    
    var rootDelegate: PVRootDelegate?
    
    @ObservedResults(
        PVGame.self,
        configuration: RealmConfiguration.realmConfig,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var games
    
    init(gameLibrary: PVGameLibrary, console: PVSystem, rootDelegate: PVRootDelegate) {
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
                // TODO: look into why there is inconsistent spacing between display options and games depending on console
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(filteredAndSortedGames(), id: \.self) { game in
                        GameItemView(
                            artwork: nil,
                            boxartAspectRatio: game.boxartAspectRatio,
                            name: game.title,
                            yearReleased: game.publishDate) {
                                rootDelegate?.load(game, sender: self, core: nil, saveState: nil)
                            }
                            .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                    }
                }
                .padding(.horizontal, 10)
            } else {
                LazyVStack { // TODO: convert to row
                    ForEach(filteredAndSortedGames(), id: \.self) { game in
                        GameItemView(
                            artwork: nil,
                            boxartAspectRatio: game.boxartAspectRatio,
                            name: game.title,
                            yearReleased: game.publishDate) {
                                rootDelegate?.load(game, sender: self, core: nil, saveState: nil)
                            }
                            .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
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
struct GamesDisplayOptionsView: SwiftUI.View {
    
    var sortAscending = true
    var isGrid = true
    
    var toggleSortAction: () -> Void
    var toggleViewTypeAction: () -> Void
    
    var body: some SwiftUI.View {
        HStack(alignment: .bottom, spacing: 10) {
            Spacer()
            Button {
                // TODO: this, should be a menu w/ filter options
            } label: {
                HStack(alignment: .bottom, spacing: 0) {
                    Text("Filter").foregroundColor(Color.gray).font(.system(size: 12))
                    OptionsIndicator(pointDown: true)
                }
            }
            Button {
                toggleSortAction()
            } label: {
                HStack(alignment: .bottom, spacing: 0) {
                    Text("Sort").foregroundColor(Color.gray).font(.system(size: 13))
                    OptionsIndicator(pointDown: sortAscending)
                }
            }
            Button {
                toggleViewTypeAction()
            } label: {
                HStack(alignment: .bottom, spacing: 0) {
                    Image(systemName: isGrid == true ? "square.grid.3x3.fill" : "line.3.horizontal.circle.fill").foregroundColor(Color.gray).font(.system(.caption))
                    OptionsIndicator(pointDown: true)
                }
            }
            .padding(.trailing, 10)
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct OptionsIndicator: SwiftUI.View {
    
    var pointDown: Bool = true
    var size: CGFloat = 16.0
    
    var body: some SwiftUI.View {
        Image(pointDown == true ? "chevron_down" : "chevron_up").resizable().foregroundColor(.gray).frame(width: size, height: size)
    }
}

//@available(iOS 14, tvOS 14, *)
//struct HomeView_Previews: PreviewProvider {
//    static var previews: some SwiftUI.View {
//        HomeView()
//    }
//}

#endif
