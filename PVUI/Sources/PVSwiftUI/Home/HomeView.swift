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
import PVThemes

enum PVHomeSection: Int, CaseIterable, Sendable {
    case recentSaveStates
    case recentlyPlayedGames
    case favorites
    case mostPlayed
}

@available(iOS 14, tvOS 14, *)
struct HomeView: SwiftUI.View {

//    var gameLibrary: PVGameLibrary<RealmDatabaseDriver>!

    weak var rootDelegate: PVRootDelegate?

    @Default(.showRecentSaveStates) private var showRecentSaveStates
    @Default(.showRecentGames) private var showRecentGames
    @Default(.showFavorites) private var showFavorites

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

    init(gameLibrary: PVGameLibrary<RealmDatabaseDriver>? = nil, delegate: PVRootDelegate? = nil) {
//        self.gameLibrary = gameLibrary
        self.rootDelegate = delegate
    }

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some SwiftUI.View {
        StatusBarProtectionWrapper {
            ScrollView {
                LazyVStack {
                    if showRecentSaveStates {
                        HomeContinueSection(rootDelegate: rootDelegate)
                    }

                    if showRecentGames {
                        HomeSection(title: "Recently Played") {
                            ForEach(recentlyPlayedGames.compactMap{$0.game}, id: \.self) { game in
                                GameItemView(game: game, constrainHeight: true) {
                                    Task.detached { @MainActor in
                                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)}
                                }
                                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                            }
                        }
                        HomeDividerView()
                    }

                    if showFavorites {
                        HomeSection(title: "Favorites") {
                            ForEach(favorites, id: \.self) { favorite in
                                GameItemView(game: favorite, constrainHeight: true) {
                                    Task.detached { @MainActor in
                                        await rootDelegate?.root_load(favorite, sender: self, core: nil, saveState: nil)}
                                }
                                .contextMenu { GameContextMenu(game: favorite, rootDelegate: rootDelegate) }
                            }
                        }
                        HomeDividerView()
                    }

                    HomeSection(title: "Most Played") {
                        ForEach(mostPlayed, id: \.self) { playedGame in
                            GameItemView(game: playedGame, constrainHeight: true) {
                                Task.detached { @MainActor in
                                    await rootDelegate?.root_load(playedGame, sender: self, core: nil, saveState: nil)}
                            }
                            .contextMenu { GameContextMenu(game: playedGame, rootDelegate: rootDelegate) }
                        }
                    }
                }
            }
            .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
        }
        .background(themeManager.currentPalette.gameLibraryBackground.swiftUIColor)
    }
}

#endif
