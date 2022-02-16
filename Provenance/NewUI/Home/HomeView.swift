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
        filter: NSPredicate(format: "game != nil && game.system != nil"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) var recentSaveStates
    
    @ObservedResults(
        PVRecentGame.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
    ) var recentlyPlayedGames
    
    @ObservedResults(
        PVGame.self,
        filter: NSPredicate(format: "\(#keyPath(PVGame.isFavorite)) == %@", NSNumber(value: true)),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var favorites
    
    @ObservedResults(
        PVGame.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false)
    ) var mostPlayed
    
    init(gameLibrary: PVGameLibrary, delegate: PVRootDelegate) {
        self.gameLibrary = gameLibrary
        self.rootDelegate = delegate
    }
    
    var body: some SwiftUI.View {
        StatusBarProtectionWrapper {
            ScrollView {
                LazyVStack {
                    if #available(iOS 15, tvOS 15, *) {
                        HomeContinueSection(continueStates: recentSaveStates, rootDelegate: rootDelegate)
                    } else {
                        HomeSection(title: "Continue") {
                            ForEach(recentSaveStates, id: \.self) { recentSaveState in
                                GameItemView(game: recentSaveState.game, constrainHeight: true) {
                                    rootDelegate?.root_load(recentSaveState.game, sender: self, core: recentSaveState.core, saveState: recentSaveState)
                                }
                            }
                        }
                        HomeDividerView()
                    }
                    HomeSection(title: "Recently Played") {
                        ForEach(recentlyPlayedGames, id: \.self) { recentlyPlayedGame in
                            GameItemView(game: recentlyPlayedGame.game, constrainHeight: true) {
                                rootDelegate?.root_load(recentlyPlayedGame.game, sender: self, core: nil, saveState: nil)
                            }
                            .contextMenu { GameContextMenu(game: recentlyPlayedGame.game, rootDelegate: rootDelegate) }
                        }
                    }
                    HomeDividerView()
                    HomeSection(title: "Favorites") {
                        ForEach(favorites, id: \.self) { favorite in
                            GameItemView(game: favorite, constrainHeight: true) {
                                rootDelegate?.root_load(favorite, sender: self, core: nil, saveState: nil)
                            }
                            .contextMenu { GameContextMenu(game: favorite, rootDelegate: rootDelegate) }
                        }
                    }
                    HomeDividerView()
                    HomeSection(title: "Most Played") {
                        ForEach(mostPlayed, id: \.self) { playedGame in
                            GameItemView(game: playedGame, constrainHeight: true) {
                                rootDelegate?.root_load(playedGame, sender: self, core: nil, saveState: nil)
                            }
                            .contextMenu { GameContextMenu(game: playedGame, rootDelegate: rootDelegate) }
                        }
                    }
                }
            }
        }
        .background(Theme.currentTheme.gameLibraryBackground.swiftUIColor)
    }
}

@available(iOS 15, tvOS 15, *)
struct HomeContinueSection: SwiftUI.View {
    
    var continueStates: Results<PVSaveState>
    var rootDelegate: PVRootDelegate?
    let height: CGFloat = 260
    
    var body: some SwiftUI.View {
        
        TabView {
            if continueStates.count > 0 {
                ForEach(continueStates, id: \.self) { state in
                    HomeContinueItemView(continueState: state, height: height) {
                        rootDelegate?.root_load(state.game, sender: self, core: state.core, saveState: state)
                    }
                }
            } else {
                Text("No Continues")
                    .tag("no continues")
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
        .id(continueStates.count)
        .frame(height: height)
    }
}

@available(iOS 15, tvOS 15, *)
struct HomeContinueItemView: SwiftUI.View {
    
    var continueState: PVSaveState
    let height: CGFloat // match image height to section height, else the fill content mode messes up the zstack
    var action: () -> Void
    
    var body: some SwiftUI.View {
        Button {
            action()
        } label: {
            ZStack {
                if let screenshot = continueState.image, let image = UIImage(contentsOfFile: screenshot.url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: height)
                } else {
                    Image(uiImage: UIImage.missingArtworkImage(gameTitle: continueState.game.title, ratio: 1))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: height)
                }
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Continue...")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
                            Text(continueState.game.title)
                                .font(.system(size: 13))
                                .foregroundColor(Color.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("...").font(.system(size: 15)).opacity(0)
                            Text(continueState.game.system.name)
                                .font(.system(size: 8))
                                .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(.ultraThinMaterial)
                }
            }
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct HomeSection<Content: SwiftUI.View>: SwiftUI.View {
    
    let title: String
    
    @ViewBuilder var content: () -> Content
    
    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .foregroundColor(Theme.currentTheme.gameLibraryText.swiftUIColor)
                .font(.system(size: 11))
                .padding(.horizontal, 10)
                .padding(.top, 20)
                .padding(.bottom, 8)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    content()
                }
                .padding(.horizontal, 10)
            }
            .padding(.bottom, 5)
        }
    }
}

@available(iOS 14, tvOS 14, *)
struct HomeDividerView: SwiftUI.View {
    var body: some SwiftUI.View {
        Divider()
            .frame(height: 1)
            .background(Theme.currentTheme.gameLibraryText.swiftUIColor)
            .opacity(0.1)
            .padding(.horizontal, 10)
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
        .background(Theme.currentTheme.gameLibraryBackground.swiftUIColor)
    }
}

#endif
