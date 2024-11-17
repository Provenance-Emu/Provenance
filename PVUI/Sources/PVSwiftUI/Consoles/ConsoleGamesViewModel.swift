//
//  ConsoleGamesViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/17/24.
//

import SwiftUI
import RealmSwift
import PVLibrary
import PVThemes
import PVUIBase
import PVRealm
import PVSettings
import Combine

class ConsoleGamesViewModel: ObservableObject {
    let console: PVSystem

    @ObservedResults(
        PVGame.self,
        filter: NSPredicate(format: "systemIdentifier == %@"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
    ) var games

    @ObservedResults(
        PVSaveState.self,
        filter: NSPredicate(format: "game.systemIdentifier == %@"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
    ) var recentSaveStates

    @ObservedResults(
        PVRecentGame.self,
        filter: NSPredicate(format: "game.systemIdentifier == %@")
    ) var recentlyPlayedGames

    @ObservedResults(
        PVGame.self,
        filter: NSPredicate(format: "isFavorite == true AND systemIdentifier == %@")
    ) var favorites

    @ObservedResults(
        PVGame.self,
        filter: NSPredicate(format: "systemIdentifier == %@ AND playCount > 0"),
        sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false)
    ) var mostPlayed

    init(console: PVSystem) {
        self.console = console
        _games = ObservedResults(
            PVGame.self,
            filter: NSPredicate(format: "systemIdentifier == %@", console.identifier),
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: false)
        )
        _recentSaveStates = ObservedResults(
            PVSaveState.self,
            filter: NSPredicate(format: "game.systemIdentifier == %@", console.identifier),
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVSaveState.date), ascending: false)
        )
        _recentlyPlayedGames = ObservedResults(
            PVRecentGame.self,
            filter: NSPredicate(format: "game.systemIdentifier == %@", console.identifier)
        )
        _favorites = ObservedResults(
            PVGame.self,
            filter: NSPredicate(format: "isFavorite == true AND systemIdentifier == %@", console.identifier)
        )
        _mostPlayed = ObservedResults(
            PVGame.self,
            filter: NSPredicate(format: "systemIdentifier == %@ AND playCount > 0", console.identifier),
            sortDescriptor: SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false)
        )
    }
}
