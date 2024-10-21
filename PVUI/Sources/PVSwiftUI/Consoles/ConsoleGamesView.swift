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
import PVThemes
import PVUIBase
import PVRealm

// TODO: might be able to reuse this view for collections


struct ConsoleGamesFilterModeFlags: OptionSet {
    let rawValue: Int
    
    // Played
    static let played = ConsoleGamesFilterModeFlags(rawValue: 1 << 0)
    
    // Never played
    static let neverPlayed = ConsoleGamesFilterModeFlags(rawValue: 1 << 1)
    
    // Recently Imported
    static let recentlyImported = ConsoleGamesFilterModeFlags(rawValue: 1 << 2)
    
    // Recently played
    static let recentlyPlayed = ConsoleGamesFilterModeFlags(rawValue: 1 << 3)
}
struct ConsoleGamesView: SwiftUI.View {
    
    @ObservedObject var viewModel: PVRootViewModel
    @ObservedRealmObject var console: PVSystem
    weak var rootDelegate: PVRootDelegate?
    
    let gamesForSystemPredicate: NSPredicate
    
    @ObservedResults(
        PVGame.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var games
    
    @ObservedResults(PVRecentGame.self) var recentlyPlayedGames
    @ObservedResults(PVGame.self) var favorites
    @ObservedResults(PVGame.self) var mostPlayed
    
    @ObservedResults(
        PVSaveState.self,
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) var recentSaveStates
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    init(console: PVSystem, viewModel: PVRootViewModel, rootDelegate: PVRootDelegate? = nil) {
        self.console = console
        self.viewModel = viewModel
        self.rootDelegate = rootDelegate
        self.gamesForSystemPredicate = NSPredicate(format: "systemIdentifier == %@", argumentArray: [console.identifier])
        
        let recentlyPlayedPredicate = NSPredicate(format: "game.systemIdentifier == %@", argumentArray: [console.identifier])
        let favoritesPredicate = NSPredicate(format: "\(#keyPath(PVGame.isFavorite)) == %@ AND systemIdentifier == %@", NSNumber(value: true), console.identifier)
        let mostPlayedPredicate = NSPredicate(format: "systemIdentifier == %@", argumentArray: [console.identifier])
        let saveStatesPredicate = NSPredicate(format: "game.systemIdentifier == %@", argumentArray: [console.identifier])
        
        _recentlyPlayedGames = ObservedResults(PVRecentGame.self,
                                               filter: recentlyPlayedPredicate,
                                               sortDescriptor: SortDescriptor(keyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false))
        _favorites = ObservedResults(PVGame.self,
                                     filter: favoritesPredicate,
                                     sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false))
        _mostPlayed = ObservedResults(PVGame.self,
                                      filter: mostPlayedPredicate,
                                      sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false))
        _recentSaveStates = ObservedResults(PVSaveState.self,
                                            filter: saveStatesPredicate,
                                            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false))
    }
    
    func filteredAndSortedGames() -> Results<PVGame> {
        return games
            .filter(gamesForSystemPredicate)
            .sorted(by: [
                SortDescriptor(keyPath: #keyPath(PVGame.isFavorite), ascending: false),
                SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: viewModel.sortGamesAscending)
            ])
    }
    
    // Adjustable grid size via pinch
    // from; https://github.com/AlexanderMarchant/DynamicGridZoom/tree/main
    @State var scale: CGFloat = 1.0
    
    // Multiple of how much to decrease the existing size to equal the next decreased size
    @State var scaleFactor: CGFloat = 1.0
    
    // Multiple of how much to increase the existing size to equal the next increased size
    @State var zoomFactor: CGFloat = 1.0
    
    @State var isMagnifying = false
    
    @State private var size: CGFloat = 100
    
    @State private var currentZoomStageIndex = 2
    @State private var previousZoomStageUpdateState: CGFloat = 0
    @State private var adjustedState: CGFloat = 0
    
    @State private var gridWidth: CGFloat = 0
    @State private var zooming: Bool = false
    
    @State private var padding: CGFloat = 2
    
    @State private var filter: ConsoleGamesFilterModeFlags = []
    
    var body: some SwiftUI.View {
        let columns = [
            GridItem(.adaptive(minimum: size), spacing: padding)
        ]
        return VStack {
            GamesDisplayOptionsView(
                sortAscending: viewModel.sortGamesAscending,
                isGrid: viewModel.viewGamesAsGrid,
                toggleFilterAction: { self.rootDelegate?.showUnderConstructionAlert() },
                toggleSortAction: { viewModel.sortGamesAscending.toggle() },
                toggleViewTypeAction: { viewModel.viewGamesAsGrid.toggle() })
            .padding(.top, 16)
            
            ScrollView {
                LazyVStack(spacing: 20) {
                    if !recentSaveStates.filter("game.systemIdentifier == %@", console.identifier).isEmpty {
                        HomeContinueSection(rootDelegate: rootDelegate, consoleIdentifier: console.identifier)
                        HomeDividerView()
                    }
                    
                    let filteredFavorites = favorites.filter("systemIdentifier == %@", console.identifier)
                    if !filteredFavorites.isEmpty {
                        HomeSection(title: "Favorites") {
                            ForEach(Array(filteredFavorites), id: \.self) { favorite in
                                GameItemView(game: favorite, constrainHeight: true) {
                                    Task.detached { @MainActor in
                                        await rootDelegate?.root_load(favorite, sender: self, core: nil, saveState: nil)
                                    }
                                }
                                .contextMenu { GameContextMenu(game: favorite, rootDelegate: rootDelegate) }
                            }
                        }
                        .frame(height: 150)
                        HomeDividerView()
                    }
                    
                    if !recentlyPlayedGames.isEmpty {
                        HomeSection(title: "Recently Played") {
                            ForEach(recentlyPlayedGames.compactMap{$0.game}, id:\.self) { game in
                                GameItemView(game: game, constrainHeight: true) {
                                    Task.detached { @MainActor in
                                        await rootDelegate?.root_load(game, sender:self, core: nil, saveState: nil)
                                    }
                                }
                                .contextMenu { GameContextMenu(game: game,rootDelegate: rootDelegate) }
                            }
                        }
                        .frame(height: 150)
                        HomeDividerView()
                    }
                    
                    // Existing grid or list view for all games
                    if viewModel.viewGamesAsGrid {
                        LazyVGrid(columns: columns, spacing: padding) {
                            ForEach(filteredAndSortedGames(), id: \.self) { game in
                                GameItemView(game: game, constrainHeight: false) {
                                    Task.detached { @MainActor in
                                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                                    }
                                }
                                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                            }
                        }
                    } else {
                        LazyVStack(spacing: padding) {
                            ForEach(filteredAndSortedGames(), id: \.self) { game in
                                GameItemView(game: game, constrainHeight: false) {
                                    Task.detached { @MainActor in
                                        await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                                    }
                                }
                                .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate) }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    // MARK: Adjustable size helpers
    func resetZoomVariables() {
        self.calculateZoomFactor(at: self.currentZoomStageIndex)
        self.zooming = false
        self.scale = 1
        self.scaleFactor = 1
        self.previousZoomStageUpdateState = 0
        self.adjustedState = 0
    }
    
    func calculateUpdatedSize(index: Int) -> CGFloat {
        let zoomStages = GridZoomStages.getZoomStage(at: index)
        
        let availableSpace = self.gridWidth - (2 * CGFloat(zoomStages))
        
        return availableSpace / CGFloat(zoomStages)
    }
    
    func calculateZoomFactor(at index: Int) {
        let currentSize = self.calculateUpdatedSize(index: index)
        let magnifiedSize = self.calculateUpdatedSize(index: index - 1)
        
        self.zoomFactor = magnifiedSize / currentSize
        
        self.size = currentSize
    }
}

@available(iOS 14, tvOS 14, *)
struct ConsoleGamesView_Previews: PreviewProvider {
    static let console: PVSystem = ._rlmDefaultValue()
    static let viewModel: PVRootViewModel = .init()
    
    static var previews: some SwiftUI.View {
        ConsoleGamesView(console: console,
                         viewModel: viewModel,
                         rootDelegate: nil)
    }
}

struct GridZoomStages
{
    static var zoomStages: [Int]
    {
#if os(tvOS)
        return [1, 2, 4, 8, 16]
#else
        if UIDevice.current.userInterfaceIdiom == .pad
        {
            if UIDevice.current.orientation.isLandscape
            {
                return [4, 6, 10, 14, 18]
            }
            else
            {
                return [4, 6, 8, 10, 12]
            }
        }
        else
        {
            if UIDevice.current.orientation.isLandscape
            {
                return [4, 6, 8, 9]
            }
            else
            {
                return [1, 2, 4, 6, 8]
            }
        }
#endif
    }
    
    static func getZoomStage(at index: Int) -> Int
    {
        if index >= zoomStages.count
        {
            return zoomStages.last!
        }
        else if index < 0
        {
            return zoomStages.first!
        }
        else
        {
            return zoomStages[index]
        }
    }
}
#endif
