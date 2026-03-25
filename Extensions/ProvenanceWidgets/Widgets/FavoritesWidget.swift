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
import PVLibrary

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
        case .systemExtraLarge: return 16
        default: return 4
        }
    }
}

// MARK: - Layout

/// Padding, grid gaps, corner radii, and title styling scaled per widget size for a consistent rhythm across families.
struct FavoritesWidgetLayoutMetrics {
    let contentPadding: CGFloat
    let gridSpacing: CGFloat
    let tileCornerRadius: CGFloat
    let artworkTitleFont: Font
    let overlayHorizontalPadding: CGFloat
    let overlayVerticalPadding: CGFloat

    /// Returns layout values aligned to small through extra-large sizes while preserving the same grid item counts.
    static func metrics(for family: WidgetFamily) -> FavoritesWidgetLayoutMetrics {
        switch family {
        case .systemSmall:
            return FavoritesWidgetLayoutMetrics(
                contentPadding: 8,
                gridSpacing: 0,
                tileCornerRadius: 10,
                artworkTitleFont: .system(.subheadline, design: .rounded).weight(.bold),
                overlayHorizontalPadding: 8,
                overlayVerticalPadding: 6
            )
        case .systemMedium:
            return FavoritesWidgetLayoutMetrics(
                contentPadding: 10,
                gridSpacing: 8,
                tileCornerRadius: 10,
                artworkTitleFont: .system(.caption, design: .rounded).weight(.semibold),
                overlayHorizontalPadding: 6,
                overlayVerticalPadding: 4
            )
        case .systemLarge:
            return FavoritesWidgetLayoutMetrics(
                contentPadding: 12,
                gridSpacing: 10,
                tileCornerRadius: 12,
                artworkTitleFont: .system(.caption, design: .rounded).weight(.semibold),
                overlayHorizontalPadding: 6,
                overlayVerticalPadding: 5
            )
        case .systemExtraLarge:
            return FavoritesWidgetLayoutMetrics(
                contentPadding: 14,
                gridSpacing: 12,
                tileCornerRadius: 12,
                artworkTitleFont: .system(.callout, design: .rounded).weight(.semibold),
                overlayHorizontalPadding: 8,
                overlayVerticalPadding: 6
            )
        default:
            return .metrics(for: .systemMedium)
        }
    }
}

// MARK: - Widget

struct FavoritesWidget: Widget {
    let kind: String = "FavoritesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoritesProvider()) { entry in
            FavoritesWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    FavoritesWidgetContainerBackground()
                }
                // Tapping outside any Link cell (e.g. padding) opens the first game.
                .widgetURL(entry.games.first?.launchURL ?? PVLibraryScreenURL)
        }
        .configurationDisplayName("Favorites")
        .description("Quick access to your favourite games.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

/// Dark RetroWave base with a soft neon wash for the favorites widget chrome.
private struct FavoritesWidgetContainerBackground: View {
    var body: some View {
        ZStack {
            RetroWaveWidgetPalette.retroBlack
            RetroWaveWidgetGradients.mainNeon.opacity(0.2)
        }
    }
}

// MARK: - Views

struct FavoritesWidgetView: View {
    let entry: FavoritesEntry

    @Environment(\.widgetFamily) private var family

    private var layoutMetrics: FavoritesWidgetLayoutMetrics {
        FavoritesWidgetLayoutMetrics.metrics(for: family)
    }

    var body: some View {
        if entry.isPlaceholder || entry.games.isEmpty {
            emptyStateView
        } else {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                gridView(columns: 2, rows: 2)
            case .systemLarge:
                gridView(columns: 4, rows: 2)
            case .systemExtraLarge:
                gridView(columns: 4, rows: 4)
            default:
                gridView(columns: 2, rows: 2)
            }
        }
    }

    // MARK: Small — single game

    private var smallView: some View {
        Group {
            if let game = entry.games.first {
                gameButton(game)
            }
        }
        .padding(layoutMetrics.contentPadding)
    }

    // MARK: Grid layouts

    private func gridView(columns: Int, rows: Int) -> some View {
        let total = columns * rows
        let games = paddedGames(count: total)
        let spacing = layoutMetrics.gridSpacing
        let padding = layoutMetrics.contentPadding

        return GeometryReader { geo in
            let cellW = (geo.size.width - 2 * padding - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            let cellH = (geo.size.height - 2 * padding - CGFloat(rows - 1) * spacing) / CGFloat(rows)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellW), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                ForEach(games) { game in
                    gameButton(game)
                        .frame(width: cellW, height: cellH)
                }
            }
            .padding(padding)
        }
    }

    // MARK: Game cell

    private func gameButton(_ game: WidgetGameEntry) -> some View {
        let metrics = layoutMetrics
        return Group {
            if game.md5Hash.isEmpty {
                ZStack {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .retroWaveWidgetGridCellSurface(cornerRadius: metrics.tileCornerRadius)
                    Image(systemName: "star")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RetroWaveWidgetPalette.neonCyan.opacity(0.45))
                }
            } else if let url = game.launchURL {
                Link(destination: url) {
                    GameArtworkView(artworkData: game.artworkData, cornerRadius: metrics.tileCornerRadius)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .topLeading) {
                            SystemBadgeView(systemShortName: game.systemShortName, chrome: .retroWaveNeon)
                                .padding(.leading, 6)
                                .padding(.top, 6)
                        }
                        .overlay(alignment: .bottom) {
                            favoritesArtworkTitleBar(title: game.title, metrics: metrics)
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: Empty state

    private var emptyStateView: some View {
        let metrics = layoutMetrics
        return VStack(spacing: metrics.contentPadding) {
            Image(systemName: "star.fill")
                .font(.title)
                .foregroundStyle(RetroWaveWidgetPalette.neonYellow)
                .shadow(color: RetroWaveWidgetPalette.neonPink.opacity(0.55), radius: 5, x: 0, y: 0)
            Text("No Favorites")
                .retroWaveWidgetTitleStyle()
            Text("Mark games as\nfavorites to see them here")
                .multilineTextAlignment(.center)
                .retroWaveWidgetMetaStyle()
        }
        .padding(metrics.contentPadding + 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .retroWaveWidgetSectionSurface(cornerRadius: max(10, metrics.tileCornerRadius * 0.85))
        .padding(metrics.contentPadding)
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

// MARK: - Artwork title overlay

/// Bottom-aligned title strip with a strong scrim and shadow so names stay readable on busy artwork.
private func favoritesArtworkTitleBar(title: String, metrics: FavoritesWidgetLayoutMetrics) -> some View {
    VStack(spacing: 0) {
        Spacer(minLength: 0)
        Text(title)
            .font(metrics.artworkTitleFont)
            .foregroundStyle(Color.white)
            .shadow(color: Color.black.opacity(0.92), radius: 4, x: 0, y: 1)
            .shadow(color: Color.black.opacity(0.55), radius: 1, x: 0, y: 0)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, metrics.overlayHorizontalPadding)
            .padding(.vertical, metrics.overlayVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(favoritesArtworkTitleScrim())
    }
}

/// Multi-stop vertical scrim under artwork titles for higher contrast than a single gradient stop.
private func favoritesArtworkTitleScrim() -> LinearGradient {
    LinearGradient(
        colors: [
            Color.black.opacity(0),
            Color.black.opacity(0.38),
            Color.black.opacity(0.78),
            Color.black.opacity(0.94)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
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
