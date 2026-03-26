//
//  LibraryStatsWidget.swift
//  ProvenanceWidgets
//
//  Created by Provenance Emu on 2026-03-19.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import SwiftUI
import UIKit
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
        .configurationDisplayName(String(localized: "widget.library-stats.display-name", defaultValue: "Library Stats", comment: "Library Stats widget display name"))
        .description(String(localized: "widget.library-stats.description", defaultValue: "An overview of your game library.", comment: "Library Stats widget description"))
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
    static let statTilePadding: CGFloat = 8
    static let statTileCornerRadius: CGFloat = 10
    static let headerTitleSpacing: CGFloat = 2
    /// Icon column width in each stat cell (keeps value column as wide as possible).
    static let statTileIconWidth: CGFloat = 14
    /// Space between the medium header lines and the usage bar section.
    static let mediumUsageSectionTopSpacing: CGFloat = 6
    /// Vertical spacing between the two usage bar rows.
    static let mediumUsageRowSpacing: CGFloat = 6
    /// Track height for medium usage bars.
    static let mediumUsageBarHeight: CGFloat = 7
    /// Minimum visible fill width when fraction is non-zero (avoids invisible slivers).
    static let mediumUsageBarMinFillWidth: CGFloat = 2
    /// Corner radius for medium usage bar tracks.
    static let mediumUsageBarCornerRadius: CGFloat = 3
    /// Spacing between row icon and label above each usage bar.
    static let mediumUsageLabelIconSpacing: CGFloat = 5
}

// MARK: - Medium usage visualization (systemMedium only)

/// Normalized fractions for medium-widget usage bars derived only from `WidgetLibraryStats` snapshots.
private enum LibraryStatsMediumUsageVisualization {
    /// Display-only cap: playtime bar reaches full width at this total play time (~100 h).
    static let playtimeBarFullWidthSeconds: Double = 100 * 60 * 60

    /// Returns the share of favorited games in `0...1`, or `0` when the library is empty.
    static func favoritesShareFraction(stats: WidgetLibraryStats) -> CGFloat {
        guard stats.totalGames > 0 else { return 0 }
        return CGFloat(min(1, Double(stats.favoritesCount) / Double(stats.totalGames)))
    }

    /// Returns total play time mapped to `0...1` against `playtimeBarFullWidthSeconds` for bar fill only.
    static func playtimeLevelFraction(stats: WidgetLibraryStats) -> CGFloat {
        guard stats.totalPlayTimeSeconds > 0 else { return 0 }
        return CGFloat(min(1, Double(stats.totalPlayTimeSeconds) / playtimeBarFullWidthSeconds))
    }
}

/// Single horizontal RetroWave track + neon fill for one usage metric.
private struct LibraryStatsMediumNeonTrackBar: View {
    /// Fill amount as a fraction of track width; drawing clamps to `0...1`.
    let fillFraction: CGFloat
    /// Neon accent color for the fill gradient (matches adjacent stat tile accents).
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let clamped = max(0, min(1, fillFraction))
            let rawWidth = CGFloat(clamped) * geo.size.width
            let fillWidth = clamped > 0 ? max(LibraryStatsWidgetLayout.mediumUsageBarMinFillWidth, rawWidth) : 0
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: LibraryStatsWidgetLayout.mediumUsageBarCornerRadius, style: .continuous)
                    .fill(RetroWaveWidgetPalette.retroBlack.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: LibraryStatsWidgetLayout.mediumUsageBarCornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                RoundedRectangle(cornerRadius: LibraryStatsWidgetLayout.mediumUsageBarCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.95), accent.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
                    .opacity(clamped > 0 ? 1 : 0)
            }
        }
        .frame(height: LibraryStatsWidgetLayout.mediumUsageBarHeight)
        .frame(maxWidth: .infinity)
    }
}

/// Two compact labeled bars: playtime level (normalized) and favorites share of the library.
private struct LibraryStatsMediumUsageBarsView: View {
    let stats: WidgetLibraryStats

    var body: some View {
        VStack(alignment: .leading, spacing: LibraryStatsWidgetLayout.mediumUsageRowSpacing) {
            LibraryStatsMediumUsageBarRow(
                label: String(localized: "widget.common.played", defaultValue: "Played", comment: "Play time label"),
                systemImage: "clock.fill",
                fillFraction: LibraryStatsMediumUsageVisualization.playtimeLevelFraction(stats: stats),
                accent: RetroWaveWidgetPalette.neonGreen
            )
            LibraryStatsMediumUsageBarRow(
                label: String(localized: "widget.common.favorites", defaultValue: "Favorites", comment: "Favorites count label"),
                systemImage: "star.fill",
                fillFraction: LibraryStatsMediumUsageVisualization.favoritesShareFraction(stats: stats),
                accent: RetroWaveWidgetPalette.neonYellow
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Label row + track for one medium usage metric (matches stat grid icon accents).
private struct LibraryStatsMediumUsageBarRow: View {
    let label: String
    let systemImage: String
    let fillFraction: CGFloat
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: LibraryStatsWidgetLayout.mediumUsageLabelIconSpacing) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: LibraryStatsWidgetLayout.statTileIconWidth, alignment: .leading)
                Text(label)
                    .retroWaveWidgetMetaStyle()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                    .truncationMode(.tail)
            }
            LibraryStatsMediumNeonTrackBar(fillFraction: fillFraction, accent: accent)
        }
    }
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
                smallPrimaryStat(value: String(entry.stats.totalGames), label: String(localized: "widget.common.games", defaultValue: "Games", comment: "Games count label"))
                smallSecondaryStat(value: String(entry.stats.totalSystems), label: String(localized: "widget.common.systems", defaultValue: "Systems", comment: "Systems count label"))
            }
        }
        .padding(LibraryStatsWidgetLayout.smallPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: Medium — header + usage bars + 2×2 stat grid

    private var mediumView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: LibraryStatsWidgetLayout.headerTitleSpacing) {
                ProvenanceMarkView(logoHeight: LibraryStatsWidgetLayout.mediumLogoHeight)
                Text(String(localized: "widget.library-stats.title.library", defaultValue: "Library", comment: "Library Stats header first line"))
                    .retroWaveWidgetTitleStyle()
                Text(String(localized: "widget.library-stats.title.stats", defaultValue: "Stats", comment: "Library Stats header second line"))
                    .retroWaveWidgetMetaStyle()
                LibraryStatsMediumUsageBarsView(stats: entry.stats)
                    .padding(.top, LibraryStatsWidgetLayout.mediumUsageSectionTopSpacing)
                Spacer(minLength: 0)
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
                    label: String(localized: "widget.common.games", defaultValue: "Games", comment: "Games count label"),
                    iconName: "gamecontroller.fill",
                    accent: RetroWaveWidgetPalette.neonBlue
                )
                statTile(
                    value: String(entry.stats.totalSystems),
                    label: String(localized: "widget.common.systems", defaultValue: "Systems", comment: "Systems count label"),
                    iconName: "cpu.fill",
                    accent: RetroWaveWidgetPalette.neonPurple
                )
                statTile(
                    value: entry.stats.totalPlayTimeFormatted,
                    label: String(localized: "widget.common.played", defaultValue: "Played", comment: "Play time label"),
                    iconName: "clock.fill",
                    accent: RetroWaveWidgetPalette.neonGreen,
                    isPlaytimeValue: true
                )
                statTile(
                    value: String(entry.stats.favoritesCount),
                    label: String(localized: "widget.common.favorites", defaultValue: "Favorites", comment: "Favorites count label"),
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
                    label: String(localized: "widget.common.games", defaultValue: "Games", comment: "Games count label"),
                    iconName: "gamecontroller.fill",
                    accent: RetroWaveWidgetPalette.neonBlue
                )
                statTile(
                    value: String(entry.stats.totalSystems),
                    label: String(localized: "widget.common.systems", defaultValue: "Systems", comment: "Systems count label"),
                    iconName: "cpu.fill",
                    accent: RetroWaveWidgetPalette.neonPurple
                )
                statTile(
                    value: entry.stats.totalPlayTimeFormatted,
                    label: String(localized: "widget.common.played", defaultValue: "Played", comment: "Play time label"),
                    iconName: "clock.fill",
                    accent: RetroWaveWidgetPalette.neonGreen,
                    isPlaytimeValue: true
                )
                statTile(
                    value: String(entry.stats.favoritesCount),
                    label: String(localized: "widget.common.favorites", defaultValue: "Favorites", comment: "Favorites count label"),
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
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(RetroWaveWidgetTypography.valueForeground)
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .lineLimit(1)
            Text(label)
                .retroWaveWidgetLabelStyle()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
                .truncationMode(.tail)
        }
    }

    private func smallSecondaryStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(RetroWaveWidgetTypography.valueForeground.opacity(0.92))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .allowsTightening(true)
                .lineLimit(1)
            Text(label)
                .retroWaveWidgetMetaStyle()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
                .truncationMode(.tail)
        }
    }

    /// Applies compact, localization-safe behavior for stat labels in tight grid cells.
    private func compactStatLabel(_ label: String) -> some View {
        Text(label)
            .retroWaveWidgetMetaStyle()
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .allowsTightening(true)
            .truncationMode(.tail)
    }

    /// Grid stat cell; when `isPlaytimeValue` is true, the value uses a smaller base font and lower minimum scale so long duration strings stay on one line.
    private func statTile(value: String, label: String, iconName: String, accent: Color, isPlaytimeValue: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 5) {
                Image(systemName: iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: LibraryStatsWidgetLayout.statTileIconWidth, alignment: .leading)
                Text(value)
                    .font(isPlaytimeValue ? .system(.footnote, design: .rounded).weight(.bold) : .system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(RetroWaveWidgetTypography.valueForeground)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(isPlaytimeValue ? 0.5 : 0.62)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)
            }
            compactStatLabel(label)
        }
        .padding(LibraryStatsWidgetLayout.statTilePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .retroWaveWidgetGridCellSurface(cornerRadius: LibraryStatsWidgetLayout.statTileCornerRadius)
    }
}

// MARK: - Brand asset

/// Loads the Provenance mark from the widget extension bundle (explicit lookup avoids ambiguous `Image(_:)` resolution).
private enum ProvenanceWidgetBrandImage {
    static let logoAssetName = "prov_icon"

    /// Returns the bundled logo, or `nil` if the asset is missing from this target.
    static func loadLogoUIImage() -> UIImage? {
        UIImage(named: logoAssetName, in: .main, compatibleWith: nil)
    }
}

// MARK: - Subviews

/// Provenance wordmark for library stats widgets: bundled `prov_icon` when available, otherwise a compact RetroWave text mark (no placeholder blur).
private struct ProvenanceMarkView: View {
    var logoHeight: CGFloat

    var body: some View {
        Group {
            if let uiImage = ProvenanceWidgetBrandImage.loadLogoUIImage() {
                Image(uiImage: uiImage)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .frame(height: logoHeight)
                    .shadow(color: Color.white.opacity(0.22), radius: 2, x: 0, y: 0)
                    .shadow(color: RetroWaveWidgetPalette.neonCyan.opacity(0.28), radius: 4, x: 0, y: 0)
            } else {
                ProvenanceWordmarkFallbackView(logoHeight: logoHeight)
            }
        }
        .accessibilityLabel(WidgetLocalizedStrings.brandName)
    }
}

/// Legible RetroWave text mark when `prov_icon` is not loaded (avoids empty or decorative-only regions).
private struct ProvenanceWordmarkFallbackView: View {
    var logoHeight: CGFloat

    private var useCompactAbbreviation: Bool {
        logoHeight <= 22
    }

    var body: some View {
        Group {
            if useCompactAbbreviation {
                Text("PV")
                    .font(.system(size: logoHeight * 0.72, weight: .heavy, design: .rounded))
            } else {
                Text(WidgetLocalizedStrings.brandName.uppercased(with: .current))
                    .font(.system(size: max(logoHeight * 0.38, 11), weight: .heavy, design: .rounded))
            }
        }
        .foregroundStyle(
            LinearGradient(
                colors: [
                    RetroWaveWidgetPalette.neonCyan.opacity(0.95),
                    RetroWaveWidgetPalette.neonPink.opacity(0.92)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .allowsTightening(true)
        .frame(height: logoHeight, alignment: .center)
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
                Text(WidgetLocalizedStrings.brandName)
                    .retroWaveWidgetTitleStyle()
                Text(String(localized: "widget.library-stats.header", defaultValue: "Library Stats", comment: "Library Stats header label"))
                    .retroWaveWidgetMetaStyle()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                    .truncationMode(.tail)
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
