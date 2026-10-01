//
//  ArtworkSelfHealing.swift
//  PVLibrary
//
//  A stored artwork URL can go dead (a gamefaqs Cloudflare 403 challenge on the user's
//  network, a 404, or an HTML page served with 200). Without this, such a game keeps retrying
//  the same URL and never gets art. This type downloads and judges an artwork URL, and when it
//  is dead looks for a replacement (libretro thumbnails first), saving the first one that works.
//

import Foundation
import PVLogging
import PVLookup
import PVLookupTypes
import PVMediaCache
import PVRealm
import PVSystems
import RealmSwift
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Result of downloading one artwork URL.
enum ArtworkFetchResult: Sendable {
    case image(Data)
    /// URL is unusable; `reason` is e.g. "HTTP 403" or "non-image body (4821 bytes)".
    case dead(reason: String)
    /// Temporary failure (5xx, timeout); keep the URL and try again later.
    case transient(reason: String, statusCode: Int?)
}

/// What is needed to look up replacement artwork for one game. Plain values only, so it is safe
/// to build from a Realm object on its own thread and use anywhere.
struct ArtworkHealContext: Sendable {
    /// MD5 (the Realm primary key); also the negative-cache key.
    let md5: String
    let gameID: String
    let title: String
    let romFileName: String?
    let systemID: SystemIdentifier?
}

enum ArtworkSelfHealing {
    private static let logPrefix = "ArtworkSelfHealing"

    // MARK: - Download + judge

    /// Download `url` and decide whether it is a usable image. A URL already known dead this
    /// launch is reported dead without touching the network.
    static func fetch(_ url: URL, session: URLSession = .shared) async -> ArtworkFetchResult {
        if await ArtworkDeadURLCache.shared.isDead(url) {
            return .dead(reason: "known dead this launch")
        }
        do {
            let (data, response) = try await session.data(from: url)
            let status = (response as? HTTPURLResponse)?.statusCode
            switch ArtworkDownloadClassifier.classify(statusCode: status, data: data) {
            case .image:
                await ArtworkDeadURLCache.shared.recordSuccess(url)
                return .image(data)
            case .dead(let reason):
                await ArtworkDeadURLCache.shared.recordDead(url, statusCode: status)
                WLOG("\(logPrefix): dead artwork URL \(url.host ?? "?") (\(reason)): \(url.absoluteString)")
                return .dead(reason: reason)
            case .transient(let reason):
                VLOG("\(logPrefix): transient artwork failure \(url.host ?? "?") (\(reason)): \(url.absoluteString)")
                return .transient(reason: reason, statusCode: status)
            }
        } catch {
            return .transient(reason: error.localizedDescription, statusCode: nil)
        }
    }

    // MARK: - Heal

    /// Look for replacement artwork for a game whose `deadURL` failed. Tries libretro thumbnails
    /// first, then other PVLookup sources, and returns the first one that downloads as an image.
    /// If everything fails the game is remembered for this launch so it is not searched again.
    static func heal(
        _ context: ArtworkHealContext,
        deadURL: String?,
        reason: String,
        session: URLSession = .shared
    ) async -> (url: URL, data: Data)? {
        let gameKey = context.md5.uppercased()
        guard await !ArtworkDeadURLCache.shared.isExhausted(gameKey: gameKey) else {
            VLOG("\(logPrefix): \(context.title) already exhausted this launch, skipping")
            return nil
        }
        guard let systemID = context.systemID, systemID != .Unknown else {
            WLOG("\(logPrefix): \(context.title) has no known system, cannot look up a replacement")
            return nil
        }

        ILOG("\(logPrefix): \(context.title) — stored artwork URL dead (\(reason)): \(deadURL ?? "none"); looking for another source")

        let rom = ROMMetadata(
            gameTitle: context.title,
            systemID: systemID,
            romFileName: context.romFileName,
            romHashMD5: context.md5.isEmpty ? nil : context.md5
        )
        let excluded: Set<String> = deadURL.map { [$0] } ?? []
        let candidates = await PVLookup.shared.fallbackArtworkURLs(forRom: rom, excluding: excluded)

        for candidate in candidates {
            let source = ArtworkFallbackPlanner.isLibretroThumbnail(candidate) ? "libretro" : (candidate.host ?? "other")
            switch await fetch(candidate, session: session) {
            case .image(let data):
                ILOG("\(logPrefix): \(context.title) — fallback \(source) OK (HTTP 200, \(data.count) bytes): \(candidate.absoluteString)")
                return (candidate, data)
            case .dead(let why):
                WLOG("\(logPrefix): \(context.title) — fallback \(source) failed (\(why)): \(candidate.absoluteString)")
            case .transient(let why, _):
                WLOG("\(logPrefix): \(context.title) — fallback \(source) transient failure (\(why)): \(candidate.absoluteString)")
            }
        }

        await ArtworkDeadURLCache.shared.markExhausted(gameKey: gameKey)
        WLOG("\(logPrefix): \(context.title) — no working artwork source (\(candidates.count) tried); not retrying this launch")
        return nil
    }

    /// Heal by MD5 alone (used by sync code that has no game context): reads the game fields on a
    /// background Realm, looks for a replacement and saves it. Returns true if artwork was saved.
    @discardableResult
    static func healAndPersist(md5: String, deadURL: String?, reason: String) async -> Bool {
        guard let context = await loadContext(md5: md5) else { return false }
        return await healAndPersist(context, deadURL: deadURL, reason: reason) != nil
    }

    /// Heal and save. Returns the number of bytes downloaded for the replacement (so callers can
    /// charge their write budget), or `nil` if no replacement was found or saved.
    @discardableResult
    static func healAndPersist(_ context: ArtworkHealContext, deadURL: String?, reason: String) async -> Int? {
        guard let replacement = await heal(context, deadURL: deadURL, reason: reason) else { return nil }
        let saved = await persist(data: replacement.data, url: replacement.url, md5: context.md5, gameID: context.gameID)
        return saved ? replacement.data.count : nil
    }

    // MARK: - Persist

    /// Cache the image under `url`, then record `url` as the game's artwork URL and file.
    /// Realm work runs on its own background thread keyed by IDs, never a passed-in object.
    @discardableResult
    static func persist(data: Data, url: URL, md5: String, gameID: String) async -> Bool {
        let localURL: URL
        do {
            localURL = try writeCachedImage(data, key: url.absoluteString)
        } catch {
            WLOG("\(logPrefix): could not cache artwork \(url.absoluteString): \(error.localizedDescription)")
            return false
        }

        let saved = await Task.detached(priority: .utility) { () -> Bool in
            guard let realm = try? Realm(),
                  let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5) ??
                             (!gameID.isEmpty ? realm.objects(PVGame.self).filter("id == %@", gameID).first : nil)
            else { return false }
            do {
                try realm.write {
                    game.originalArtworkFile = PVImageFile(withURL: localURL, relativeRoot: .documents)
                    game.originalArtworkURL = url.absoluteString
                }
                return true
            } catch {
                WLOG("ArtworkSelfHealing: could not save replacement artwork URL: \(error.localizedDescription)")
                return false
            }
        }.value

        if saved {
            ILOG("\(logPrefix): saved replacement artwork for \(md5): \(url.absoluteString)")
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .artworkDidCache,
                    object: nil,
                    userInfo: [SyncNotification.gameIDsKey: Set([md5])]
                )
            }
        }
        return saved
    }

    /// Decode `data` and write it to the media cache the way other artwork paths do.
    private static func writeCachedImage(_ data: Data, key: String) throws -> URL {
        #if os(macOS)
        guard let image = NSImage(data: data) else { throw MediaCacheError.failedToScaleImage }
        return try PVMediaCache.writeImage(toDisk: image, withKey: key)
        #else
        guard let image = UIImage(data: data) else { throw MediaCacheError.failedToScaleImage }
        return try PVMediaCache.writeImage(toDisk: image, withKey: key)
        #endif
    }

    // MARK: - Context

    static func loadContext(md5: String) async -> ArtworkHealContext? {
        await Task.detached(priority: .utility) { () -> ArtworkHealContext? in
            guard let realm = try? Realm(),
                  let game = realm.object(ofType: PVGame.self, forPrimaryKey: md5)
            else { return nil }
            return context(for: game)
        }.value
    }

    /// Build a context from a Realm game. Call on the thread that owns `game`.
    static func context(for game: PVGame) -> ArtworkHealContext {
        let fileName = (game.romPath as NSString).lastPathComponent
        return ArtworkHealContext(
            md5: game.md5Hash,
            gameID: game.id,
            title: game.title,
            romFileName: fileName.isEmpty ? nil : fileName,
            systemID: SystemIdentifier(rawValue: game.systemIdentifier)
        )
    }
}
