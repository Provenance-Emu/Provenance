//
//  LibrarySnapshotWriter.swift
//  PVUIBase
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Writes the shared PVLibrarySnapshot (github.com/Provenance-Emu/PVLibrarySnapshot)
//  that the tvOS Top Shelf reads, and mirrors its covers into the App Group.
//
//  Why covers are mirrored: Top Shelf cannot reach the app's PVMediaCache (on
//  tvOS it lives in the app's private Library/Caches), and the remote artwork
//  URLs are no substitute: gamefaqs answers 403 to non-browser fetches and
//  gametdb serves 160×224 thumbnails, so Top Shelf showed blank artwork.
//
//  This file must not import PVAppIntents: it re-exports PVLibrarySnapshotLegacy,
//  whose type names (`LibrarySnapshotGame`, `LibrarySnapshotAppGroup`, …) are the
//  same as the shared package's. The widgets still read the legacy keys written
//  by `WidgetDataWriter.writeFromRealm()`, which calls this.
//
//  tvOS only: Top Shelf is the only reader. Widen the guard when the widgets
//  move to the shared snapshot.
//

#if os(tvOS)
import Foundation
import CryptoKit
import PVLibrary
import PVLibrarySnapshotConfig
import PVLogging
import PVMediaCache
import RealmSwift
import TVServices
import UIKit

enum LibrarySnapshotWriter {
    /// Serialises writes so an older snapshot never lands after a newer one.
    private static let queue = DispatchQueue(label: "org.provenance-emu.provenance.library-snapshot", qos: .utility)

    /// Reads the candidate games on the main actor, then mirrors covers and saves
    /// the snapshot on a utility queue.
    @MainActor
    static func writeFromRealm() {
        let sources = candidateSources(in: RomDatabase.sharedInstance)
        let jobs: [CoverJob] = sources.compactMap { source in
            guard let key = source.artworkKey,
                  let file = PVMediaCache.filePath(forKey: key),
                  FileManager.default.fileExists(atPath: file.path) else { return nil }
            return CoverJob(gameID: source.md5, source: file, artworkKey: key)
        }

        queue.async {
            let covers = CoverMirror.mirror(jobs, into: ProvenanceSnapshot.appGroup.mediaDirectory)
            let snapshot = ProvenanceSnapshotBuilder.snapshot(from: sources, covers: covers)
            let saved = ProvenanceSnapshot.store.save(snapshot)
            ILOG("[LibrarySnapshot] saved=\(saved) recent=\(snapshot.recentlyPlayed.count) "
                + "favorites=\(snapshot.favorites.count) added=\(snapshot.recentlyAdded.count) "
                + "covers=\(covers.count)/\(sources.count)")
            if saved { TVTopShelfContentProvider.topShelfContentDidChange() }
        }
    }

    /// The recents, favorites and newest imports: a bounded set, never the whole library.
    @MainActor
    private static func candidateSources(in database: RomDatabase) -> [ProvenanceSnapshotSource] {
        let games = database.all(PVGame.self).filter("contentless == false")
        var seen = Set<String>()
        var sources: [ProvenanceSnapshotSource] = []

        func add(_ game: PVGame, recentLastPlayed: Date? = nil) {
            guard !game.isInvalidated, !game.contentless, seen.insert(game.md5Hash).inserted else { return }
            let key = game.customArtworkURL.isEmpty ? game.originalArtworkURL : game.customArtworkURL
            sources.append(ProvenanceSnapshotSource(
                md5: game.md5Hash,
                title: game.title,
                romPath: game.romPath,
                systemIdentifier: game.systemIdentifier,
                regionName: game.regionName,
                lastPlayed: ProvenanceSnapshotBuilder.lastPlayed(recent: recentLastPlayed, game: game.lastPlayed),
                isFavorite: game.isFavorite,
                importDate: game.importDate,
                artworkKey: key.isEmpty ? nil : key
            ))
        }

        let recents = database.all(PVRecentGame.self)
            .sorted(byKeyPath: "lastPlayedDate", ascending: false)
            .prefix(ProvenanceSnapshotBuilder.recentScanDepth)
        for recent in recents {
            guard let game = recent.game else { continue }
            add(game, recentLastPlayed: recent.lastPlayedDate)
        }
        for game in games.filter("isFavorite == true").sorted(byKeyPath: "title").prefix(LibrarySnapshot.maxFavorites) {
            add(game)
        }
        for game in games.sorted(byKeyPath: "importDate", ascending: false).prefix(LibrarySnapshot.maxRecentlyAdded) {
            add(game)
        }
        return sources
    }
}

private struct CoverJob: Sendable {
    let gameID: String
    let source: URL
    let artworkKey: String
}

/// JPEG copies of cover art in the App Group media directory, for Top Shelf.
private enum CoverMirror {
    static let jpegQuality: CGFloat = 0.85

    /// Writes the covers that are missing and deletes covers no job names.
    /// Returns game id → filename for every cover now present.
    static func mirror(_ jobs: [CoverJob], into directory: URL?) -> [String: String] {
        guard let directory else {
            WLOG("[LibrarySnapshot] App Group container unavailable; covers not mirrored")
            return [:]
        }
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        var present: [String: String] = [:]
        for job in jobs {
            guard let sourceData = try? Data(contentsOf: job.source) else { continue }
            let fingerprint = SHA256.hash(data: sourceData).map { String(format: "%02x", $0) }.joined()
            let filename = ProvenanceSnapshotBuilder.coverFilename(gameID: job.gameID, artworkKey: job.artworkKey,
                                                                   sourceFingerprint: fingerprint)
            let url = directory.appendingPathComponent(filename, isDirectory: false)
            if !fileManager.fileExists(atPath: url.path) {
                guard let image = UIImage(data: sourceData),
                      let data = jpegData(image) else { continue }
                do {
                    try data.write(to: url, options: .atomic)
                } catch {
                    WLOG("[LibrarySnapshot] cover write failed for \(job.gameID): \(error.localizedDescription)")
                    continue
                }
            }
            present[job.gameID] = filename
        }

        let keep = Set(present.values)
        let existing = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in existing where name.hasPrefix(ProvenanceSnapshotBuilder.coverFilenamePrefix) && !keep.contains(name) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(name, isDirectory: false))
        }
        return present
    }

    static func jpegData(_ image: UIImage) -> Data? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let source = CGSize(width: pixelWidth, height: pixelHeight)
        let shape = LibraryArtworkShape.shape(for: source)
        guard let layout = shape.layout(for: source) else { return nil }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: layout.canvas, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: layout.canvas))
            context.cgContext.interpolationQuality = .high
            image.draw(in: layout.drawing)
        }
        return rendered.jpegData(compressionQuality: jpegQuality)
    }
}
#endif
