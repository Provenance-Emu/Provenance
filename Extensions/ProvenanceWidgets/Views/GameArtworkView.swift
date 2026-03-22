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
        Group {
            if let data = artworkData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(.systemGray5))
            Image(systemName: "gamecontroller.fill")
                .foregroundStyle(.secondary)
                .font(.title2)
        }
    }
}
#endif
