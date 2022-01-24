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
    
    var gameLaunchDelegate: GameLaunchingViewController?
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    @State var games: Results<PVGame>
    
    init(gameLibrary: PVGameLibrary, console: PVSystem, delegate: GameLaunchingViewController) {
        self.console = console
        self.gameLaunchDelegate = delegate
        games = gameLibrary.gamesForSystem(systemIdentifier: self.console.identifier)
    }
    
    var body: some SwiftUI.View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(games, id: \.self) { game in
                    GameItemView(
                        artwork: nil,
                        name: game.title,
                        yearReleased: game.publishDate) {
                            gameLaunchDelegate?.load(game, sender: self, core: nil, saveState: nil)
                        }
                    // TODO: add context menu instead of button
                }
            }
            .padding(.horizontal, 10)
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
