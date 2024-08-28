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
@_exported public import PVSettings

public class PVGameLibrary<T> where T: DatabaseDriver {
    
    public struct System {
        public let identifier: String
        public let manufacturer: String
        public let shortName: String
        public let isBeta: Bool
        public let unsupported: Bool
        public let sortedGames: [T.GameType]
    }
    
    internal let database: RomDatabase
    internal let databaseDriver: T

    public init(database: RomDatabase) {
        self.database = database

        self.databaseDriver = .init(database: database)
    }
}

public extension PVGameLibrary where T == RealmDatabaseDriver {
    public func toggleFavorite(for game: PVGame) -> Completable {
        return databaseDriver.toggleFavorite(for: game)
    }
}


extension RealmSwift.LinkingObjects where Element: PVGame {
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

extension Array where Element == PVGameLibrary<RealmDatabaseDriver>.System {
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
