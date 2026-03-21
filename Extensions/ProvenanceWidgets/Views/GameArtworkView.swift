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
            // artworkData is loaded at provider time (getTimeline/getSnapshot), so this
            // call is cheap — no disk I/O occurs during widget rendering.
            if let data = entry.artworkData,
               let uiImage = UIImage(data: data) {
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
