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

// MARK: - Recent activity buckets

/// Computes daily play counts from widget recent-game entries for the medium sparkline.
private enum LibraryStatsRecentActivity {
    /// Number of calendar days in the activity window (today inclusive).
    static let bucketCount = 7

    /// Returns one bucket per day for the last `bucketCount` days ending at `referenceDate`, oldest first. Missing dates are ignored; empty input yields zeros.
    static func buckets(from recentGames: [WidgetGameEntry], referenceDate: Date = Date(), calendar: Calendar = .current) -> [Int] {
        var buckets = [Int](repeating: 0, count: bucketCount)
        let todayStart = calendar.startOfDay(for: referenceDate)
        guard let windowStart = calendar.date(byAdding: .day, value: -(bucketCount - 1), to: todayStart) else { return buckets }
        for game in recentGames {
            guard let played = game.lastPlayedDate else { continue }
            let dayStart = calendar.startOfDay(for: played)
            let dayIndex = calendar.dateComponents([.day], from: windowStart, to: dayStart).day ?? -999
            if dayIndex >= 0, dayIndex < bucketCount {
                buckets[dayIndex] += 1
            }
        }
        return buckets
    }
}

// MARK: - Entry

struct LibraryStatsEntry: TimelineEntry {
    let date: Date
    let stats: WidgetLibraryStats
    /// One count per calendar day for the last 7 days (today inclusive), oldest day first — derived from recent games' `lastPlayedDate`.
    let recentActivityBuckets: [Int]
    let isPlaceholder: Bool

    static var placeholder: LibraryStatsEntry {
        LibraryStatsEntry(
            date: Date(),
            stats: WidgetLibraryStats(totalGames: 0, totalSystems: 0, totalPlayTimeSeconds: 0, favoritesCount: 0),
            recentActivityBuckets: [Int](repeating: 0, count: LibraryStatsRecentActivity.bucketCount),
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
            let previewBuckets = [0, 1, 2, 1, 1, 3, 2]
            completion(LibraryStatsEntry(date: Date(), stats: previewStats, recentActivityBuckets: previewBuckets, isPlaceholder: false))
        } else {
            let stats = WidgetSharedDefaults.loadLibraryStats()
            let buckets = LibraryStatsRecentActivity.buckets(from: WidgetSharedDefaults.loadRecentGames())
            completion(LibraryStatsEntry(date: Date(), stats: stats, recentActivityBuckets: buckets, isPlaceholder: false))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LibraryStatsEntry>) -> Void) {
        let stats = WidgetSharedDefaults.loadLibraryStats()
        let buckets = LibraryStatsRecentActivity.buckets(from: WidgetSharedDefaults.loadRecentGames())
        let entry = LibraryStatsEntry(date: Date(), stats: stats, recentActivityBuckets: buckets, isPlaceholder: false)
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
    /// Space between the medium header lines and the activity sparkline.
    static let mediumSparklineSectionTopSpacing: CGFloat = 6
    /// Height of the 7-day activity sparkline chart.
    static let mediumSparklineHeight: CGFloat = 44
    /// Vertical inset for the sparkline polyline so point markers are not clipped.
    static let mediumSparklineVerticalPadding: CGFloat = 5
    /// Diameter of each sparkline vertex marker.
    static let mediumSparklinePointDiameter: CGFloat = 4
    /// Spacing between sparkline caption icon and label.
    static let mediumSparklineLabelIconSpacing: CGFloat = 5
    /// Corner radius for the sparkline chart surface and clipping.
    static let mediumSparklineChartCornerRadius: CGFloat = 6
}

// MARK: - Medium recent activity sparkline (systemMedium only)

/// Pads or truncates bucket arrays so the chart always draws seven days.
private func libraryStatsNormalizedActivityBuckets(_ raw: [Int]) -> [Int] {
    let n = LibraryStatsRecentActivity.bucketCount
    if raw.count == n { return raw }
    if raw.count > n { return Array(raw.prefix(n)) }
    return raw + [Int](repeating: 0, count: n - raw.count)
}

/// Caption + RetroWave sparkline for recent daily play counts on the medium widget.
private struct LibraryStatsMediumRecentActivitySparklineView: View {
    /// Daily play counts (typically length `LibraryStatsRecentActivity.bucketCount`); normalized in `body`.
    let activityBuckets: [Int]

    var body: some View {
        let buckets = libraryStatsNormalizedActivityBuckets(activityBuckets)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: LibraryStatsWidgetLayout.mediumSparklineLabelIconSpacing) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(RetroWaveWidgetPalette.neonCyan)
                    .frame(width: LibraryStatsWidgetLayout.statTileIconWidth, alignment: .leading)
                Text(String(localized: "widget.library-stats.recent-activity", defaultValue: "Recent Activity", comment: "Medium Library Stats sparkline caption"))
                    .retroWaveWidgetMetaStyle()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .allowsTightening(true)
                    .truncationMode(.tail)
            }
            LibraryStatsMediumSparklineChart(values: buckets)
                .frame(height: LibraryStatsWidgetLayout.mediumSparklineHeight)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Neon gradient line, soft fill, and vertex dots for the 7-day activity series.
private struct LibraryStatsMediumSparklineChart: View {
    /// One non-negative count per day, left (oldest) to right (newest).
    let values: [Int]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let pad = LibraryStatsWidgetLayout.mediumSparklineVerticalPadding
            let chartH = max(h - pad * 2, 1)
            let maxV = max(values.max() ?? 0, 1)
            let n = values.count
            let points: [CGPoint] = values.enumerated().map { i, v in
                let x: CGFloat
                if n <= 1 {
                    x = w * 0.5
                } else {
                    x = CGFloat(i) / CGFloat(n - 1) * w
                }
                let frac = CGFloat(v) / CGFloat(maxV)
                let y = h - pad - frac * chartH
                return CGPoint(x: x, y: y)
            }
            ZStack {
                RoundedRectangle(cornerRadius: LibraryStatsWidgetLayout.mediumSparklineChartCornerRadius, style: .continuous)
                    .fill(RetroWaveWidgetPalette.retroBlack.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: LibraryStatsWidgetLayout.mediumSparklineChartCornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                if points.count >= 2 {
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: h))
                        for p in points {
                            path.addLine(to: p)
                        }
                        path.addLine(to: CGPoint(x: points[points.count - 1].x, y: h))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                RetroWaveWidgetPalette.neonPink.opacity(0.38),
                                RetroWaveWidgetPalette.neonCyan.opacity(0.06)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                if let first = points.first {
                    Path { path in
                        path.move(to: first)
                        for p in points.dropFirst() {
                            path.addLine(to: p)
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [RetroWaveWidgetPalette.neonCyan, RetroWaveWidgetPalette.neonPink],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                }
                ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [RetroWaveWidgetPalette.neonCyan.opacity(0.98), RetroWaveWidgetPalette.neonPink.opacity(0.55)],
                                center: .center,
                                startRadius: 0,
                                endRadius: LibraryStatsWidgetLayout.mediumSparklinePointDiameter * 0.6
                            )
                        )
                        .frame(width: LibraryStatsWidgetLayout.mediumSparklinePointDiameter, height: LibraryStatsWidgetLayout.mediumSparklinePointDiameter)
                        .position(pt)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: LibraryStatsWidgetLayout.mediumSparklineChartCornerRadius, style: .continuous))
        }
        .frame(height: LibraryStatsWidgetLayout.mediumSparklineHeight)
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

    // MARK: Medium — header + activity sparkline + 2×2 stat grid

    private var mediumView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: LibraryStatsWidgetLayout.headerTitleSpacing) {
                ProvenanceMarkView(logoHeight: LibraryStatsWidgetLayout.mediumLogoHeight)
                Text(String(localized: "widget.library-stats.title.library", defaultValue: "Library", comment: "Library Stats header first line"))
                    .retroWaveWidgetTitleStyle()
                Text(String(localized: "widget.library-stats.title.stats", defaultValue: "Stats", comment: "Library Stats header second line"))
                    .retroWaveWidgetMetaStyle()
                LibraryStatsMediumRecentActivitySparklineView(activityBuckets: entry.recentActivityBuckets)
                    .padding(.top, LibraryStatsWidgetLayout.mediumSparklineSectionTopSpacing)
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
        recentActivityBuckets: [0, 1, 2, 1, 1, 3, 2],
        isPlaceholder: false
    )
}

#Preview("Medium", as: .systemMedium) {
    LibraryStatsWidget()
} timeline: {
    LibraryStatsEntry(
        date: Date(),
        stats: WidgetLibraryStats(totalGames: 247, totalSystems: 18, totalPlayTimeSeconds: 3 * 3600 + 25 * 60, favoritesCount: 12),
        recentActivityBuckets: [0, 1, 2, 1, 1, 3, 2],
        isPlaceholder: false
    )
}

#Preview("Large", as: .systemLarge) {
    LibraryStatsWidget()
} timeline: {
    LibraryStatsEntry(
        date: Date(),
        stats: WidgetLibraryStats(totalGames: 247, totalSystems: 18, totalPlayTimeSeconds: 3 * 3600 + 25 * 60, favoritesCount: 12),
        recentActivityBuckets: [0, 1, 2, 1, 1, 3, 2],
        isPlaceholder: false
    )
}
#endif
