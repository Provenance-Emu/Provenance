//
//  PVGameLibrary.swift
//  PVLibrary
//
//  Created by Dan Berglund on 2020-05-27.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import RxSwift
import RealmSwift
import RxRealm
import PVLogging

public struct PVGameLibrary {
    public let saveStates: Observable<[PVSaveState]>
    public let favorites: Observable<[PVGame]>
    public let recents: Observable<[PVRecentGame]>
    public let mostPlayed: Observable<[PVGame]>

    public let saveStatesResults: Results<PVSaveState>
    public let favoritesResults: Results<PVGame>
    public let recentsResults: Results<PVRecentGame>
    public let mostPlayedResults: Results<PVGame>
    public let activeSystems: Results<PVSystem>

    private let database: RomDatabase

    public init(database: RomDatabase) {
        self.database = database

        self.saveStatesResults = database.all(PVSaveState.self).filter("game != nil && game.system != nil").sorted(byKeyPath: #keyPath(PVSaveState.lastOpened), ascending: false).sorted(byKeyPath: #keyPath(PVSaveState.date), ascending: false)
        self.saveStates = Observable
            .collection(from: self.saveStatesResults)
            .mapMany { $0 }

        self.favoritesResults = database.all(PVGame.self, where: #keyPath(PVGame.isFavorite), value: true).sorted(byKeyPath: #keyPath(PVGame.title), ascending: false)
        self.favorites = Observable
            .collection(from: self.favoritesResults)
            .mapMany { $0 }

        self.recentsResults = database.all(PVRecentGame.self).sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false)
        self.recents = Observable
            .collection(from: recentsResults)
            .mapMany { $0 }

        self.mostPlayedResults = database.all(PVGame.self).sorted(byKeyPath: #keyPath(PVGame.playCount), ascending: false)
        self.mostPlayed = Observable
            .collection(from: self.mostPlayedResults)
            .mapMany { $0 }

        self.activeSystems = database.all(PVSystem.self, filter: NSPredicate(format: "games.@count > 0")).sorted(byKeyPath: #keyPath(PVSystem.name), ascending: true)
    }

    public func search(for searchText: String) -> Observable<[PVGame]> {
        return Observable.collection(from: searchResults(for: searchText)).mapMany { $0 }
    }

    public func searchResults(for searchText: String) -> Results<PVGame> {
        // Search first by title, and a broader search if that one's empty
        if searchText.count == 0 {
            return self.database.all(PVGame.self).sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        } else {
            let titleResults = self.database.all(PVGame.self, filter: NSPredicate(format: "title CONTAINS[c] %@", argumentArray: [searchText]))
            let results = !titleResults.isEmpty ?
            titleResults :
            self.database.all(PVGame.self, filter: NSPredicate(format: "genres LIKE[c] %@ OR gameDescription CONTAINS[c] %@ OR regionName LIKE[c] %@ OR developer LIKE[c] %@ or publisher LIKE[c] %@", argumentArray: [searchText, searchText, searchText, searchText, searchText]))
            return results.sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)
        }
    }

    public func systems(sortedBy sortOptions: SortOptions) -> Observable<[System]> {
        let betaIDs: [SystemIdentifier] = SystemIdentifier.betas
        let unsuppotedIDs: [SystemIdentifier] = SystemIdentifier.unsupported

        return Observable.collection(from: database.all(PVSystem.self))
            .flatMapLatest({ systems -> Observable<[System]> in
                // Here we actualy observe on the games for each system, since we want to update this when games are added or removed from a system
                Observable.combineLatest(systems.map({ (pvSystem: PVSystem) -> Observable<System> in
                    // We read all the values from the realm-object here, and not in the `Observable.collection` below
                    // Not doing this makes the game crash when using refreshGameLibrary, since the pvSystem goes out of scope inside the closure, and thus we crash
                    let identifier = pvSystem.identifier
                    let manufacturer = pvSystem.manufacturer
                    let shortName = pvSystem.shortName
                    let isBeta = betaIDs.contains(pvSystem.enumValue)
                    let unsupported = unsuppotedIDs.contains(pvSystem.enumValue)
                    let sortedGames = pvSystem.games.sorted(by: sortOptions)
                    return Observable.collection(from: sortedGames)
                        .mapMany { $0 }
                        .map({ games in
                            System(
                                identifier: identifier,
                                manufacturer: manufacturer,
                                shortName: shortName,
                                isBeta: isBeta,
                                unsupported: unsupported,
                                sortedGames: games
                            )
                        })
                }))
            })
            .map { systems in systems.sorted(by: sortOptions) }
    }

    public func toggleFavorite(for game: PVGame) -> Completable {
        Completable.create { observer in
            do {
                try self.database.writeTransaction {
                    game.isFavorite = !game.isFavorite
                    observer(.completed)
                }
            } catch {
                observer(.error(error))
            }
            return Disposables.create()
        }
    }

    public struct System {
        public let identifier: String
        public let manufacturer: String
        public let shortName: String
        public let isBeta: Bool
        public let unsupported: Bool
        public let sortedGames: [PVGame]
    }

    /// Clear the library
    public func clearLibrary() -> Completable {
        Completable.create { observer in
            do {
                try self.database.deleteAllData()
                observer(.completed)
            } catch {
                NSLog("Failed to delete all objects. \(error.localizedDescription)")
                observer(.error(error))
            }
            return Disposables.create()
        }
    }

    public func clearROMs() -> Completable {
        Completable.create { observer in
            do {
                try self.database.deleteAllGames()
                observer(.completed)
            } catch {
                ELOG("Failed to delete all objects. \(error.localizedDescription)")
                observer(.error(error))
            }
            return Disposables.create()
        }
    }
    public func refreshLibrary() -> Completable {
        Completable.create { observer in
            do {
                try self.database.refresh()
                observer(.completed)
            } catch {
                NSLog("Failed to refresh all objects. \(error.localizedDescription)")
                observer(.error(error))
            }
            return Disposables.create()
        }
    }
    public func gamesForSystem(systemIdentifier: String) -> Results<PVGame> {
        return database.all(PVGame.self).filter(NSPredicate(format: "systemIdentifier == %@", argumentArray: [systemIdentifier]))
    }

    public func system(identifier: String) -> PVSystem? {
        return database.object(ofType: PVSystem.self, wherePrimaryKeyEquals: identifier)
    }

    public func game(identifier: String) -> PVGame? {
        return database.object(ofType: PVGame.self, wherePrimaryKeyEquals: identifier)
    }

//    public enum SaveType {
//        case auto
//        case manual
//        case any
//    }
//    public func saves(ofType type: SaveType = .any, game: PVGame? = nil) -> [PVSaveState]? {
//        let saves =
//        switch type {
//        case .auto:
//            return database.all(PVSaveState.self).filter("isAutoSave == YES").sorted(byKeyPath: #keyPath(PVSaveState.lastOpened), ascending: false).sorted(byKeyPath: #keyPath(PVSaveState.date), ascending: false)
//        case .manual:
//            return saveStates.filter("isAutosave == NO")
//        case .any:
//
//        }
//    }
}

public extension ObservableType where Element: Collection {
    func mapMany<R>(_ transform: @escaping (Element.Element) -> R?) -> Observable<[R]> {
        map { elements in elements.compactMap(transform) }
    }
}

extension LinkingObjects where Element: PVGame {
    func sorted(by sortOptions: SortOptions) -> Results<Element> {
        var sortDescriptors = [SortDescriptor(keyPath: #keyPath(PVGame.isFavorite), ascending: false)]
        switch sortOptions {
        case .title:
            break
        case .importDate:
            sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.importDate), ascending: false))
        case .lastPlayed:
            sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.lastPlayed), ascending: false))
        case .mostPlayed:
            sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.playCount), ascending: false))
        }

        sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: true))
        return sorted(by: sortDescriptors)
    }
}

extension Array where Element == PVGameLibrary.System {
    func sorted(by sortOptions: SortOptions) -> [Element] {
        let titleSort: (Element, Element) -> Bool = { (s1, s2) -> Bool in
            let mc = s1.manufacturer.compare(s2.manufacturer)
            if mc == .orderedSame {
                return s1.shortName.compare(s2.shortName) == .orderedAscending
            } else {
                return mc == .orderedAscending
            }
        }

        switch sortOptions {
        case .title:
            return sorted(by: titleSort)
        case .lastPlayed:
            return sorted(by: { (s1, s2) -> Bool in
                let l1 = s1.sortedGames.first?.lastPlayed
                let l2 = s2.sortedGames.first?.lastPlayed

                if let l1 = l1, let l2 = l2 {
                    return l1.compare(l2) == .orderedDescending
                } else if l1 != nil {
                    return true
                } else if l2 != nil {
                    return false
                } else {
                    return titleSort(s1, s2)
                }
            })
        case .importDate:
            return sorted(by: { (s1, s2) -> Bool in
                let l1 = s1.sortedGames.first?.importDate
                let l2 = s2.sortedGames.first?.importDate

                if let l1 = l1, let l2 = l2 {
                    return l1.compare(l2) == .orderedDescending
                } else if l1 != nil {
                    return true
                } else if l2 != nil {
                    return false
                } else {
                    return titleSort(s1, s2)
                }
            })
        case .mostPlayed:
            return sorted(by: { (s1, s2) -> Bool in
                let l1 = s1.sortedGames.first?.playCount
                let l2 = s2.sortedGames.first?.playCount

                if let l1 = l1, let l2 = l2 {
                    return l1 < l2
                } else if l1 != nil {
                    return true
                } else if l2 != nil {
                    return false
                } else {
                    return titleSort(s1, s2)
                }
            })
        }
    }
}
