//
//  RecentlyPlayedWidget.swift
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

struct RecentlyPlayedEntry: TimelineEntry {
    let date: Date
    let games: [WidgetGameEntry]
    let isPlaceholder: Bool

    static var placeholder: RecentlyPlayedEntry {
        RecentlyPlayedEntry(date: Date(), games: [], isPlaceholder: true)
    }
}

// MARK: - Provider

struct RecentlyPlayedProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentlyPlayedEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentlyPlayedEntry) -> Void) {
        let limit = gameLimit(for: context.family)
        let games = WidgetSharedDefaults.loadRecentGamesWithArtwork(limit: limit)
        completion(RecentlyPlayedEntry(date: Date(), games: games, isPlaceholder: context.isPreview && games.isEmpty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentlyPlayedEntry>) -> Void) {
        let limit = gameLimit(for: context.family)
        let games = WidgetSharedDefaults.loadRecentGamesWithArtwork(limit: limit)
        let entry = RecentlyPlayedEntry(date: Date(), games: games, isPlaceholder: false)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func gameLimit(for family: WidgetFamily) -> Int {
        RecentlyPlayedWidgetGameCounts.limit(for: family)
    }
}

// MARK: - Layout metrics

/// Row counts per widget family; kept in sync with timeline `gameLimit` so layout matches loaded entries.
private enum RecentlyPlayedWidgetGameCounts {
    static func limit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 3
        case .systemLarge: return 4
        case .systemExtraLarge: return 8
        default: return 2
        }
    }
}

/// Padding, spacing, corner radii, and typography hints for Recently Played across widget families.
struct RecentlyPlayedWidgetLayoutMetrics {
    let contentPadding: CGFloat
    let rowSpacing: CGFloat
    let rowCardCornerRadius: CGFloat
    let artworkCornerRadius: CGFloat
    let listArtworkSide: CGFloat
    let titleLineLimit: Int
    let heroArtworkCornerRadius: CGFloat
    let heroTitleFont: Font
    let listTitleFont: Font
    let rowHorizontalPadding: CGFloat
    let rowVerticalPadding: CGFloat

    /// Returns layout tuned for small through extra-large while keeping the same per-family game limits.
    static func metrics(for family: WidgetFamily) -> RecentlyPlayedWidgetLayoutMetrics {
        switch family {
        case .systemSmall:
            return RecentlyPlayedWidgetLayoutMetrics(
                contentPadding: 8,
                rowSpacing: 0,
                rowCardCornerRadius: 14,
                artworkCornerRadius: 8,
                listArtworkSide: 48,
                titleLineLimit: 2,
                heroArtworkCornerRadius: 14,
                heroTitleFont: .system(.subheadline, design: .rounded).weight(.bold),
                listTitleFont: .system(.subheadline, design: .rounded).weight(.semibold),
                rowHorizontalPadding: 10,
                rowVerticalPadding: 8
            )
        case .systemMedium:
            return RecentlyPlayedWidgetLayoutMetrics(
                contentPadding: 6,
                rowSpacing: 6,
                rowCardCornerRadius: 10,
                artworkCornerRadius: 7,
                listArtworkSide: 38,
                titleLineLimit: 2,
                heroArtworkCornerRadius: 12,
                heroTitleFont: .system(.subheadline, design: .rounded).weight(.bold),
                listTitleFont: .system(.caption2, design: .rounded).weight(.semibold),
                rowHorizontalPadding: 8,
                rowVerticalPadding: 5
            )
        case .systemLarge:
            return RecentlyPlayedWidgetLayoutMetrics(
                contentPadding: 12,
                rowSpacing: 8,
                rowCardCornerRadius: 12,
                artworkCornerRadius: 9,
                listArtworkSide: 56,
                titleLineLimit: 2,
                heroArtworkCornerRadius: 14,
                heroTitleFont: .system(.subheadline, design: .rounded).weight(.bold),
                listTitleFont: .system(.caption, design: .rounded).weight(.semibold),
                rowHorizontalPadding: 10,
                rowVerticalPadding: 8
            )
        case .systemExtraLarge:
            return RecentlyPlayedWidgetLayoutMetrics(
                contentPadding: 14,
                rowSpacing: 8,
                rowCardCornerRadius: 14,
                artworkCornerRadius: 10,
                listArtworkSide: 58,
                titleLineLimit: 2,
                heroArtworkCornerRadius: 14,
                heroTitleFont: .system(.subheadline, design: .rounded).weight(.bold),
                listTitleFont: .system(.caption, design: .rounded).weight(.semibold),
                rowHorizontalPadding: 10,
                rowVerticalPadding: 8
            )
        default:
            return .metrics(for: .systemMedium)
        }
    }
}

// MARK: - Widget

struct RecentlyPlayedWidget: Widget {
    let kind: String = "RecentlyPlayedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentlyPlayedProvider()) { entry in
            RecentlyPlayedWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    RecentlyPlayedWidgetContainerBackground()
                }
                // Tapping outside any Link row (e.g. padding) opens the most recent game.
                .widgetURL(entry.games.first(where: { !$0.id.isEmpty && $0.launchURL != nil })?.launchURL ?? PVLibraryScreenURL)
        }
        .configurationDisplayName("Recently Played")
        .description("See the games you've played most recently.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

/// Dark RetroWave base with a soft neon wash matching other Provenance widgets.
private struct RecentlyPlayedWidgetContainerBackground: View {
    var body: some View {
        ZStack {
            RetroWaveWidgetPalette.retroBlack
            RetroWaveWidgetGradients.mainNeon.opacity(0.2)
        }
    }
}

// MARK: - Views

struct RecentlyPlayedWidgetView: View {
    let entry: RecentlyPlayedEntry

    @Environment(\.widgetFamily) private var family

    private var layoutMetrics: RecentlyPlayedWidgetLayoutMetrics {
        RecentlyPlayedWidgetLayoutMetrics.metrics(for: family)
    }

    var body: some View {
        if entry.isPlaceholder || entry.games.isEmpty {
            placeholderView
        } else {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumGridView
            case .systemLarge:
                largeGridView
            case .systemExtraLarge:
                extraLargeGridView
            default:
                mediumGridView
            }
        }
    }

    // MARK: Small — single hero card

    private var smallView: some View {
        Group {
            if let game = entry.games.first, let url = game.launchURL {
                Link(destination: url) {
                    smallHeroCard(game: game)
                }
            } else {
                emptyStateView
            }
        }
        .padding(layoutMetrics.contentPadding)
    }

    private func smallHeroCard(game: WidgetGameEntry) -> some View {
        let m = layoutMetrics
        return ZStack(alignment: .bottomLeading) {
            GameArtworkView(artworkData: game.artworkData, cornerRadius: m.heroArtworkCornerRadius)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            LinearGradient(
                colors: [
                    RetroWaveWidgetPalette.retroBlack.opacity(0.1),
                    RetroWaveWidgetPalette.retroBlack.opacity(0.88)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 6) {
                Text(game.title)
                    .font(m.heroTitleFont)
                    .foregroundStyle(RetroWaveWidgetTypography.titleForeground)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)
                recentlyPlayedMetaRow(game: game, compact: true)
            }
            .padding(10)
        }
        .clipShape(RoundedRectangle(cornerRadius: m.heroArtworkCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: m.heroArtworkCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            RetroWaveWidgetPalette.neonPink.opacity(0.45),
                            RetroWaveWidgetPalette.neonCyan.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: Medium / Large / Extra Large — grid

    private var mediumGridView: some View {
        recentlyPlayedWideGrid(for: .systemMedium)
    }

    private var largeGridView: some View {
        recentlyPlayedWideGrid(for: .systemLarge)
    }

    private var extraLargeGridView: some View {
        recentlyPlayedWideGrid(for: .systemExtraLarge)
    }

    /// Lays out recent games in a flexible `LazyVGrid` so medium through extra-large widgets use horizontal space instead of a single full-width column.
    private func recentlyPlayedWideGrid(for gridFamily: WidgetFamily) -> some View {
        let limit = RecentlyPlayedWidgetGameCounts.limit(for: gridFamily)
        let games = Array(entry.games.prefix(limit))
        let columns = RecentlyPlayedGridColumnSpec.columnCount(for: gridFamily, itemCount: games.count)
        let m = layoutMetrics
        let spacing = m.rowSpacing

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(games) { game in
                recentlyPlayedGridCell(game: game)
            }
        }
        .padding(m.contentPadding)
    }

    // MARK: Grid cell (vertical: artwork, title, meta)

    /// Single grid cell: square artwork on top, title and metadata below; artwork fills the cell width.
    @ViewBuilder
    private func recentlyPlayedGridCell(game: WidgetGameEntry) -> some View {
        let m = layoutMetrics
        let inner = VStack(alignment: .leading, spacing: 5) {
            GameArtworkView(artworkData: game.artworkData, cornerRadius: m.artworkCornerRadius)
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
            Text(game.title)
                .font(m.listTitleFont)
                .foregroundStyle(RetroWaveWidgetTypography.titleForeground)
                .lineLimit(m.titleLineLimit)
                .minimumScaleFactor(0.82)
                .multilineTextAlignment(.leading)
            recentlyPlayedMetaRow(game: game, compact: true)
        }
        .padding(.horizontal, m.rowHorizontalPadding)
        .padding(.vertical, m.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .retroWaveWidgetGridCellSurface(cornerRadius: m.rowCardCornerRadius)

        if let url = game.launchURL {
            Link(destination: url) {
                inner
            }
        } else {
            inner.opacity(0.45)
        }
    }

    /// Single-line metadata: optional system badge, dot separator, and optional relative last-played time (`compact` tightens spacing).
    @ViewBuilder
    private func recentlyPlayedMetaRow(game: WidgetGameEntry, compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: compact ? 5 : 6) {
            if Self.hasMeaningfulSystemBadge(game.systemShortName) {
                SystemBadgeView(systemShortName: game.systemShortName, chrome: .retroWaveNeon)
            }
            if let playedDate = game.lastPlayedDate {
                if Self.hasMeaningfulSystemBadge(game.systemShortName) {
                    Text("·")
                        .retroWaveWidgetMetaStyle()
                        .opacity(0.7)
                }
                Text(playedDate, style: .relative)
                    .retroWaveWidgetMetaStyle()
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// True when the system abbreviation should be shown (avoids empty badges / `???` noise).
    private static func hasMeaningfulSystemBadge(_ shortName: String) -> Bool {
        !shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Placeholder

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "gamecontroller.fill")
                .font(.largeTitle)
                .foregroundStyle(RetroWaveWidgetPalette.neonCyan.opacity(0.65))
            Text("No Recent Games")
                .retroWaveWidgetMetaStyle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ZStack {
            RetroWaveWidgetPalette.retroBlack.opacity(0.35)
            VStack(spacing: 6) {
                Image(systemName: "gamecontroller")
                    .font(.title2)
                    .foregroundStyle(RetroWaveWidgetPalette.neonCyan.opacity(0.7))
                Text("Play a game\nto see it here")
                    .multilineTextAlignment(.center)
                    .retroWaveWidgetMetaStyle()
            }
        }
    }
}

/// Column counts for `LazyVGrid` on medium (1–3), large (2×2 for 3–4 items), and extra-large (4-wide band).
private enum RecentlyPlayedGridColumnSpec {
    static func columnCount(for family: WidgetFamily, itemCount: Int) -> Int {
        let n = max(1, itemCount)
        switch family {
        case .systemMedium:
            return min(3, n)
        case .systemLarge:
            if n <= 2 { return n }
            return 2
        case .systemExtraLarge:
            return 4
        default:
            return min(2, n)
        }
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    RecentlyPlayedWidget()
} timeline: {
    RecentlyPlayedEntry.placeholder
}

#Preview("Medium", as: .systemMedium) {
    RecentlyPlayedWidget()
} timeline: {
    RecentlyPlayedEntry.placeholder
}

#Preview("Large", as: .systemLarge) {
    RecentlyPlayedWidget()
} timeline: {
    RecentlyPlayedEntry.placeholder
}

#Preview("Extra Large", as: .systemExtraLarge) {
    RecentlyPlayedWidget()
} timeline: {
    RecentlyPlayedEntry.placeholder
}
#endif
