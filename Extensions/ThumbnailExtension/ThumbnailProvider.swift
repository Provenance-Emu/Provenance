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
        // For iCloud placeholder files the URL contains the .icloud suffix — strip it
        // to recover the real filename so Realm lookups succeed without downloading the file.
        let effectiveFilename = ROMGameLookup.realFilename(from: fileURL)

        // Reconstruct an effective path that replaces the iCloud placeholder filename
        // with the real filename, preserving the directory so Realm path queries work.
        let effectivePath = fileURL.deletingLastPathComponent()
            .appendingPathComponent(effectiveFilename).path

        // Route to save-state or ROM artwork lookup based on UTI / path conventions.
        if isSaveState(fileURL, filename: effectiveFilename) {
            if let imageURL = artworkDriver.saveStateImageFileURL(forSaveStatePath: effectivePath) {
                handler(QLThumbnailReply(imageFileURL: imageURL), nil)
                return
            }
        } else {
            // ROM file — look up artwork via the driver then resolve the cached file URL.
            if let artworkKey = artworkDriver.artworkURLKey(forROMFilename: effectiveFilename),
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
    private func isSaveState(_ fileURL: URL, filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        // .pvsav = Provenance Save State bundle (canonical extension for SpotlightImportExtension)
        // .svs   = raw emulator save state slot file (used by PVEmulatorViewController)
        // pathComponents check ensures "Save States" matches an exact directory component,
        // not a substring (avoids false positives like "My Save States Collection/game.rom").
        return ext == "pvsav" || ext == "svs" || fileURL.pathComponents.contains("Save States")
    }

    /// Draws a Provenance-branded placeholder when no artwork is available.
    ///
    /// Uses a deep navy background with an orange diagonal stripe accent and a
    /// game-controller emoji — visually distinct from Adobe's solid-letter icons.
    private func drawPlaceholderReply(for request: QLFileThumbnailRequest) -> QLThumbnailReply {
        let size = request.maximumSize
        return QLThumbnailReply(contextSize: size, currentContextDrawing: {
            guard let context = UIGraphicsGetCurrentContext() else { return false }

            // Deep navy-to-midnight background gradient
            let bgColors = [UIColor(red: 0.10, green: 0.13, blue: 0.25, alpha: 1).cgColor,
                            UIColor(red: 0.04, green: 0.04, blue: 0.10, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: bgColors as CFArray,
                                         locations: [0, 1]) {
                context.drawLinearGradient(gradient,
                                           start: .zero,
                                           end: CGPoint(x: 0, y: size.height),
                                           options: [])
            }

            // Diagonal orange accent stripe (bottom-left to top-right corner)
            let stripe = UIBezierPath()
            let stripeW = size.width * 0.18
            stripe.move(to: CGPoint(x: 0, y: size.height))
            stripe.addLine(to: CGPoint(x: stripeW, y: size.height))
            stripe.addLine(to: CGPoint(x: size.width, y: 0))
            stripe.addLine(to: CGPoint(x: size.width - stripeW, y: 0))
            stripe.close()
            UIColor(red: 0.95, green: 0.50, blue: 0.05, alpha: 0.35).setFill()
            stripe.fill()

            // Game controller emoji centred in the icon
            let emoji = "🎮"
            let fontSize = min(size.width, size.height) * 0.44
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize)
            ]
            let textSize = (emoji as NSString).size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width  - textSize.width)  / 2,
                y: (size.height - textSize.height) / 2,
                width:  textSize.width,
                height: textSize.height
            )
            (emoji as NSString).draw(in: textRect, withAttributes: attributes)
            return true
        })
    }
}
