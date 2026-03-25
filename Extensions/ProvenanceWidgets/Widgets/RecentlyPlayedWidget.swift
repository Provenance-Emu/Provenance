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

    /// Returns layout tuned for small through extra-large while keeping the same per-family game counts.
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
                rowSpacing: 4,
                rowCardCornerRadius: 10,
                artworkCornerRadius: 7,
                listArtworkSide: 38,
                titleLineLimit: 2,
                heroArtworkCornerRadius: 12,
                heroTitleFont: .system(.subheadline, design: .rounded).weight(.bold),
                listTitleFont: .system(.caption, design: .rounded).weight(.semibold),
                rowHorizontalPadding: 8,
                rowVerticalPadding: 5
            )
        case .systemLarge:
            return RecentlyPlayedWidgetLayoutMetrics(
                contentPadding: 12,
                rowSpacing: 9,
                rowCardCornerRadius: 12,
                artworkCornerRadius: 9,
                listArtworkSide: 56,
                titleLineLimit: 2,
                heroArtworkCornerRadius: 14,
                heroTitleFont: .system(.subheadline, design: .rounded).weight(.bold),
                listTitleFont: .system(.body, design: .rounded).weight(.semibold),
                rowHorizontalPadding: 10,
                rowVerticalPadding: 8
            )
        case .systemExtraLarge:
            return RecentlyPlayedWidgetLayoutMetrics(
                contentPadding: 14,
                rowSpacing: 10,
                rowCardCornerRadius: 14,
                artworkCornerRadius: 10,
                listArtworkSide: 58,
                titleLineLimit: 2,
                heroArtworkCornerRadius: 14,
                heroTitleFont: .system(.subheadline, design: .rounded).weight(.bold),
                listTitleFont: .system(.body, design: .rounded).weight(.semibold),
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
                .widgetURL(entry.games.first?.launchURL ?? PVLibraryScreenURL)
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
                mediumView
            case .systemLarge:
                largeView
            case .systemExtraLarge:
                extraLargeView
            default:
                mediumView
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

    // MARK: Medium — stacked rows (full-width titles)

    private var mediumView: some View {
        VStack(spacing: layoutMetrics.rowSpacing) {
            ForEach(paddedGames(count: RecentlyPlayedWidgetGameCounts.limit(for: .systemMedium))) { game in
                recentlyPlayedRow(game: game)
            }
        }
        .padding(layoutMetrics.contentPadding)
    }

    // MARK: Large — four stacked rows

    private var largeView: some View {
        VStack(spacing: layoutMetrics.rowSpacing) {
            ForEach(paddedGames(count: 4)) { game in
                recentlyPlayedRow(game: game)
            }
        }
        .padding(layoutMetrics.contentPadding)
    }

    // MARK: Extra Large — two columns of four

    private var extraLargeView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: layoutMetrics.rowSpacing) {
                ForEach(paddedGames(count: 8).prefix(4)) { game in
                    recentlyPlayedRow(game: game)
                }
            }
            retroWaveColumnDivider
            VStack(spacing: layoutMetrics.rowSpacing) {
                ForEach(paddedGames(count: 8).dropFirst(4)) { game in
                    recentlyPlayedRow(game: game)
                }
            }
        }
        .padding(layoutMetrics.contentPadding)
    }

    private var retroWaveColumnDivider: some View {
        Rectangle()
            .fill(RetroWaveWidgetPalette.neonPurple.opacity(0.4))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    // MARK: Row

    @ViewBuilder
    private func recentlyPlayedRow(game: WidgetGameEntry) -> some View {
        let inner = recentlyPlayedRowContent(game: game)
        if let url = game.launchURL {
            Link(destination: url) {
                inner
            }
        } else {
            inner.opacity(0.45)
        }
    }

    private func recentlyPlayedRowContent(game: WidgetGameEntry) -> some View {
        let m = layoutMetrics
        return HStack(alignment: .center, spacing: 10) {
            GameArtworkView(artworkData: game.artworkData, cornerRadius: m.artworkCornerRadius)
                .frame(width: m.listArtworkSide, height: m.listArtworkSide)
            VStack(alignment: .leading, spacing: 5) {
                Text(game.title)
                    .font(m.listTitleFont)
                    .foregroundStyle(RetroWaveWidgetTypography.titleForeground)
                    .lineLimit(m.titleLineLimit)
                    .minimumScaleFactor(0.86)
                    .multilineTextAlignment(.leading)
                recentlyPlayedMetaRow(game: game, compact: false)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, m.rowHorizontalPadding)
        .padding(.vertical, m.rowVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .retroWaveWidgetGridCellSurface(cornerRadius: m.rowCardCornerRadius)
    }

    /// Single-line metadata: system badge, dot separator, and optional relative last-played time (`compact` tightens spacing).
    @ViewBuilder
    private func recentlyPlayedMetaRow(game: WidgetGameEntry, compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: compact ? 5 : 6) {
            SystemBadgeView(systemShortName: game.systemShortName, chrome: .retroWaveNeon)
            if let playedDate = game.lastPlayedDate {
                Text("·")
                    .retroWaveWidgetMetaStyle()
                    .opacity(0.7)
                Text(playedDate, style: .relative)
                    .retroWaveWidgetMetaStyle()
            }
        }
        .accessibilityElement(children: .combine)
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

    // MARK: Helpers

    private func paddedGames(count: Int) -> [WidgetGameEntry] {
        let games = Array(entry.games.prefix(count))
        if games.count == count { return games }
        let padding = (games.count..<count).map {
            WidgetGameEntry(id: "placeholder-\($0)", title: "—", systemName: "")
        }
        return games + padding
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
