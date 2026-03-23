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
/// Pass `artworkData` as pre-loaded bytes from the timeline provider;
/// no disk I/O is performed during rendering.
struct GameArtworkView: View {
    let artworkData: Data?
    let cornerRadius: CGFloat

    init(artworkData: Data?, cornerRadius: CGFloat = 8) {
        self.artworkData = artworkData
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        // Color.clear is fully flexible — it fills the parent's proposed size exactly.
        // The overlay renders the artwork ON TOP using the same bounding rect.
        // .clipped() then cuts any scaledToFill overflow to that rect before
        // clipShape rounds the corners.
        Color.clear
            .overlay {
                if let data = artworkData, let uiImage = UIImage(data: data) {
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
