//
//  PreviewProvider.swift
//  QuickLookPreview
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import QuickLook
import UniformTypeIdentifiers
import PVQuickLookSupport

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        // For iCloud placeholder files the URL contains the .icloud suffix — strip it
        // so App Group library index lookups succeed without requiring the file to be downloaded.
        let filename = ROMGameLookup.realFilename(from: fileURL)

        // Look up game metadata from the App Group library index.
        let gameInfo = ROMGameLookup.lookup(forROMFilename: filename)

        // Resolve artwork — raw bytes so the HTML card can embed it as base64.
        let artworkData: Data? = gameInfo.flatMap { info in
            info.artworkURLKey.flatMap { ArtworkResolver.data(forKey: $0) }
        }

        // Build an HTML preview card and return it as the QLPreviewReply.
        let html = GameMetadataCard.html(for: gameInfo, filename: filename, artworkData: artworkData)
        let htmlData = Data(html.utf8)

        let reply = QLPreviewReply(dataOfContentType: .html,
                                   contentSize: CGSize(width: 600, height: 800)) { replyToUpdate in
            replyToUpdate.stringEncoding = .utf8
            return htmlData
        }
        return reply
    }
}
