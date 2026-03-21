//
//  ThumbnailProvider.swift
//  ThumbnailExtension
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//
//  Uses the CPDI (ThumbnailArtworkDriver) abstraction so the persistence
//  layer (Realm today, SwiftData in future) can be swapped without touching
//  QL thumbnail logic.
//

import UIKit
import QuickLookThumbnailing
import PVQuickLookSupport

// https://developer.apple.com/documentation/quicklookthumbnailing/providing_thumbnails_of_your_custom_file_types

class ThumbnailProvider: QLThumbnailProvider {

    /// CPDI driver — swap this property to change the persistence backend.
    private lazy var artworkDriver: ThumbnailArtworkDriver = RealmThumbnailArtworkDriver()

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let fileURL = request.fileURL

        // Route to save-state or ROM artwork lookup based on UTI / path conventions.
        if isSaveState(fileURL) {
            if let imageURL = artworkDriver.saveStateImageFileURL(forSaveStatePath: fileURL.path) {
                handler(QLThumbnailReply(imageFileURL: imageURL), nil)
                return
            }
        } else {
            // ROM file — look up artwork via the driver then resolve the cached file URL.
            if let artworkKey = artworkDriver.artworkURLKey(forROMFilename: fileURL.lastPathComponent),
               let artworkFileURL = ArtworkResolver.fileURL(forKey: artworkKey) {
                handler(QLThumbnailReply(imageFileURL: artworkFileURL), nil)
                return
            }
        }

        // Fall back to a simple branded placeholder drawn into the context.
        handler(drawPlaceholderReply(for: request), nil)
    }

    // MARK: - Private Helpers

    /// Returns `true` when `fileURL` represents a save state file.
    private func isSaveState(_ fileURL: URL) -> Bool {
        let ext = fileURL.pathExtension.lowercased()
        // Provenance save states use .pvsav (see SpotlightImportExtension for canonical extension).
        return ext == "pvsav" || fileURL.path.contains("Save States")
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
