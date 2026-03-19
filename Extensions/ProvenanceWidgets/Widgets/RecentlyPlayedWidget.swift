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

// MARK: - Provider

struct RecentlyPlayedProvider: TimelineProvider {
    private let dataProvider = WidgetDataProvider()

    func placeholder(in context: Context) -> RecentlyPlayedEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentlyPlayedEntry) -> Void) {
        let limit = gameLimit(for: context.family)
        let games = dataProvider.recentGames(limit: limit)
        completion(RecentlyPlayedEntry(date: Date(), games: games, isPlaceholder: context.isPreview && games.isEmpty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentlyPlayedEntry>) -> Void) {
        let limit = gameLimit(for: context.family)
        let games = dataProvider.recentGames(limit: limit)
        let entry = RecentlyPlayedEntry(date: Date(), games: games, isPlaceholder: false)
        // Refresh every 15 minutes; the main app also calls WidgetCenter.reloadTimelines on game launch/end
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func gameLimit(for family: WidgetFamily) -> Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 2
        case .systemLarge: return 4
        default: return 2
        }
    }
}

// MARK: - Widget

struct RecentlyPlayedWidget: Widget {
    let kind: String = "RecentlyPlayedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentlyPlayedProvider()) { entry in
            RecentlyPlayedWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recently Played")
        .description("See the games you've played most recently.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Views

struct RecentlyPlayedWidgetView: View {
    let entry: RecentlyPlayedEntry

    @Environment(\.widgetFamily) private var family

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
            default:
                mediumView
            }
        }
    }

    // MARK: Small — single game

    private var smallView: some View {
        Group {
            if let game = entry.games.first {
                Link(destination: game.launchURL ?? URL(string: "provenance://")!) {
                    ZStack(alignment: .bottomLeading) {
                        GameArtworkView(entry: game, cornerRadius: 12)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        VStack(alignment: .leading, spacing: 2) {
                            SystemBadgeView(systemShortName: game.systemShortName)
                            Text(game.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if let playedDate = game.lastPlayedDate {
                                Text(playedDate, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(8)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.7)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            } else {
                emptyStateView
            }
        }
    }

    // MARK: Medium — two games side by side

    private var mediumView: some View {
        HStack(spacing: 8) {
            ForEach(paddedGames(count: 2)) { game in
                gameRow(game)
            }
        }
        .padding(12)
    }

    // MARK: Large — four games stacked

    private var largeView: some View {
        VStack(spacing: 8) {
            ForEach(paddedGames(count: 4)) { game in
                gameRow(game)
            }
        }
        .padding(12)
    }

    // MARK: Shared row

    private func gameRow(_ game: WidgetGameEntry) -> some View {
        Link(destination: game.launchURL ?? URL(string: "provenance://")!) {
            HStack(spacing: 10) {
                GameArtworkView(entry: game, cornerRadius: 6)
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        SystemBadgeView(systemShortName: game.systemShortName)
                        if let playedDate = game.lastPlayedDate {
                            Text(playedDate, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: Placeholder

    private var placeholderView: some View {
        VStack(spacing: 8) {
            Image(systemName: "gamecontroller.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No Recent Games")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        ZStack {
            Color(.systemGray6)
            VStack(spacing: 4) {
                Image(systemName: "gamecontroller")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Play a game\nto see it here")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Helpers

    /// Returns entry games padded to `count` with empty placeholder entries.
    private func paddedGames(count: Int) -> [WidgetGameEntry] {
        let games = Array(entry.games.prefix(count))
        if games.count == count { return games }
        let padding = (games.count..<count).map {
            WidgetGameEntry(id: "placeholder-\($0)", title: "—", md5Hash: "", systemIdentifier: "", systemShortName: "", artworkPath: nil, lastPlayedDate: nil, isFavorite: false)
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
#endif
