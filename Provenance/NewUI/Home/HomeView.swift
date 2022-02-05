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
import PVLibrary

enum PVHomeSection: Int, CaseIterable {
    case recentSaveStates
    case recentlyPlayedGames
    case favorites
    case mostPlayed
}

@available(iOS 14, tvOS 14, *)
struct HomeView: SwiftUI.View {
    
    var gameLibrary: PVGameLibrary!
    
    var rootDelegate: PVRootDelegate?
    
    @ObservedResults(
        PVSaveState.self,
        configuration: RealmConfiguration.realmConfig,
        filter: NSPredicate(format: "game != nil && game.system != nil")
    ) var recentSaveStates
    
    @ObservedResults(
        PVRecentGame.self,
        configuration: RealmConfiguration.realmConfig,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
    ) var recentlyPlayedGames
    
    @ObservedResults(
        PVGame.self,
        configuration: RealmConfiguration.realmConfig,
        filter: NSPredicate(format: "\(#keyPath(PVGame.isFavorite)) == %@", NSNumber(value: true)),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var favorites
    
    @ObservedResults(
        PVGame.self,
        configuration: RealmConfiguration.realmConfig,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false)
    ) var mostPlayed
    
    init(gameLibrary: PVGameLibrary, delegate: PVRootDelegate) {
        self.gameLibrary = gameLibrary
        self.rootDelegate = delegate
    }
    
    var body: some SwiftUI.View {
        ScrollView {
            LazyVStack {
                HomeSection(title: "Continue") {
                    ForEach(recentSaveStates, id: \.self) { recentSaveState in
                        GameItemView(game: recentSaveState.game, constrainHeight: true) {
                            rootDelegate?.root_load(recentSaveState.game, sender: self, core: nil, saveState: recentSaveState)
                        }
                    }
                }
                HomeSection(title: "Recently Played") {
                    ForEach(recentlyPlayedGames, id: \.self) { recentlyPlayedGame in
                        GameItemView(game: recentlyPlayedGame.game, constrainHeight: true) {
                            rootDelegate?.root_load(recentlyPlayedGame.game, sender: self, core: nil, saveState: nil)
                        }
                    }
                }
                HomeSection(title: "Favorites") {
                    ForEach(favorites, id: \.self) { favorite in
                        GameItemView(game: favorite, constrainHeight: true) {
                            rootDelegate?.root_load(favorite, sender: self, core: nil, saveState: nil)
                        }
                    }
                }
                HomeSection(title: "Most Played") {
                    ForEach(mostPlayed, id: \.self) { playedGame in
                        GameItemView(game: playedGame, constrainHeight: true) {
                            rootDelegate?.root_load(playedGame, sender: self, core: nil, saveState: nil)
                        }
                    }
                }
            }
        }
        .background(Color.black)
    }
}

@available(iOS 14, tvOS 14, *)
struct HomeSection<Content: SwiftUI.View>: SwiftUI.View {
    
    let title: String
    
    @ViewBuilder var content: () -> Content
    
    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .frame(height: 1)
                .background(Color.gray)
                .opacity(0.1)
                .padding(.horizontal, 10)
            Text(title.uppercased())
                .foregroundColor(Color.gray)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.top, 24)
                .padding(.bottom, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    content()
                }
                .padding(.horizontal, 10)
            }
        }
    }
}

@available(iOS 14, tvOS 14, *)
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
