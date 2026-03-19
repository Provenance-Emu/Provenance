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

// NOTE: This file is ready for use once the QuickLookPreview Xcode build target is created (#3310).
// To enable: set QLIsDataBasedPreview = true and NSExtensionPrincipalClass = PreviewProvider in Info.plist,
// then remove NSExtensionMainStoryboard.

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let filename = fileURL.lastPathComponent

        // Look up game metadata from the shared Realm database.
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
