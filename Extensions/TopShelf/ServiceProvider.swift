//  ServiceProvider.swift
//  TopShelf
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//
//  Reads the shared PVLibrarySnapshot (github.com/Provenance-Emu/PVLibrarySnapshot,
//  the same package iCube and iFly use) from the App Group. The host app writes
//  it and mirrors cover JPEGs into the group's media folder (PVUIBase
//  `LibrarySnapshotWriter`); this extension never opens Realm and never fetches
//  artwork over the network.
//
//  Why: there is no extension→host-app IPC on tvOS, and Top Shelf is queried
//  precisely when Provenance is not running. Every failure path degrades to
//  `nil`, which shows the static Top Shelf image.
//
import Foundation
import os
import PVLibrarySnapshotConfig
import TVServices

private let log = Logger(subsystem: ProvenanceSnapshot.configuration.telemetrySubsystem, category: "topshelf")

@objc(ServiceProvider)
public final class ServiceProvider: TVTopShelfContentProvider {
    /// Maximum number of games to show in each section.
    private static let maxGamesPerSection = 10

    private let telemetry = ExtensionTelemetry(.topShelf)

    // MARK: - TVTopShelfContentProvider

    public override func loadTopShelfContent(completionHandler: @escaping ((any TVTopShelfContent)?) -> Void) {
        let sections = telemetry.measure(.topShelfBuild) { buildSections() }
        guard !sections.isEmpty else {
            completionHandler(nil)
            return
        }
        completionHandler(TVTopShelfSectionedContent(sections: sections))
    }

    private func buildSections() -> [TVTopShelfItemCollection<TVTopShelfSectionedItem>] {
        let (snapshot, outcome) = ProvenanceSnapshot.store.loadWithOutcome()
        telemetry.record(outcome)

        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
        var covers = 0

        func addSection(_ title: String, _ prefix: String, _ games: [LibrarySnapshotGame]) {
            let items = games.prefix(Self.maxGamesPerSection).map { game -> TVTopShelfSectionedItem in
                // The same game can appear in two sections, so identifiers carry the section.
                let item = TVTopShelfSectionedItem(identifier: "\(prefix)-\(game.id)")
                item.title = game.title
                switch LibraryArtworkShape.shape(forSystemIdentifier: game.platform) {
                case .square: item.imageShape = .square
                case .wide: item.imageShape = .hdtv
                }
                if let url = game.coverURL, FileManager.default.fileExists(atPath: url.path) {
                    item.setImageURL(url, for: .screenScale1x)
                    item.setImageURL(url, for: .screenScale2x)
                    covers += 1
                }
                if let launch = game.launchURL {
                    let action = TVTopShelfAction(url: launch)
                    item.playAction = action
                    item.displayAction = action
                }
                return item
            }
            guard !items.isEmpty else { return }
            let collection = TVTopShelfItemCollection(items: Array(items))
            collection.title = title
            sections.append(collection)
        }

        // Before anything has been played on this Apple TV, lead with the newest
        // imports so a fresh library still fills the shelf.
        if snapshot.recentlyPlayed.isEmpty {
            addSection(Self.sectionTitleRecentlyAdded, "added", snapshot.recentlyAdded)
            addSection(Self.sectionTitleFavorites, "favorite", snapshot.favorites)
        } else {
            addSection(Self.sectionTitleRecentlyPlayed, "recent", snapshot.recentlyPlayed)
            addSection(Self.sectionTitleFavorites, "favorite", snapshot.favorites)
            addSection(Self.sectionTitleRecentlyAdded, "added", snapshot.recentlyAdded)
        }

        // .notice, not .info: .info is not persisted, so it never reaches a sysdiagnose.
        log.notice("""
            load: \(outcome.reason, privacy: .public) recent=\(snapshot.recentlyPlayed.count) \
            favorites=\(snapshot.favorites.count) added=\(snapshot.recentlyAdded.count) \
            sections=\(sections.count) covers=\(covers)
            """)
        return sections
    }

    // MARK: - Localized strings

    private static let sectionTitleRecentlyPlayed = NSLocalizedString(
        "topshelf.section.recently-played", value: "Recently Played",
        comment: "Top Shelf section heading for recently played games"
    )
    private static let sectionTitleFavorites = NSLocalizedString(
        "topshelf.section.favorites", value: "Favorites",
        comment: "Top Shelf section heading for favorite games"
    )
    private static let sectionTitleRecentlyAdded = NSLocalizedString(
        "topshelf.section.recently-added", value: "Recently Added",
        comment: "Top Shelf section heading for recently imported games"
    )
}
