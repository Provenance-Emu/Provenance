//
//  LibraryStatsWidget.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import SwiftUI
import WidgetKit
import PVLibrary

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
                .containerBackground(for: .widget) {
                    LibraryStatsWidgetContainerBackground()
                }
                .widgetURL(PVLibraryScreenURL)
        }
        .configurationDisplayName("Library Stats")
        .description("An overview of your game library.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Container chrome

/// Full-bleed RetroWave background for the library stats widget (dark base + top neon accent).
private struct LibraryStatsWidgetContainerBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            RetroWaveWidgetPalette.retroBlack
            RetroWaveWidgetGradients.mainNeon
                .frame(height: LibraryStatsWidgetLayout.containerAccentHeight)
                .opacity(0.92)
        }
    }
}

// MARK: - Layout constants

private enum LibraryStatsWidgetLayout {
    static let containerAccentHeight: CGFloat = 3
    static let smallLogoHeight: CGFloat = 20
    static let mediumLogoHeight: CGFloat = 24
    static let largeLogoHeight: CGFloat = 26
    static let extraLargeLogoHeight: CGFloat = 28
    static let smallPadding: CGFloat = 12
    static let mediumOuterPadding: CGFloat = 12
    static let largeOuterPadding: CGFloat = 16
    static let extraLargeOuterPadding: CGFloat = 18
    static let mediumGridSpacing: CGFloat = 10
    static let largeGridSpacing: CGFloat = 12
    static let extraLargeGridSpacing: CGFloat = 14
    static let statTilePadding: CGFloat = 10
    static let statTileCornerRadius: CGFloat = 10
    static let headerTitleSpacing: CGFloat = 2
}

// MARK: - Views

struct LibraryStatsWidgetView: View {
    let entry: LibraryStatsEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .systemLarge:
                largeView(extraLarge: false)
            case .systemExtraLarge:
                largeView(extraLarge: true)
            default:
                mediumView
            }
        }
        .retroWaveWidgetContainerChrome()
    }

    // MARK: Small — hero count + secondary stat

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProvenanceMarkView(logoHeight: LibraryStatsWidgetLayout.smallLogoHeight)
            RetroWaveNeonAccentLine()
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 6) {
                smallPrimaryStat(value: String(entry.stats.totalGames), label: "Games")
                smallSecondaryStat(value: String(entry.stats.totalSystems), label: "Systems")
            }
        }
        .padding(LibraryStatsWidgetLayout.smallPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium — header + 2×2 stat grid

    private var mediumView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: LibraryStatsWidgetLayout.headerTitleSpacing) {
                ProvenanceMarkView(logoHeight: LibraryStatsWidgetLayout.mediumLogoHeight)
                Text("Library")
                    .retroWaveWidgetTitleStyle()
                Text("Stats")
                    .retroWaveWidgetMetaStyle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, LibraryStatsWidgetLayout.mediumOuterPadding)
            .padding(.vertical, LibraryStatsWidgetLayout.mediumOuterPadding)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: LibraryStatsWidgetLayout.mediumGridSpacing),
                    GridItem(.flexible(), spacing: LibraryStatsWidgetLayout.mediumGridSpacing)
                ],
                spacing: LibraryStatsWidgetLayout.mediumGridSpacing
            ) {
                statTile(
                    value: String(entry.stats.totalGames),
                    label: "Games",
                    iconName: "gamecontroller.fill",
                    accent: RetroWaveWidgetPalette.neonBlue
                )
                statTile(
                    value: String(entry.stats.totalSystems),
                    label: "Systems",
                    iconName: "cpu.fill",
                    accent: RetroWaveWidgetPalette.neonPurple
                )
                statTile(
                    value: entry.stats.totalPlayTimeFormatted,
                    label: "Played",
                    iconName: "clock.fill",
                    accent: RetroWaveWidgetPalette.neonGreen
                )
                statTile(
                    value: String(entry.stats.favoritesCount),
                    label: "Favorites",
                    iconName: "star.fill",
                    accent: RetroWaveWidgetPalette.neonYellow
                )
            }
            .padding(LibraryStatsWidgetLayout.mediumOuterPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Large / Extra Large — header + 2×2 stat grid (readability over single row)

    private func largeView(extraLarge: Bool) -> some View {
        let pad = extraLarge ? LibraryStatsWidgetLayout.extraLargeOuterPadding : LibraryStatsWidgetLayout.largeOuterPadding
        let gridSpacing = extraLarge ? LibraryStatsWidgetLayout.extraLargeGridSpacing : LibraryStatsWidgetLayout.largeGridSpacing
        let logoH = extraLarge ? LibraryStatsWidgetLayout.extraLargeLogoHeight : LibraryStatsWidgetLayout.largeLogoHeight

        return VStack(alignment: .leading, spacing: extraLarge ? 18 : 14) {
            LibraryStatsBrandedHeaderView(logoHeight: logoH)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: gridSpacing),
                    GridItem(.flexible(), spacing: gridSpacing)
                ],
                spacing: gridSpacing
            ) {
                statTile(
                    value: String(entry.stats.totalGames),
                    label: "Games",
                    iconName: "gamecontroller.fill",
                    accent: RetroWaveWidgetPalette.neonBlue
                )
                statTile(
                    value: String(entry.stats.totalSystems),
                    label: "Systems",
                    iconName: "cpu.fill",
                    accent: RetroWaveWidgetPalette.neonPurple
                )
                statTile(
                    value: entry.stats.totalPlayTimeFormatted,
                    label: "Played",
                    iconName: "clock.fill",
                    accent: RetroWaveWidgetPalette.neonGreen
                )
                statTile(
                    value: String(entry.stats.favoritesCount),
                    label: "Favorites",
                    iconName: "star.fill",
                    accent: RetroWaveWidgetPalette.neonYellow
                )
            }
            Spacer(minLength: 0)
        }
        .padding(pad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Helpers

    private func smallPrimaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(RetroWaveWidgetTypography.valueForeground)
                .monospacedDigit()
                .minimumScaleFactor(0.85)
                .lineLimit(1)
            Text(label)
                .retroWaveWidgetLabelStyle()
        }
    }

    private func smallSecondaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(RetroWaveWidgetTypography.valueForeground.opacity(0.92))
                .monospacedDigit()
                .minimumScaleFactor(0.85)
                .lineLimit(1)
            Text(label)
                .retroWaveWidgetMetaStyle()
        }
    }

    private func statTile(value: String, label: String, iconName: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 14, alignment: .leading)
                Text(value)
                    .retroWaveWidgetValueStyle()
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
                    .lineLimit(2)
            }
            Text(label)
                .retroWaveWidgetMetaStyle()
        }
        .padding(LibraryStatsWidgetLayout.statTilePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .retroWaveWidgetGridCellSurface(cornerRadius: LibraryStatsWidgetLayout.statTileCornerRadius)
    }
}

// MARK: - Subviews

/// Provenance wordmark used in library stats widgets (`prov_icon` asset).
private struct ProvenanceMarkView: View {
    var logoHeight: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: logoHeight * 0.38, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: logoHeight
                    )
                )
                .frame(width: logoHeight * 2.5, height: logoHeight * 1.45)
                .blur(radius: 2)
            Image("prov_icon")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(height: logoHeight)
                .shadow(color: Color.white.opacity(0.35), radius: 4, x: 0, y: 0)
                .shadow(color: RetroWaveWidgetPalette.neonCyan.opacity(0.42), radius: 6, x: 0, y: 0)
        }
        .accessibilityLabel("Provenance")
    }
}

/// Thin horizontal neon gradient accent for visual hierarchy under the mark.
private struct RetroWaveNeonAccentLine: View {
    var body: some View {
        RetroWaveWidgetGradients.mainNeon
            .frame(height: 2)
            .clipShape(Capsule())
            .opacity(0.85)
    }
}

/// Title stack with logo and “Provenance / Library Stats” for large widgets.
private struct LibraryStatsBrandedHeaderView: View {
    var logoHeight: CGFloat

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ProvenanceMarkView(logoHeight: logoHeight)
            VStack(alignment: .leading, spacing: LibraryStatsWidgetLayout.headerTitleSpacing) {
                Text("Provenance")
                    .retroWaveWidgetTitleStyle()
                Text("Library Stats")
                    .retroWaveWidgetMetaStyle()
            }
            Spacer(minLength: 0)
        }
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
