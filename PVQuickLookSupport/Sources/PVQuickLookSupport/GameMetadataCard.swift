//
//  GameMetadataCard.swift
//  PVQuickLookSupport
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Builds self-contained HTML preview cards for use in QLPreviewReply.
//  Pure Foundation — no UIKit, AppKit, SwiftUI, or WebKit imports.
//

import Foundation

/// Builds a self-contained HTML game metadata card for `QLPreviewReply`.
///
/// The generated HTML is suitable for use with
/// `QLPreviewReply(dataOfContentType: .html, ...)` and embeds all styling
/// inline so it renders correctly in Quick Look without external resources.
///
/// Usage example:
/// ```swift
/// let artworkData = ArtworkResolver.data(forKey: gameInfo.artworkURLKey ?? "")
/// let html = GameMetadataCard.html(for: gameInfo, filename: filename, artworkData: artworkData)
/// let reply = QLPreviewReply(dataOfContentType: .html, contentSize: CGSize(width: 600, height: 800)) { _ in
///     Data(html.utf8)
/// }
/// ```
public struct GameMetadataCard {

    // MARK: - Public API

    /// Returns a complete HTML document for the given `GameInfo`.
    ///
    /// - Parameters:
    ///   - gameInfo: Metadata to display.  When `nil` a minimal card is rendered
    ///     using only the filename.
    ///   - filename: The ROM's bare filename, shown at the bottom of the card.
    ///   - artworkData: Raw JPEG or PNG bytes to embed as the box-art image.
    ///     When `nil` a system-icon placeholder is shown instead.
    /// - Returns: A complete HTML document as a `String`.
    public static func html(
        for gameInfo: GameInfo?,
        filename: String,
        artworkData: Data? = nil
    ) -> String {
        let rawTitle = gameInfo?.title ?? ""
        let title = rawTitle.isEmpty ? derivedTitle(from: filename) : rawTitle
        let system = gameInfo?.systemName ?? ""
        let developer = gameInfo?.developer ?? ""
        let year = gameInfo?.publishDate ?? ""
        let genre = gameInfo?.genre ?? ""
        let description = gameInfo?.gameDescription ?? ""
        let playCount = gameInfo?.playCount ?? 0
        let isFavorite = gameInfo?.isFavorite ?? false
        let systemID = gameInfo?.systemIdentifier ?? ""

        // Build artwork tag — either an embedded base64 image or a placeholder icon.
        // Only embed data when the format is positively identified (JPEG or PNG).
        let artworkTag: String
        if let data = artworkData, !data.isEmpty, let mime = data.recognizedMIMEType {
            let b64 = data.base64EncodedString()
            artworkTag = "<img class=\"artwork\" src=\"data:\(mime);base64,\(b64)\" alt=\"Box Art\">"
        } else {
            let symbol = SystemIconProvider.sfSymbolName(forSystemIdentifier: systemID)
            artworkTag = "<div class=\"art-placeholder\" data-symbol=\"\(symbol.htmlEscaped)\">🎮</div>"
        }

        let favoriteTag = isFavorite
            ? "<span class=\"badge favorite\">★ Favorite</span>"
            : ""
        let playCountTag = playCount > 0
            ? "<span class=\"badge plays\">▶ \(playCount) play\(playCount == 1 ? "" : "s")</span>"
            : ""

        let devYear = [developer, year].filter { !$0.isEmpty }.joined(separator: " · ")
        let metaRow = [devYear, genre].filter { !$0.isEmpty }.joined(separator: " | ")

        let descriptionBlock = description.isEmpty
            ? ""
            : "<p class=\"description\">\(description.htmlEscaped)</p>"

        return """
        <!DOCTYPE html>
        <html lang="en">
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
        \(descriptionBlock)
        <div class="filename">\(filename.htmlEscaped)</div>
        </body>
        </html>
        """
    }

    // MARK: - Private helpers

    /// Derives a human-readable title from a ROM filename by stripping the
    /// extension and replacing underscores / hyphens with spaces.
    private static func derivedTitle(from filename: String) -> String {
        let base = (filename as NSString).deletingPathExtension
        return base
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}

// MARK: - String+HTML

extension String {
    /// Escapes `&`, `<`, `>`, and `"` for safe HTML embedding.
    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - Data+ImageType

private extension Data {
    /// Returns the MIME type when the magic bytes identify a known image format, or `nil` for unrecognized data.
    ///
    /// Recognized formats:
    /// - JPEG: SOI marker `FF D8`
    /// - PNG:  signature `89 50 4E 47`
    var recognizedMIMEType: String? {
        if count >= 2 && self[0] == 0xFF && self[1] == 0xD8 {
            return "image/jpeg"
        }
        if count >= 4 && self[0] == 0x89 && self[1] == 0x50 && self[2] == 0x4E && self[3] == 0x47 {
            return "image/png"
        }
        return nil
    }
}
