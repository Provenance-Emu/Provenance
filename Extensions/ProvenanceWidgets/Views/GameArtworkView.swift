//
//  GameArtworkView.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import SwiftUI
import UIKit

/// Displays box art for a game or falls back to a system-icon placeholder.
///
/// Takes an App Group–relative *path* plus the pixel budget it will be drawn at, and
/// decodes straight into that budget. It deliberately does not take pre-loaded `Data`:
/// WidgetKit renders every entry of a timeline in one burst right after `getTimeline`
/// returns, so pre-loading in the provider does not move the work off the render path —
/// it only forces every cover in the timeline to stay resident at once, at full
/// resolution. Decoding here keeps one bounded bitmap alive at a time.
struct GameArtworkView: View {
    let artworkPath: String?
    /// Maximum pixels on the artwork's longest edge — see `WidgetArtworkPixelBudget`.
    let maxPixelSize: Int
    let cornerRadius: CGFloat

    init(artworkPath: String?, maxPixelSize: Int, cornerRadius: CGFloat = 8) {
        self.artworkPath = artworkPath
        self.maxPixelSize = maxPixelSize
        self.cornerRadius = cornerRadius
    }

    private var artworkImage: UIImage? {
        guard let artworkPath else { return nil }
        return WidgetSharedDefaults.artworkImage(forRelativePath: artworkPath, maxPixelSize: maxPixelSize)
    }

    var body: some View {
        // Color.clear is fully flexible — it fills the parent's proposed size exactly.
        // The overlay renders the artwork ON TOP using the same bounding rect.
        // .clipped() then cuts any scaledToFill overflow to that rect before
        // clipShape rounds the corners.
        Color.clear
            .overlay {
                if let uiImage = artworkImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholderView
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholderView: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "gamecontroller.fill")
                .foregroundStyle(.secondary)
                .font(.title2)
        }
    }
}
#endif
