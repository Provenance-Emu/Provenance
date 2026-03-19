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

// MARK: - Provider

struct LibraryStatsProvider: TimelineProvider {
    private let dataProvider = WidgetDataProvider()

    func placeholder(in context: Context) -> LibraryStatsEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (LibraryStatsEntry) -> Void) {
        if context.isPreview {
            let previewStats = LibraryStatsData(
                totalGames: 247,
                totalSystems: 18,
                totalPlayTimeSeconds: 3 * 3600 + 25 * 60,
                favoritesCount: 12
            )
            completion(LibraryStatsEntry(date: Date(), stats: previewStats, isPlaceholder: false))
        } else {
            let stats = dataProvider.libraryStats()
            completion(LibraryStatsEntry(date: Date(), stats: stats, isPlaceholder: false))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LibraryStatsEntry>) -> Void) {
        let stats = dataProvider.libraryStats()
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
        .supportedFamilies([.systemSmall, .systemMedium])
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
            // Left column — branding
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

            // Right column — stats grid
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
        stats: LibraryStatsData(totalGames: 247, totalSystems: 18, totalPlayTimeSeconds: 3 * 3600 + 25 * 60, favoritesCount: 12),
        isPlaceholder: false
    )
}

#Preview("Medium", as: .systemMedium) {
    LibraryStatsWidget()
} timeline: {
    LibraryStatsEntry(
        date: Date(),
        stats: LibraryStatsData(totalGames: 247, totalSystems: 18, totalPlayTimeSeconds: 3 * 3600 + 25 * 60, favoritesCount: 12),
        isPlaceholder: false
    )
}
#endif
