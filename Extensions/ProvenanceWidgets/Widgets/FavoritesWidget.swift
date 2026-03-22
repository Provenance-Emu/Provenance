//
//  FavoritesWidget.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import WidgetKit
import SwiftUI

// MARK: - Entry

struct FavoritesEntry: TimelineEntry {
    let date: Date
    let games: [WidgetGameEntry]
    let isPlaceholder: Bool

    static var placeholder: FavoritesEntry {
        FavoritesEntry(date: Date(), games: [], isPlaceholder: true)
    }
}

// MARK: - Provider

struct FavoritesProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
        let limit = gameLimit(for: context.family)
        let games = WidgetSharedDefaults.loadFavoriteGamesWithArtwork(limit: limit)
        completion(FavoritesEntry(date: Date(), games: games, isPlaceholder: context.isPreview && games.isEmpty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
        let limit = gameLimit(for: context.family)
        let games = WidgetSharedDefaults.loadFavoriteGamesWithArtwork(limit: limit)
        let entry = FavoritesEntry(date: Date(), games: games, isPlaceholder: false)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func gameLimit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 4
        case .systemLarge: return 8
        case .systemExtraLarge: return 8
        default: return 4
        }
    }
}

// MARK: - Widget

struct FavoritesWidget: Widget {
    let kind: String = "FavoritesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesProvider()) { entry in
            FavoritesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favorites")
        .description("Quick access to your favourite games.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Views

struct FavoritesWidgetView: View {
    let entry: FavoritesEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.isPlaceholder || entry.games.isEmpty {
            emptyStateView
        } else {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                gridView(columns: 2, rows: 2)
            case .systemLarge, .systemExtraLarge:
                gridView(columns: 4, rows: 2)
            default:
                gridView(columns: 2, rows: 2)
            }
        }
    }

    // MARK: Small — single tile

    private var smallView: some View {
        Group {
            if let game = entry.games.first {
                gameButton(game)
            }
        }
    }

    // MARK: Grid layouts

    private func gridView(columns: Int, rows: Int) -> some View {
        let total = columns * rows
        let games = paddedGames(count: total)

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns),
            spacing: 8
        ) {
            ForEach(games) { game in
                gameButton(game)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .padding(10)
    }

    // MARK: Tile

    private func gameButton(_ game: WidgetGameEntry) -> some View {
        Group {
            if game.md5Hash.isEmpty {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemGray5).opacity(0.5))
            } else if let url = game.launchURL {
                Link(destination: url) {
                    GameArtworkView(artworkData: game.artworkData, cornerRadius: 8)
                        .overlay(alignment: .bottom) {
                            Text(game.title)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 4)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .background(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.65)],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )
                                )
                        }
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.largeTitle)
                .foregroundStyle(.yellow)
            Text("No Favorites")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Mark games as\nfavorites to see them here")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Helpers

    private func paddedGames(count: Int) -> [WidgetGameEntry] {
        let games = Array(entry.games.prefix(count))
        if games.count == count { return games }
        let padding = (games.count..<count).map {
            WidgetGameEntry(id: "pad-\($0)", title: "", systemName: "")
        }
        return games + padding
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    FavoritesWidget()
} timeline: {
    FavoritesEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    FavoritesWidget()
} timeline: {
    FavoritesEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    FavoritesWidget()
} timeline: {
    FavoritesEntry.placeholder
}
#endif
