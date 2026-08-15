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
import PVLibrary

// MARK: - Timeline Entry

struct GameArtGalleryEntry: TimelineEntry {
    let date: Date
    let game: WidgetGameEntry?
    let gameCount: Int
}

// MARK: - Timeline Provider

/// Rotation cadence and depth for the gallery timeline.
private enum GameArtGalleryTimeline {
    /// Minutes each game stays on screen before the next entry becomes current.
    static let rotationIntervalMinutes = 5

    /// Number of games in one timeline pass.
    ///
    /// Entries carry only an artwork *path*, so this no longer multiplies the encoded
    /// bytes held in the timeline. It does still multiply decode work: WidgetKit renders
    /// every entry in one burst, so peak decoded memory is `entryCount × the budget the
    /// view asks for` — which is why `GameArtGalleryView` does not take the `hero`
    /// budget the way other single-cover widgets do.
    static let entryCount = 12

    /// Fallback refresh when the library has no games to show.
    static let emptyLibraryRefreshMinutes = 30
}

struct GameArtGalleryProvider: TimelineProvider {
    func placeholder(in context: Context) -> GameArtGalleryEntry {
        GameArtGalleryEntry(date: Date(), game: nil, gameCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (GameArtGalleryEntry) -> Void) {
        let entry = GameArtGalleryEntry(
            date: Date(),
            game: WidgetSharedDefaults.loadGalleryGames().first,
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
            let nextUpdate = Calendar.current.date(
                byAdding: .minute,
                value: GameArtGalleryTimeline.emptyLibraryRefreshMinutes,
                to: now
            ) ?? now
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
            return
        }

        // Rotate through gallery games. Entries hold an identifier and an artwork path,
        // never image bytes: WidgetKit keeps the whole timeline resident while it renders,
        // so a `Data` payload here would be multiplied by `entryCount`.
        let entries = games.prefix(GameArtGalleryTimeline.entryCount).enumerated().map { index, game in
            let entryDate = Calendar.current.date(
                byAdding: .minute,
                value: index * GameArtGalleryTimeline.rotationIntervalMinutes,
                to: now
            ) ?? now
            return GameArtGalleryEntry(date: entryDate, game: game, gameCount: gameCount)
        }

        // Loop back: after the last game, start over from the first
        let loopDate = Calendar.current.date(
            byAdding: .minute,
            value: entries.count * GameArtGalleryTimeline.rotationIntervalMinutes,
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
        .widgetURL(PVLibraryScreenURL)
    }

    /// The gallery draws one cover full-bleed, but unlike the other single-cover widgets
    /// it does *not* take the `hero` budget: WidgetKit renders all
    /// `GameArtGalleryTimeline.entryCount` entries in one burst, so the cost of this
    /// decode is paid `entryCount` times over.
    ///
    /// `gridCell` (768) is the smallest budget that still covers a `.systemSmall` panel
    /// with no upscale — 170pt × 3 × 1.5 ≈ 765 — and holds the pass to
    /// 12 × 768 × 576 × 4 B ≈ 21 MB instead of ≈37 MB at `hero`.
    private var artworkImage: UIImage? {
        guard let path = entry.game?.artworkPath else { return nil }
        return WidgetSharedDefaults.artworkImage(
            forRelativePath: path,
            maxPixelSize: WidgetArtworkPixelBudget.gridCell
        )
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let uiImage = artworkImage {
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
                    Text(WidgetLocalizedStrings.brandName)
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
        .configurationDisplayName(String(localized: "widget.game-art-gallery.display-name", defaultValue: "Game Art Gallery", comment: "Game Art Gallery widget display name"))
        .description(String(localized: "widget.game-art-gallery.description", defaultValue: "Rotates through your game library art in StandBy mode.", comment: "Game Art Gallery widget description"))
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
