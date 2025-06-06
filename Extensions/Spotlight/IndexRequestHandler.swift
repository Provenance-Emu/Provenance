//
//  IndexRequestHandler.swift
//  Spotlight
//
//  Created by Joseph Mattiello on 2/12/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import CoreSpotlight
import CoreServices
import PVLibrary
import PVSupport
import RealmSwift

public enum SpotlightError: Error {
    case appGroupsNotSupported
    case dontHandleDatatype
    case notFound
}

public final class IndexRequestHandler: CSIndexExtensionRequestHandler {
    public override init() {
        super.init()

        if RealmConfiguration.supportsAppGroups {
            RealmConfiguration.setDefaultRealmConfig()
        }
    }

    public override func searchableIndex(_: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        if RealmConfiguration.supportsAppGroups {
            let database = RomDatabase.sharedInstance

            let allGames = database.all(PVGame.self)
            indexResults(allGames)

        } else {
            WLOG("App Groups not setup")
        }

        acknowledgementHandler()
    }

    public override func searchableIndex(_: CSSearchableIndex, reindexSearchableItemsWithIdentifiers identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        // Reindex any items with the given identifiers and the provided index

        if RealmConfiguration.supportsAppGroups {
            let database = RomDatabase.sharedInstance

            let allGamesMatching = database.all(PVGame.self, filter: NSPredicate(format: "md5Hash IN %@", identifiers))
            indexResults(allGamesMatching)
        } else {
            WLOG("App Groups not setup")
        }

        acknowledgementHandler()
    }

//    public override func data(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String) throws -> Data {
//        if !RealmConfiguration.supportsAppGroups {
//            throw SpotlightError.appGroupsNotSupported
//        }
    // Could make a scaled image too and supply the data
//        if let p = pathOfCachedImage?.path, let t = UIImage(contentsOfFile: p), let s = t.scaledImage(withMaxResolution: 270) {
//
//        if typeIdentifier == (kUTTypeImage as String) {
//            do {
//                let url = try fileURL(for: searchableIndex, itemIdentifier: itemIdentifier, typeIdentifier: typeIdentifier, inPlace: true)
//                return try Data(contentsOf: url)
//            } catch {
//                throw error
//            }
//        } else {
//            throw SpotlightError.dontHandleDatatype
//        }
//    }

    public override func fileURL(for _: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String, inPlace _: Bool) throws -> URL {
        if !RealmConfiguration.supportsAppGroups {
            throw SpotlightError.appGroupsNotSupported
        }

        // We're assuming the typeIndentifier is the game one since that's all we've been using so far

        // I think it's looking for the image path
        if typeIdentifier == (kUTTypeImage as String) {
            let md5 = itemIdentifier.components(separatedBy: ".").last ?? ""
            let realm = try Realm()
            if let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5), let artworkURL = game.pathOfCachedImage {
                return artworkURL
            } else {
                throw SpotlightError.notFound
            }
        } else {
            throw SpotlightError.dontHandleDatatype
        }
    }

    private func indexResults(_ results: Results<PVGame>) {
        let items: [CSSearchableItem] = results.compactMap({ (game) -> CSSearchableItem? in
            if !game.md5Hash.isEmpty {
                return CSSearchableItem(uniqueIdentifier: "org.provenance-emu.game.\(game.md5Hash)", domainIdentifier: "org.provenance-emu.game", attributeSet: game.spotlightContentSet)
            } else {
                return nil
            }
        })
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                ELOG("indexing error: \(error)")
            }
        }
    }
}
