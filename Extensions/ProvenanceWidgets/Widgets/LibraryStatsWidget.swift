//
//  LibraryStatsWidget.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import WidgetKit
import SwiftUI

// MARK: - Entry

struct LibraryStatsEntry: TimelineEntry {
    let date: Date
    let stats: WidgetLibraryStats
    let isPlaceholder: Bool

    static var placeholder: LibraryStatsEntry {
        LibraryStatsEntry(
            date: Date(),
            stats: WidgetLibraryStats(totalGames: 0, totalSystems: 0, totalPlayTimeSeconds: 0, favoritesCount: 0),
            isPlaceholder: true
        )
    }
}

// MARK: - Provider

struct LibraryStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> LibraryStatsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (LibraryStatsEntry) -> Void) {
        if context.isPreview {
            let previewStats = WidgetLibraryStats(
                totalGames: 247,
                totalSystems: 18,
                totalPlayTimeSeconds: 3 * 3600 + 25 * 60,
                favoritesCount: 12
            )
            completion(LibraryStatsEntry(date: Date(), stats: previewStats, isPlaceholder: false))
        } else {
            let stats = WidgetSharedDefaults.loadLibraryStats()
            completion(LibraryStatsEntry(date: Date(), stats: stats, isPlaceholder: false))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LibraryStatsEntry>) -> Void) {
        let stats = WidgetSharedDefaults.loadLibraryStats()
        let entry = LibraryStatsEntry(date: Date(), stats: stats, isPlaceholder: false)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Widget

struct LibraryStatsWidget: Widget {
    let kind: String = "LibraryStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LibraryStatsProvider()) { entry in
            LibraryStatsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Library Stats")
        .description("An overview of your game library.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Views

struct LibraryStatsWidgetView: View {
    let entry: LibraryStatsEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemMedium:
            mediumView
        case .systemLarge, .systemExtraLarge:
            largeView
        default:
            mediumView
        }
    }

    // MARK: Small — key stat only

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "books.vertical.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Spacer()
            statValue(String(entry.stats.totalGames), label: "Games")
            statValue(String(entry.stats.totalSystems), label: "Systems")
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium — all stats

    private var mediumView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "books.vertical.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text("Library")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Stats")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statTile(value: String(entry.stats.totalGames), label: "Games", iconName: "gamecontroller.fill", color: .blue)
                statTile(value: String(entry.stats.totalSystems), label: "Systems", iconName: "cpu.fill", color: .purple)
                statTile(value: entry.stats.totalPlayTimeFormatted, label: "Played", iconName: "clock.fill", color: .green)
                statTile(value: String(entry.stats.favoritesCount), label: "Favorites", iconName: "star.fill", color: .yellow)
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Large / Extra Large — stats grid with recent-play hook

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Provenance")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Library Stats")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()),
                          GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                statTile(value: String(entry.stats.totalGames),
                         label: "Games", iconName: "gamecontroller.fill", color: .blue)
                statTile(value: String(entry.stats.totalSystems),
                         label: "Systems", iconName: "cpu.fill", color: .purple)
                statTile(value: entry.stats.totalPlayTimeFormatted,
                         label: "Played", iconName: "clock.fill", color: .green)
                statTile(value: String(entry.stats.favoritesCount),
                         label: "Favorites", iconName: "star.fill", color: .yellow)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Helpers

    private func statValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func statTile(value: String, label: String, iconName: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    LibraryStatsWidget()
} timeline: {
    LibraryStatsEntry(
        date: Date(),
        stats: WidgetLibraryStats(totalGames: 247, totalSystems: 18, totalPlayTimeSeconds: 3 * 3600 + 25 * 60, favoritesCount: 12),
        isPlaceholder: false
    )
}

#Preview("Medium", as: .systemMedium) {
    LibraryStatsWidget()
} timeline: {
    LibraryStatsEntry(
        date: Date(),
        stats: WidgetLibraryStats(totalGames: 247, totalSystems: 18, totalPlayTimeSeconds: 3 * 3600 + 25 * 60, favoritesCount: 12),
        isPlaceholder: false
    )
}

#Preview("Large", as: .systemLarge) {
    LibraryStatsWidget()
} timeline: {
    LibraryStatsEntry(
        date: Date(),
        stats: WidgetLibraryStats(totalGames: 247, totalSystems: 18, totalPlayTimeSeconds: 3 * 3600 + 25 * 60, favoritesCount: 12),
        isPlaceholder: false
    )
}
#endif
