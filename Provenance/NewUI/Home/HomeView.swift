//
//  HomeView.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#if canImport(SwiftUI)
import Foundation
import SwiftUI
import RealmSwift

enum PVHomeSection: Int, CaseIterable {
    case recentSaveStates
    case recentlyPlayedGames
    case favorites
    case mostPlayed
}

@available(iOS 14.0.0, *)
struct HomeView: SwiftUI.View {
    
    var gameLibrary: PVGameLibrary!
    
    var gameLaunchDelegate: GameLaunchingViewController?
    
    @State var recentSaveStates: Results<PVSaveState>?
    @State var recentlyPlayedGames: Results<PVRecentGame>?
    @State var favorites: Results<PVGame>?
    @State var mostPlayed: Results<PVGame>?
    
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
    
    
    init(gameLibrary: PVGameLibrary, delegate: GameLaunchingViewController) {
        self.gameLibrary = gameLibrary
        self.gameLaunchDelegate = delegate
        
        self.recentSaveStates = self.gameLibrary.saveStatesResults
        self.recentlyPlayedGames = self.gameLibrary.recentsResults
        self.favorites = self.gameLibrary.favoritesResults
        self.mostPlayed = self.gameLibrary.mostPlayedResults
    }
    
    
    var body: some SwiftUI.View {
        ScrollView {
            VStack {
                if let recentSaveStates = recentSaveStates {
                    HStack {
                        ForEach(recentSaveStates, id: \.self) { recentSaveState in
                            GameItemView(
                                artwork: nil,
                                name: recentSaveState.game.title,
                                yearReleased: recentSaveState.game.publishDate) {
                                    gameLaunchDelegate?.load(recentSaveState.game, sender: self, core: nil, saveState: recentSaveState)
                                }
                        }
                    }
                }
                if let recentlyPlayedGames = recentlyPlayedGames {
                    HStack {
                        ForEach(recentlyPlayedGames, id: \.self) { recentlyPlayedGame in
                            GameItemView(
                                artwork: nil,
                                name: recentlyPlayedGame.game.title,
                                yearReleased: recentlyPlayedGame.game.publishDate) {
                                    gameLaunchDelegate?.load(recentlyPlayedGame.game, sender: self, core: nil, saveState: nil)
                                }
                        }
                    }
                }
                if let favorites = favorites {
                    HStack {
                        ForEach(favorites, id: \.self) { favorite in
                            GameItemView(
                                artwork: nil,
                                name: favorite.title,
                                yearReleased: favorite.publishDate) {
                                    gameLaunchDelegate?.load(favorite, sender: self, core: nil, saveState: nil)
                                }
                        }
                    }
                }
                if let mostPlayed = mostPlayed {
                    HStack {
                        ForEach(mostPlayed, id: \.self) { playedGame in
                            GameItemView(
                                artwork: nil,
                                name: playedGame.title,
                                yearReleased: playedGame.publishDate) {
                                    gameLaunchDelegate?.load(playedGame, sender: self, core: nil, saveState: nil)
                                }
                        }
                    }
                }
                
            }
        }
        .background(Color.black)
    }
}


@available(iOS 14.0.0, *)
struct HomeItemView: SwiftUI.View {
    
    var imageName: String
    var rowTitle: String
    
    var body: some SwiftUI.View {
        HStack(spacing: 0) {
            Image(imageName).resizable().scaledToFit().cornerRadius(4).padding(8)
            Text(rowTitle).foregroundColor(Color.white)
            Spacer()
        }
        .frame(height: 40.0)
        .background(Color.black)
    }
}

#endif