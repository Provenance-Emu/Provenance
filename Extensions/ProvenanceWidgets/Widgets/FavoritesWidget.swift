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

// MARK: - System glyph (widget-local; mirrors PVQuickLookSupport/SystemIconProvider)

/// Supplies SF Symbol names for Provenance system identifiers for compact favorites artwork overlays.
enum FavoritesWidgetSystemGlyph {

    /// Returns an SF Symbol name appropriate for the reverse-DNS system identifier (e.g. `"com.provenance.snes"`).
    ///
    /// The mapping groups systems by hardware category; unknown identifiers fall back to a generic controller symbol.
    static func sfSymbolName(forSystemIdentifier identifier: String) -> String {
        guard !identifier.isEmpty else { return Defaults.generic }
        let id = identifier.lowercased()

        switch true {
        case id.contains("gameboy") || id.contains(".gb") || id.contains(".gbc") || id.contains(".gba"):
            return "handheld.fill"
        case id.hasSuffix(".ds") || id.hasSuffix(".3ds") || id.contains("nintendo3ds") || id.contains("nintendods"):
            return "handheld.fill"
        case id.contains("psp") || id.contains("psv") || id.contains("vita"):
            return "handheld.fill"
        case id.contains("gamegear") || id.contains("lynx") || id.contains("wonderswan"):
            return "handheld.fill"
        case id.contains("portable") || id.contains("handheld") || id.contains("pocket"):
            return "handheld.fill"
        case id.contains("nes") && !id.contains("snes"):
            return "gamecontroller.fill"
        case id.contains("snes") || id.contains("famicom"):
            return "gamecontroller.fill"
        case id.contains("n64") || id.contains("nintendo64"):
            return "gamecontroller.fill"
        case id.contains("gamecube") || id.contains("wii") || id.contains("switch"):
            return "gamecontroller.fill"
        case id.contains("playstation") || id.contains(".psx") || id.contains(".ps1")
            || id.contains(".ps2") || id.contains(".ps3"):
            return "gamecontroller.fill"
        case id.contains("genesis") || id.contains("megadrive") || id.contains("saturn")
            || id.contains("dreamcast") || id.contains("mastersystem") || id.contains("32x"):
            return "gamecontroller.fill"
        case id.contains("coleco") || id.contains("colecovision"):
            return "gamecontroller.fill"
        case id.contains("dos") || id.contains("doom") || id.contains("amiga")
            || id.contains("atarist") || id.contains("msx") || id.contains("spectrum")
            || id.contains("c64") || id.contains("appleii")
            || id.contains("apple2") || id.contains("macintosh") || id.contains("pc98"):
            return "desktopcomputer"
        case id.contains("arcade") || id.contains("mame") || id.contains("neogeo")
            || id.contains("cps"):
            return "arcade.stick.console.fill"
        default:
            return Defaults.generic
        }
    }

    private enum Defaults {
        static let generic = "gamecontroller.fill"
    }
}

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

    /// Returns layout values aligned to small through extra-large sizes while preserving the same per-family game counts.
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
                .widgetURL(entry.games.first(where: { !$0.id.isEmpty && $0.launchURL != nil })?.launchURL ?? PVLibraryScreenURL)
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

    /// Favorites with non-empty id and a resolvable launch URL so taps and artwork stay aligned with real library rows.
    private var displayGames: [WidgetGameEntry] {
        entry.games.filter { !$0.id.isEmpty && $0.launchURL != nil }
    }

    var body: some View {
        if entry.isPlaceholder || displayGames.isEmpty {
            emptyStateView
        } else {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                adaptiveGridView(for: .systemMedium, maxSlots: 4)
            case .systemLarge:
                adaptiveGridView(for: .systemLarge, maxSlots: 8)
            case .systemExtraLarge:
                adaptiveGridView(for: .systemExtraLarge, maxSlots: 16)
            default:
                adaptiveGridView(for: .systemMedium, maxSlots: 4)
            }
        }
    }

    // MARK: Small — single game

    private var smallView: some View {
        Group {
            if let game = displayGames.first {
                gameButton(game)
            }
        }
        .padding(layoutMetrics.contentPadding)
    }

    // MARK: Adaptive grid (no empty padding cells)

    private func adaptiveGridView(for family: WidgetFamily, maxSlots: Int) -> some View {
        let games = Array(displayGames.prefix(maxSlots))
        let spec = FavoritesGridLayoutSpec.spec(family: family, itemCount: games.count)
        let spacing = layoutMetrics.gridSpacing
        let padding = layoutMetrics.contentPadding

        return GeometryReader { geo in
            let cellW = (geo.size.width - 2 * padding - CGFloat(spec.columns - 1) * spacing) / CGFloat(spec.columns)
            let cellH = (geo.size.height - 2 * padding - CGFloat(spec.rows - 1) * spacing) / CGFloat(spec.rows)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cellW), spacing: spacing), count: spec.columns),
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
                            if Self.shouldShowSystemOverlay(for: game) {
                                favoritesSystemTopOverlay(for: game)
                                    .padding(.leading, 6)
                                    .padding(.top, 6)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            favoritesArtworkTitleBar(title: game.title, metrics: metrics)
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// True when the abbreviated system label is non-empty after trimming, so the badge is not shown as `???`.
    private static func hasMeaningfulSystemBadge(_ shortName: String) -> Bool {
        !shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when a non-empty `systemIdentifier` is available from shared widget JSON.
    private static func hasNonEmptySystemIdentifier(_ systemIdentifier: String?) -> Bool {
        guard let systemIdentifier else { return false }
        return !systemIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// True when a top-leading system row (glyph and/or short-name pill) should appear on artwork.
    private static func shouldShowSystemOverlay(for game: WidgetGameEntry) -> Bool {
        hasMeaningfulSystemBadge(game.systemShortName) || hasNonEmptySystemIdentifier(game.systemIdentifier)
    }

    /// SF Symbol glyph with optional `SystemBadgeView` for the abbreviated system name.
    @ViewBuilder
    private func favoritesSystemTopOverlay(for game: WidgetGameEntry) -> some View {
        let symbol = FavoritesWidgetSystemGlyph.sfSymbolName(forSystemIdentifier: game.systemIdentifier ?? "")
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.65), radius: 2, x: 0, y: 1)
                .padding(5)
                .background(Circle().fill(Color.black.opacity(0.45)))
            if Self.hasMeaningfulSystemBadge(game.systemShortName) {
                SystemBadgeView(systemShortName: game.systemShortName, chrome: .retroWaveNeon)
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
}

/// Column and row counts for a favorites grid given widget family and how many real items are shown (no placeholder slots).
private struct FavoritesGridLayoutSpec {
    let columns: Int
    let rows: Int

    /// Picks a compact grid: fewer items use fewer columns/rows so cells grow without empty neighbors.
    static func spec(family: WidgetFamily, itemCount: Int) -> FavoritesGridLayoutSpec {
        let n = max(1, itemCount)
        switch family {
        case .systemMedium:
            if n == 1 { return FavoritesGridLayoutSpec(columns: 1, rows: 1) }
            if n == 2 { return FavoritesGridLayoutSpec(columns: 2, rows: 1) }
            return FavoritesGridLayoutSpec(columns: 2, rows: Int(ceil(Double(n) / 2.0)))
        case .systemLarge:
            if n <= 4 {
                if n == 1 { return FavoritesGridLayoutSpec(columns: 1, rows: 1) }
                if n == 2 { return FavoritesGridLayoutSpec(columns: 2, rows: 1) }
                if n == 3 { return FavoritesGridLayoutSpec(columns: 3, rows: 1) }
                return FavoritesGridLayoutSpec(columns: 2, rows: 2)
            }
            return FavoritesGridLayoutSpec(columns: 4, rows: Int(ceil(Double(n) / 4.0)))
        case .systemExtraLarge:
            let cols = 4
            return FavoritesGridLayoutSpec(columns: cols, rows: Int(ceil(Double(n) / Double(cols))))
        default:
            return FavoritesGridLayoutSpec(columns: 2, rows: Int(ceil(Double(n) / 2.0)))
        }
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
