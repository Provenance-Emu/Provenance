//
//  PVLookup+ArtworkFallback.swift
//  PVLookup
//
//  Replacement artwork sources for a game whose stored artwork URL is dead.
//

import Foundation
import PVLogging
import PVLookupTypes
import PVSystems
#if canImport(libretrodb)
import libretrodb
#endif

public extension PVLookup {
    /// URLs to try, best first, when `rom`'s current artwork URL is dead.
    ///
    /// Order: libretro thumbnails built straight from the system folder plus ROM file name or
    /// title (HEAD-validated), then libretro/OpenVGDB/TheGamesDB URLs from the databases, then
    /// a title search. Anything in `excluding`, and anything already known dead this launch,
    /// is dropped. Returns at most `maxAttempts` URLs.
    func fallbackArtworkURLs(
        forRom rom: ROMMetadata,
        excluding dead: Set<String>,
        maxAttempts: Int = ArtworkFallbackPlanner.defaultMaxAttempts
    ) async -> [URL] {
        guard rom.systemID != .Unknown else { return [] }

        var excluded = dead
        excluded.formUnion(await ArtworkDeadURLCache.shared.deadURLStrings())

        var libretro: [URL] = []
        #if canImport(libretrodb)
        let systemName = rom.systemID.libretroDatabaseName
        var names: [String] = []
        for name in [rom.romFileName, rom.gameTitle] {
            if let name, !name.isEmpty, !names.contains(name) { names.append(name) }
        }
        for name in names {
            let urls = await LibretroArtwork.getValidURLs(systemName: systemName, gameName: name)
            libretro.append(contentsOf: urls)
        }
        #endif

        var databaseURLs: [URL] = []
        if !rom.gameTitle.isEmpty {
            databaseURLs = ((try? await getArtworkURLs(forRom: rom)) ?? [])
            let searched = (try? await searchArtwork(
                byGameName: rom.gameTitle,
                systemID: rom.systemID,
                artworkTypes: .boxFront
            )) ?? []
            databaseURLs.append(contentsOf: searched.map(\.url))
        }

        let libretroFromDB = databaseURLs.filter(ArtworkFallbackPlanner.isLibretroThumbnail)
        let others = databaseURLs.filter { !ArtworkFallbackPlanner.isLibretroThumbnail($0) }

        let blockedHosts = await Self.blockedHosts(in: libretro + libretroFromDB + others)
        return ArtworkFallbackPlanner.order(
            libretro: libretro + libretroFromDB,
            others: others,
            excluding: excluded,
            isBlocked: { url in url.host.map(blockedHosts.contains) ?? false },
            maxAttempts: maxAttempts
        )
    }

    private static func blockedHosts(in urls: [URL]) async -> Set<String> {
        var blocked: Set<String> = []
        for url in urls {
            if let host = url.host, await ArtworkDeadURLCache.shared.isHostBlocked(url) {
                blocked.insert(host)
            }
        }
        return blocked
    }
}
