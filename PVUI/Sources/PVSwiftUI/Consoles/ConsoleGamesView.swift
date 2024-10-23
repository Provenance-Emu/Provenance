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
import PVSettings

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
struct ConsoleGamesView: SwiftUI.View, GameContextMenuDelegate {

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

        // Initialize scale with the saved value
        let savedScale = CGFloat(Defaults[.gameLibraryScale])
        _scale = State(initialValue: savedScale)
    }

    func filteredAndSortedGames() -> Results<PVGame> {
        return games
            .filter(gamesForSystemPredicate)
            .sorted(by: [
                SortDescriptor(keyPath: #keyPath(PVGame.isFavorite), ascending: false),
                SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: viewModel.sortGamesAscending)
            ])
    }

    @State private var scale: CGFloat
    @State private var lastScale: CGFloat = 1.0
    @State private var currentZoomIndex: Int = 2 // Start at middle zoom level

    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var gameToUpdateCover: PVGame?

    var body: some SwiftUI.View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                GamesDisplayOptionsView(
                    sortAscending: viewModel.sortGamesAscending,
                    isGrid: viewModel.viewGamesAsGrid,
                    toggleFilterAction: { self.rootDelegate?.showUnderConstructionAlert() },
                    toggleSortAction: { viewModel.sortGamesAscending.toggle() },
                    toggleViewTypeAction: { viewModel.viewGamesAsGrid.toggle() })
                .padding(.top, 16)

                ZStack(alignment: .bottom) {
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
                                        .contextMenu { GameContextMenu(game: favorite, rootDelegate: rootDelegate, contextMenuDelegate: self) }
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
                                        .contextMenu { GameContextMenu(game: game,rootDelegate: rootDelegate, contextMenuDelegate: self) }
                                    }
                                }
                                .frame(height: 150)
                                HomeDividerView()
                            }

                            // Existing grid or list view for all games
                            if viewModel.viewGamesAsGrid {
                                let columns = [GridItem(.adaptive(minimum: calculateGridItemSize()), spacing: 2)]
                                LazyVGrid(columns: columns, spacing: 2) {
                                    ForEach(filteredAndSortedGames(), id: \.self) { game in
                                        GameItemView(game: game, constrainHeight: false) {
                                            Task { @MainActor in
                                                await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                                            }
                                        }
                                        .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: self) }
                                    }
                                }
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            adjustZoom(delta: delta)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                            saveScale()
                                        }
                                )
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(filteredAndSortedGames(), id: \.self) { game in
                                        GameItemView(game: game, constrainHeight: false) {
                                            Task { @MainActor in
                                                await rootDelegate?.root_load(game, sender: self, core: nil, saveState: nil)
                                            }
                                        }
                                        .contextMenu { GameContextMenu(game: game, rootDelegate: rootDelegate, contextMenuDelegate: self) }
                                    }
                                }
                            }
                            BiosesView(console: console)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 44)
                    }
                }
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: .photoLibrary) { image in
                if let game = gameToUpdateCover {
                    saveArtwork(image: image, forGame: game)
                }
                gameToUpdateCover = nil
                showImagePicker = false
            }
        }
    }

    // MARK: - Zoom Helpers

    private func calculateGridItemSize() -> CGFloat {
        let baseSize: CGFloat = 100 // Adjust this base size as needed
        return baseSize * scale
    }

    private func adjustZoom(delta: CGFloat) {
        let minScale: CGFloat = 0.5
        let maxScale: CGFloat = 1.5
        let newScale = scale * delta
        scale = min(max(newScale, minScale), maxScale)
    }

    private func saveScale() {
        Defaults[.gameLibraryScale] = Float(scale)
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestRenameFor game: PVGame, to newTitle: String) {
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                thawedGame?.title = newTitle
            }
            rootDelegate?.showMessage("Game successfully renamed to \(newTitle).", title: "Game Renamed")
        } catch {
            rootDelegate?.showMessage("Failed to rename game: \(error.localizedDescription)", title: "Error")
        }
    }

    func gameContextMenu(_ menu: GameContextMenu, didRequestChooseCoverFor game: PVGame) {
        gameToUpdateCover = game
        showImagePicker = true
    }

    private func saveArtwork(image: UIImage, forGame game: PVGame) {
        DLOG("GameContextMenu: Attempting to save artwork for game: \(game.title)")

        let uniqueID = UUID().uuidString
        let key = "artwork_\(game.md5)_\(uniqueID)"
        DLOG("Generated key for image: \(key)")

        do {
            DLOG("Attempting to write image to disk")
            try PVMediaCache.writeImage(toDisk: image, withKey: key)
            DLOG("Image successfully written to disk")

            DLOG("Attempting to update game's customArtworkURL")
            try RomDatabase.sharedInstance.writeTransaction {
                let thawedGame = game.thaw()
                DLOG("Game thawed: \(thawedGame?.title ?? "Unknown")")
                thawedGame?.customArtworkURL = key
                DLOG("Game's customArtworkURL updated to: \(key)")
            }
            DLOG("Database transaction completed successfully")
            rootDelegate?.showMessage("Artwork has been saved for \(game.title).", title: "Artwork Saved")

            // Verify the image can be retrieved
            DLOG("Attempting to verify image retrieval")
            PVMediaCache.shareInstance().image(forKey: key) { retrievedKey, retrievedImage in
                if let retrievedImage = retrievedImage {
                    DLOG("Successfully retrieved saved image for key: \(retrievedKey)")
                    DLOG("Retrieved image size: \(retrievedImage.size)")
                } else {
                    DLOG("Failed to retrieve saved image for key: \(retrievedKey)")
                }
            }
        } catch {
            DLOG("Failed to set custom artwork: \(error.localizedDescription)")
            DLOG("Error details: \(error)")
            rootDelegate?.showMessage("Failed to set custom artwork for \(game.title): \(error.localizedDescription)", title: "Error")
        }
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

// New BiosesView
struct BiosesView: View {
    let console: PVSystem

    var body: some View {
        VStack {
            GamesDividerView()
            ForEach(console.bioses, id: \.self) { bios in
                BiosRowView(bios: bios.warmUp())
                GamesDividerView()
            }
        }
    }
}

#endif
