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

public struct PVGameLibrary {
    public let saveStates: Observable<[PVSaveState]>
    public let favorites: Observable<[PVGame]>
    public let recents: Observable<[PVRecentGame]>

    private let database: RomDatabase

    public init(database: RomDatabase) {
        self.database = database
        self.saveStates = Observable
            .collection(from: database.all(PVSaveState.self).filter("game != nil && game.system != nil").sorted(byKeyPath: #keyPath(PVSaveState.lastOpened), ascending: false).sorted(byKeyPath: #keyPath(PVSaveState.date), ascending: false))
            .mapMany { $0 }
        self.favorites = Observable
            .collection(from: database.all(PVGame.self, where: #keyPath(PVGame.isFavorite), value: true).sorted(byKeyPath: #keyPath(PVGame.title), ascending: false))
            .mapMany { $0 }
        self.recents = Observable
            .collection(from: database.all(PVRecentGame.self).sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false))
            .mapMany { $0 }
    }

    public func search(for searchText: String) -> Observable<[PVGame]> {
        // Search first by title, and a broader search if that one's empty
        let titleResults = self.database.all(PVGame.self, filter: NSPredicate(format: "title CONTAINS[c] %@", argumentArray: [searchText]))
        let results = !titleResults.isEmpty ?
            titleResults :
            self.database.all(PVGame.self, filter: NSPredicate(format: "genres LIKE[c] %@ OR gameDescription CONTAINS[c] %@ OR regionName LIKE[c] %@ OR developer LIKE[c] %@ or publisher LIKE[c] %@", argumentArray: [searchText, searchText, searchText, searchText, searchText]))

        return Observable.collection(from: results.sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)).mapMany { $0 }
    }

    public func systems(sortedBy sortOptions: SortOptions) -> Observable<[System]> {
        let betaIDs: [SystemIdentifier] = [.AtariJaguar, .Saturn, .Dreamcast]
        return Observable.collection(from: database.all(PVSystem.self))
            .flatMapLatest({ systems -> Observable<[System]> in
                // Here we actualy observe on the games for each system, since we want to update this when games are added or removed from a system
                Observable.combineLatest(systems.map({ (pvSystem: PVSystem) -> Observable<System> in
                    let sortedGames = pvSystem.games.sorted(by: sortOptions)
                    return Observable.collection(from: sortedGames)
                        .mapMany { $0 }
                        .map({ games in
                            System(
                                identifier: pvSystem.identifier,
                                manufacturer: pvSystem.manufacturer,
                                shortName: pvSystem.shortName,
                                isBeta: betaIDs.contains(pvSystem.enumValue),
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
        public let sortedGames: [PVGame]
    }
}

public extension ObservableType where Element: Collection {
    func mapMany<R>(_ transform: @escaping (Element.Element) -> R) -> Observable<[R]> {
        map { elements in elements.map(transform) }
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
        }

        sortDescriptors.append(SortDescriptor(keyPath: #keyPath(PVGame.title), ascending: true))
        return sorted(by: sortDescriptors)
    }
}

extension Array where Element == PVGameLibrary.System {
    func sorted(by sortOptions: SortOptions) -> Array<Element> {
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
        }
    }
}
