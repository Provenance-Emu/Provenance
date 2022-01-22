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

@available(iOS 13.0.0, *)
struct ConsoleGamesView: View {
    
    var console: PVSystem!
    
    var gameLaunchDelegate: GameLaunchingViewController?
    
    @State var games: Results<PVGame>
    
//    collectionView.rx.itemSelected
//        .map { indexPath in (try! collectionView.rx.model(at: indexPath) as Section.Item, collectionView.cellForItem(at: indexPath)) }
//        .compactMap({ item, cell -> Playable? in
//            switch item {
//            case .game(let game):
//                return (game, cell, nil, nil)
//            case .saves, .favorites, .recents:
//                // Handled in another place libVC.load(self.saveState!.game, sender: sender, core: nil, saveState: saveState)
//                return nil
//            }
//        })
//        .bind(to: selectedPlayable)
//        .disposed(by: disposeBag)
//
//    selectedPlayable.bind(onNext: self.load).disposed(by: disposeBag)
    
    
    init(gameLibrary: PVGameLibrary, console: PVSystem, delegate: GameLaunchingViewController) {
        self.console = console
        self.gameLaunchDelegate = delegate
        games = gameLibrary.gamesForSystem(systemIdentifier: self.console.identifier)
    }
    
    
    var body: some View {
        ScrollView {
            VStack {
                ForEach(games, id: \.self) { game in
                    DynamicWidthGameItemView(
                        artwork: nil,
                        name: game.title,
                        yearReleased: game.publishDate) {
                            gameLaunchDelegate?.load(game, sender: self, core: nil, saveState: nil)
                        }
                }
            }
        }
        .background(Color.black)
    }
}

//@available(iOS 13.0.0, *)
//struct HomeView_Previews: PreviewProvider {
//    static var previews: some View {
//        HomeView()
//    }
//}

#endif
