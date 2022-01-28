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

@available(iOS 14.0.0, *)
struct ConsoleGamesView: SwiftUI.View {
    
    var console: PVSystem!
    
    var rootDelegate: PVRootDelegate?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    @State var games: Results<PVGame>
    
    init(gameLibrary: PVGameLibrary, console: PVSystem, rootDelegate: PVRootDelegate) {
        self.console = console
        self.rootDelegate = rootDelegate
        self.games = gameLibrary.gamesForSystem(systemIdentifier: self.console.identifier)
    }
    
    var body: some SwiftUI.View {
        ScrollView {
            // TODO: sort options view. This includes replacing the grid with a list
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(games, id: \.self) { game in
                    GameItemView(
                        artwork: nil,
                        artworkType: console.gameArtworkType,
                        name: game.title,
                        yearReleased: game.publishDate) {
                            rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
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

//@available(iOS 14.0.0, *)
//struct HomeView_Previews: PreviewProvider {
//    static var previews: some SwiftUI.View {
//        HomeView()
//    }
//}

#endif
