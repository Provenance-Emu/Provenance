//
//  GameArtworkView.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import SwiftUI

/// Displays box art for a game from a local file path or falls back to a system-icon placeholder.
struct GameArtworkView: View {
    let entry: WidgetGameEntry
    let cornerRadius: CGFloat

    init(entry: WidgetGameEntry, cornerRadius: CGFloat = 8) {
        self.entry = entry
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let artworkPath = entry.artworkPath,
               let uiImage = UIImage(contentsOfFile: artworkPath) {
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
