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
import WidgetKit

// MARK: - Timeline Entry

struct GameArtGalleryEntry: TimelineEntry {
    let date: Date
    let game: WidgetGameEntry?
    let gameCount: Int
}

// MARK: - Timeline Provider

struct GameArtGalleryProvider: TimelineProvider {
    func placeholder(in context: Context) -> GameArtGalleryEntry {
        GameArtGalleryEntry(date: Date(), game: nil, gameCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (GameArtGalleryEntry) -> Void) {
        let games = WidgetSharedDefaults.loadGalleryGames()
        let entry = GameArtGalleryEntry(
            date: Date(),
            game: games.first,
            gameCount: WidgetSharedDefaults.loadGameCount()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GameArtGalleryEntry>) -> Void) {
        let games = WidgetSharedDefaults.loadGalleryGames()
        let gameCount = WidgetSharedDefaults.loadGameCount()
        let now = Date()

        guard !games.isEmpty else {
            let entry = GameArtGalleryEntry(date: now, game: nil, gameCount: gameCount)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
            return
        }

        // Rotate through gallery games, one every 5 minutes
        var entries: [GameArtGalleryEntry] = []
        let rotationInterval = 5 // minutes

        for (index, game) in games.prefix(12).enumerated() {
            let entryDate = Calendar.current.date(
                byAdding: .minute,
                value: index * rotationInterval,
                to: now
            ) ?? now
            entries.append(GameArtGalleryEntry(date: entryDate, game: game, gameCount: gameCount))
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
        .widgetURL(URL(string: "provenance://library"))
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let game = entry.game, let path = game.artworkPath,
           let url = WidgetSharedDefaults.artworkURL(forRelativePath: path),
           let uiImage = UIImage(contentsOfFile: url.path) {
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
        gameCount: 42
    )
}
#endif
