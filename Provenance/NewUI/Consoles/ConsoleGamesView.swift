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
    }
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    var body: some SwiftUI.View {
        ScrollView {
            // TODO: sort options view. This includes replacing the grid with a list
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(filteredAndSortedGames(), id: \.self) { game in
                    GameItemView(
                        artwork: nil,
                        artworkType: console.gameArtworkType,
                        name: game.title,
                        yearReleased: game.publishDate) {
                            rootDelegate?.load(game, sender: self, core: nil, saveState: nil)
                        }
                        .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                }
            }
            .padding(.horizontal, 10)
            // TODO: bios if applicable
        }
        .background(Color.black)
    }
}

//@available(iOS 14, tvOS 14, *)
//struct HomeView_Previews: PreviewProvider {
//    static var previews: some SwiftUI.View {
//        HomeView()
//    }
//}

#endif
