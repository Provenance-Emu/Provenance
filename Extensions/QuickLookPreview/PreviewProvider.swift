//
//  PreviewProvider.swift
//  QuickLookPreview
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import QuickLook
import UniformTypeIdentifiers
import PVLibrary
import PVHashing
import RealmSwift

// NOTE: This file is ready for use once the QuickLookPreview Xcode build target is created (#3310).
// To enable: set QLIsDataBasedPreview = true and NSExtensionPrincipalClass = PreviewProvider in Info.plist,
// then remove NSExtensionMainStoryboard.

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let filename = fileURL.lastPathComponent

        // Look up game metadata from the shared Realm database.
        let info = ROMPreviewInfo(forROMAt: fileURL)

        // Build an HTML preview card and return it as the QLPreviewReply.
        let html = buildHTMLCard(filename: filename, info: info)
        let htmlData = Data(html.utf8)

        let reply = QLPreviewReply(dataOfContentType: .html,
                                   contentSize: CGSize(width: 600, height: 800)) { replyToUpdate in
            replyToUpdate.stringEncoding = .utf8
            return htmlData
        }
        return reply
    }

    // MARK: - Private

    private func buildHTMLCard(filename: String, info: ROMPreviewInfo?) -> String {
        let title = info?.title ?? filename
        let system = info?.systemName ?? "Unknown System"
        let developer = info?.developer ?? ""
        let year = info?.year ?? ""
        let genre = info?.genre ?? ""
        let description = info?.gameDescription ?? ""
        let playCount = info?.playCount ?? 0
        let isFavorite = info?.isFavorite ?? false
        let artworkBase64 = info?.artworkBase64 ?? ""

        let artworkTag = artworkBase64.isEmpty
            ? "<div class=\"art-placeholder\">🎮</div>"
            : "<img class=\"artwork\" src=\"data:image/jpeg;base64,\(artworkBase64)\" alt=\"Box Art\">"

        let favoriteTag = isFavorite ? "<span class=\"badge favorite\">★ Favorite</span>" : ""
        let playCountTag = playCount > 0
            ? "<span class=\"badge plays\">▶ \(playCount) play\(playCount == 1 ? "" : "s")</span>"
            : ""
        let devYearParts = [developer, year].filter { !$0.isEmpty }.joined(separator: " · ")
        let metaRow = [devYearParts, genre].filter { !$0.isEmpty }.joined(separator: " | ")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          body { font-family: -apple-system, sans-serif; background: #0f0f1a; color: #e8e8f0; margin: 0; padding: 20px; }
          .card { display: flex; gap: 20px; align-items: flex-start; }
          .artwork, .art-placeholder { width: 140px; height: 140px; border-radius: 10px; object-fit: cover; flex-shrink: 0; }
          .art-placeholder { background: #1e1e2e; display: flex; align-items: center; justify-content: center; font-size: 48px; }
          .info { flex: 1; min-width: 0; }
          h1 { margin: 0 0 4px; font-size: 20px; color: #ffffff; }
          .system { color: #f28030; font-size: 14px; font-weight: 600; margin-bottom: 6px; }
          .meta { color: #a0a0b8; font-size: 13px; margin-bottom: 8px; }
          .badges { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 10px; }
          .badge { font-size: 12px; padding: 2px 8px; border-radius: 20px; }
          .favorite { background: #3a2a00; color: #f28030; }
          .plays { background: #1a2a3a; color: #60a0e0; }
          .description { font-size: 13px; color: #c0c0d8; line-height: 1.5; margin-top: 10px;
                         display: -webkit-box; -webkit-line-clamp: 5; -webkit-box-orient: vertical; overflow: hidden; }
          .filename { margin-top: 14px; font-size: 11px; color: #606080; font-family: monospace; word-break: break-all; }
        </style>
        </head>
        <body>
        <div class="card">
          \(artworkTag)
          <div class="info">
            <h1>\(title.htmlEscaped)</h1>
            <div class="system">\(system.htmlEscaped)</div>
            <div class="meta">\(metaRow.htmlEscaped)</div>
            <div class="badges">\(favoriteTag)\(playCountTag)</div>
          </div>
        </div>
        \(description.isEmpty ? "" : "<p class=\"description\">\(description.htmlEscaped)</p>")
        <div class="filename">\(filename.htmlEscaped)</div>
        </body>
        </html>
        """
    }
}

// MARK: - ROMPreviewInfo

/// Lightweight struct carrying metadata for the HTML preview card.
struct ROMPreviewInfo {
    let title: String
    let systemName: String?
    let developer: String?
    let year: String?
    let genre: String?
    let gameDescription: String?
    let playCount: Int
    let isFavorite: Bool
    /// JPEG bytes of box art, base64-encoded, or empty string if unavailable.
    let artworkBase64: String

    /// Looks up metadata from the shared Realm database by ROM filename.
    ///
    /// Opens the App Group Realm (same store as the main app) and queries
    /// `PVGame` by matching the ROM filename suffix.  All Realm objects are
    /// read synchronously on the calling thread and no Realm objects escape
    /// this initializer — only plain value types are stored.
    init(forROMAt fileURL: URL) {
        let romFilename = fileURL.lastPathComponent

        // Derive a human-readable title from the filename as a fallback.
        let fallbackTitle = fileURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")

        guard RealmConfiguration.supportsAppGroups else {
            WLOG("App Groups not available — QuickLookPreview falling back to filename metadata")
            self.title = fallbackTitle
            self.systemName = nil
            self.developer = nil
            self.year = nil
            self.genre = nil
            self.gameDescription = nil
            self.playCount = 0
            self.isFavorite = false
            self.artworkBase64 = ""
            return
        }

        do {
            RealmConfiguration.setDefaultRealmConfig()
            let realm = try Realm()

            // romPath is stored as "{systemID}/{filename}" or just "{filename}".
            // Match the suffix to avoid requiring the full path.
            let bySuffix = realm.objects(PVGame.self)
                .filter("romPath ENDSWITH %@", "/" + romFilename)
            let game = bySuffix.first
                ?? realm.objects(PVGame.self).filter("romPath == %@", romFilename).first

            guard let game = game else {
                DLOG("No game found in Realm for filename: \(romFilename)")
                self.title = fallbackTitle
                self.systemName = nil
                self.developer = nil
                self.year = nil
                self.genre = nil
                self.gameDescription = nil
                self.playCount = 0
                self.isFavorite = false
                self.artworkBase64 = ""
                return
            }

            // Copy all values out of the Realm object before it goes out of scope.
            let resolvedTitle = game.title.isEmpty ? fallbackTitle : game.title
            let systemName = game.system?.name ?? game.systemShortName
            let developer: String? = game.developer.flatMap { $0.isEmpty ? nil : $0 }
            let year: String? = game.publishDate.flatMap { $0.isEmpty ? nil : $0 }
            let genre: String? = game.genres.flatMap { $0.isEmpty ? nil : $0 }
            let description = game.gameDescription
            let playCount = game.playCount
            let isFavorite = game.isFavorite
            let artworkKey = game.artworkURL

            // Resolve the artwork key to a base64-encoded JPEG string.
            var artworkBase64 = ""
            if !artworkKey.isEmpty,
               let artworkURL = ROMPreviewInfo.resolveMediaCacheURL(forKey: artworkKey),
               let imageData = try? Data(contentsOf: artworkURL) {
                artworkBase64 = imageData.base64EncodedString()
            }

            self.title = resolvedTitle
            self.systemName = systemName
            self.developer = developer
            self.year = year
            self.genre = genre
            self.gameDescription = description
            self.playCount = playCount
            self.isFavorite = isFavorite
            self.artworkBase64 = artworkBase64

        } catch {
            ELOG("Realm lookup failed in QuickLookPreview: \(error.localizedDescription)")
            self.title = fallbackTitle
            self.systemName = nil
            self.developer = nil
            self.year = nil
            self.genre = nil
            self.gameDescription = nil
            self.playCount = 0
            self.isFavorite = false
            self.artworkBase64 = ""
        }
    }

    // MARK: - Private Helpers

    /// Resolves a PVMediaCache key to a local file URL via the App Group container.
    ///
    /// Mirrors the lookup in `ThumbnailProvider.resolveMediaCacheURL(forKey:)`.
    private static func resolveMediaCacheURL(forKey key: String) -> URL? {
        guard !key.isEmpty else { return nil }
        let keyHash = key.md5Hash

        // App Group container — reliable from extension processes.
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: PVAppGroupId) {
            let candidate = groupURL
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent("PVCache", isDirectory: true)
                .appendingPathComponent(keyHash, isDirectory: false)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // Local documents fallback via PVMediaCache.
        if let localURL = PVMediaCache.filePath(forKey: key),
           FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        return nil
    }
}

// MARK: - String+HTML

private extension String {
    /// Escapes special HTML characters.
    var htmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
