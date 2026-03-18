//
//  ThumbnailProvider.swift
//  ThumbnailExtension
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import UIKit
import QuickLookThumbnailing
import PVLibrary
import os.log

// https://developer.apple.com/documentation/quicklookthumbnailing/providing_thumbnails_of_your_custom_file_types

class ThumbnailProvider: QLThumbnailProvider {

    private let logger = OSLog(subsystem: "org.provenance-emu.provenance.thumbnail", category: "ThumbnailProvider")

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let fileURL = request.fileURL

        // Try to look up artwork in the shared Realm database using the ROM filename.
        // Filename-based lookup avoids MD5-hashing large ROM files in the extension process.
        if let artworkURL = lookupArtworkURL(forROMAt: fileURL) {
            if let artworkFileURL = PVMediaCache.filePath(forKey: artworkURL),
               FileManager.default.fileExists(atPath: artworkFileURL.path) {
                handler(QLThumbnailReply(imageFileURL: artworkFileURL), nil)
                return
            }
        }

        // Fall back to a simple branded placeholder drawn into the context.
        handler(drawPlaceholderReply(for: request), nil)
    }

    // MARK: - Private Helpers

    /// Looks up the `artworkURL` for a game whose ROM filename matches `fileURL.lastPathComponent`.
    /// Returns `nil` if Realm is unavailable or no matching game is found.
    private func lookupArtworkURL(forROMAt fileURL: URL) -> String? {
        guard RealmConfiguration.supportsAppGroups else {
            os_log("App Groups not supported — cannot access shared Realm", log: logger, type: .error)
            return nil
        }

        do {
            RealmConfiguration.setDefaultRealmConfig()
            let realm = try Realm()
            let filename = fileURL.lastPathComponent

            // romPath stores a partial path like "{systemID}/{filename}" or just "{filename}".
            // Match any game whose romPath ends with the ROM filename.
            let games = realm.objects(PVGame.self)
                .filter("romPath ENDSWITH %@", "/" + filename)
            let match = games.first ?? realm.objects(PVGame.self)
                .filter("romPath == %@", filename).first

            guard let game = match else { return nil }
            let url = game.artworkURL
            return url.isEmpty ? nil : url
        } catch {
            os_log("Realm lookup failed: %{public}@", log: logger, type: .error, error.localizedDescription)
            return nil
        }
    }

    /// Draws a simple "Provenance" branded placeholder when no artwork is available.
    private func drawPlaceholderReply(for request: QLFileThumbnailRequest) -> QLThumbnailReply {
        let size = request.maximumSize
        return QLThumbnailReply(contextSize: size, currentContextDrawing: {
            let rect = CGRect(origin: .zero, size: size)

            // Background gradient
            let context = UIGraphicsGetCurrentContext()
            let colors = [UIColor(red: 0.12, green: 0.12, blue: 0.20, alpha: 1).cgColor,
                          UIColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors as CFArray,
                                         locations: [0, 1]) {
                context?.drawLinearGradient(gradient,
                                            start: CGPoint(x: 0, y: 0),
                                            end: CGPoint(x: 0, y: size.height),
                                            options: [])
            }

            // "P" logo placeholder
            let label = "P"
            let fontSize = min(size.width, size.height) * 0.5
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1)
            ]
            let textSize = (label as NSString).size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (label as NSString).draw(in: textRect, withAttributes: attributes)
            UIRectFrame(rect)
            return true
        })
    }
}
