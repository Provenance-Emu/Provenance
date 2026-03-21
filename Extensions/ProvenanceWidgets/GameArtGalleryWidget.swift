//
//  GameArtGalleryWidget.swift
//  ProvenanceWidgets
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

/// StandBy-mode Game Art Gallery widget.
/// Displays a rotating, full-screen game box-art image from the library.
/// Uses `.systemSmall` rendered in StandBy's full-screen context.
/// Requires `.containerBackground` for StandBy compatibility (iOS 17+).

#if os(iOS)
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Timeline Entry

struct GameArtGalleryEntry: TimelineEntry {
    let date: Date
    let game: WidgetGameEntry?
    let gameCount: Int
    /// Pre-loaded artwork bytes; nil when no game is available or artwork is missing.
    /// Populated by the timeline provider to avoid synchronous disk I/O during view rendering.
    let artworkImageData: Data?
}

// MARK: - Timeline Provider

struct GameArtGalleryProvider: TimelineProvider {
    func placeholder(in context: Context) -> GameArtGalleryEntry {
        GameArtGalleryEntry(date: Date(), game: nil, gameCount: 0, artworkImageData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (GameArtGalleryEntry) -> Void) {
        let games = WidgetSharedDefaults.loadGalleryGames()
        let game = games.first
        let imageData = game?.artworkPath.flatMap { WidgetSharedDefaults.artworkData(forRelativePath: $0) }
        let entry = GameArtGalleryEntry(
            date: Date(),
            game: game,
            gameCount: WidgetSharedDefaults.loadGameCount(),
            artworkImageData: imageData
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GameArtGalleryEntry>) -> Void) {
        let games = WidgetSharedDefaults.loadGalleryGames()
        let gameCount = WidgetSharedDefaults.loadGameCount()
        let now = Date()

        guard !games.isEmpty else {
            let entry = GameArtGalleryEntry(date: now, game: nil, gameCount: gameCount, artworkImageData: nil)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
            return
        }

        // Rotate through gallery games, one every 5 minutes.
        // Image data is pre-loaded here so view rendering avoids synchronous disk I/O.
        var entries: [GameArtGalleryEntry] = []
        let rotationInterval = 5 // minutes

        for (index, game) in games.prefix(12).enumerated() {
            let entryDate = Calendar.current.date(
                byAdding: .minute,
                value: index * rotationInterval,
                to: now
            ) ?? now
            let imageData = game.artworkPath.flatMap { WidgetSharedDefaults.artworkData(forRelativePath: $0) }
            entries.append(GameArtGalleryEntry(date: entryDate, game: game, gameCount: gameCount, artworkImageData: imageData))
        }

        // Loop back: after the last game, start over from the first
        let loopDate = Calendar.current.date(
            byAdding: .minute,
            value: entries.count * rotationInterval,
            to: now
        ) ?? now
        completion(Timeline(entries: entries, policy: .after(loopDate)))
    }
}

// MARK: - Views

struct GameArtGalleryView: View {
    let entry: GameArtGalleryEntry

    var body: some View {
        ZStack(alignment: .bottom) {
            artworkBackground
            titleOverlay
        }
        .containerBackground(.black, for: .widget)
        .widgetURL(URL(string: "provenance://screen/library"))
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let data = entry.artworkImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        } else {
            ZStack {
                Color.black
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Provenance")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
    }

    @ViewBuilder
    private var titleOverlay: some View {
        if let game = entry.game {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(game.systemName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(0.5))
        }
    }
}

// MARK: - Widget

struct GameArtGalleryWidget: Widget {
    static let kind = "com.provenance-emu.widget.artgallery"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: GameArtGalleryProvider()) { entry in
            GameArtGalleryView(entry: entry)
        }
        .configurationDisplayName("Game Art Gallery")
        .description("Rotates through your game library art in StandBy mode.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    GameArtGalleryWidget()
} timeline: {
    GameArtGalleryEntry(
        date: Date(),
        game: WidgetGameEntry(
            id: "preview",
            title: "The Legend of Zelda",
            systemName: "NES",
            artworkPath: nil
        ),
        gameCount: 42,
        artworkImageData: nil
    )
}
#endif
