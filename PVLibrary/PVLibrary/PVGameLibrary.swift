//
//  PVGameLibrary.swift
//  PVLibrary
//
//  Created by Dan Berglund on 2020-05-27.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import RxSwift
import RealmSwift
import RxRealm

public struct PVGameLibrary {
    public let favorites: Observable<[PVGame]>
    public let recents: Observable<[PVGame]>

    private let database: RomDatabase

    public init(database: RomDatabase) {
        self.database = database
        self.favorites = Observable
            .collection(from: database.all(PVGame.self, where: #keyPath(PVGame.isFavorite), value: true).sorted(byKeyPath: #keyPath(PVGame.title), ascending: false))
            .mapMany { $0 }
        self.recents = Observable
            .collection(from: database.all(PVRecentGame.self).sorted(byKeyPath: #keyPath(PVRecentGame.lastPlayedDate), ascending: false))
            .mapMany { $0.game }
    }

    public func search(for searchText: String) -> Observable<[PVGame]> {
        // Search first by title, and a broader search if that one's empty
        let titleResults = self.database.all(PVGame.self, filter: NSPredicate(format: "title CONTAINS[c] %@", argumentArray: [searchText]))
        let results = !titleResults.isEmpty ?
            titleResults :
            self.database.all(PVGame.self, filter: NSPredicate(format: "genres LIKE[c] %@ OR gameDescription CONTAINS[c] %@ OR regionName LIKE[c] %@ OR developer LIKE[c] %@ or publisher LIKE[c] %@", argumentArray: [searchText, searchText, searchText, searchText, searchText]))

        return Observable.collection(from: results.sorted(byKeyPath: #keyPath(PVGame.title), ascending: true)).mapMany { $0 }
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
}

public extension ObservableType where Element: Collection {
    func mapMany<R>(_ transform: @escaping (Element.Element) -> R) -> Observable<[R]> {
        map { elements in elements.map(transform) }
    }
}
