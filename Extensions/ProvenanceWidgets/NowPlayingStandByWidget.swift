//
//  NowPlayingStandByWidget.swift
//  ProvenanceWidgets
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

/// StandBy-mode Now Playing widget.
/// Displays full-screen album art and track info while game music plays in background.
/// Designed for nightstand use with iOS 17+ StandBy mode.
/// Requires `.containerBackground` for StandBy compatibility.

#if os(iOS)
import SwiftUI
import UIKit
import WidgetKit
import PVLibrary

// MARK: - Timeline Entry

struct NowPlayingStandByEntry: TimelineEntry {
    let date: Date
    let nowPlaying: WidgetNowPlayingEntry?
    let fallbackGame: WidgetGameEntry?

    /// Full-bleed album art for the StandBy background.
    ///
    /// Decoded on demand from `WidgetNowPlayingEntry.albumArtPath` at the `hero` budget.
    var albumArtBackgroundImage: UIImage? {
        guard let path = nowPlaying?.albumArtPath else { return nil }
        return WidgetSharedDefaults.artworkImage(
            forRelativePath: path,
            maxPixelSize: WidgetArtworkPixelBudget.hero
        )
    }

    /// The same album art again for the 60pt inset thumbnail.
    ///
    /// A separate, much smaller decode on purpose: reusing the full-bleed bitmap for a
    /// 60pt square would keep a `hero`-sized image alive for a thumbnail's worth of
    /// pixels.
    var albumArtThumbnailImage: UIImage? {
        guard let path = nowPlaying?.albumArtPath else { return nil }
        return WidgetSharedDefaults.artworkImage(
            forRelativePath: path,
            maxPixelSize: WidgetArtworkPixelBudget.inlineThumbnail
        )
    }

    /// Box art for the most recent game, shown full-bleed when nothing is playing.
    var fallbackArtworkImage: UIImage? {
        guard let path = fallbackGame?.artworkPath else { return nil }
        return WidgetSharedDefaults.artworkImage(
            forRelativePath: path,
            maxPixelSize: WidgetArtworkPixelBudget.hero
        )
    }
}

// MARK: - Timeline Provider

struct NowPlayingStandByProvider: TimelineProvider {
    /// Fallback refresh cadence, in minutes. Now-playing changes push an immediate
    /// reload via `WidgetDataWriter`.
    private static let refreshIntervalMinutes = 10

    func placeholder(in context: Context) -> NowPlayingStandByEntry {
        NowPlayingStandByEntry(date: Date(), nowPlaying: nil, fallbackGame: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingStandByEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingStandByEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(
            byAdding: .minute,
            value: Self.refreshIntervalMinutes,
            to: Date()
        ) ?? Date()
        completion(Timeline(entries: [currentEntry()], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> NowPlayingStandByEntry {
        NowPlayingStandByEntry(
            date: Date(),
            nowPlaying: WidgetSharedDefaults.loadNowPlaying(),
            fallbackGame: WidgetSharedDefaults.loadRecentGames().first
        )
    }
}

// MARK: - Views

struct NowPlayingStandByView: View {
    let entry: NowPlayingStandByEntry

    var body: some View {
        ZStack {
            artworkBackground
            contentOverlay
        }
        .containerBackground(.black, for: .widget)
        .widgetURL(PVLibraryScreenURL)
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let uiImage = entry.albumArtBackgroundImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .overlay(.black.opacity(0.45))
        } else if let uiImage = entry.fallbackArtworkImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .overlay(.black.opacity(0.55))
        } else {
            Color.black
        }
    }

    @ViewBuilder
    private var contentOverlay: some View {
        VStack(spacing: 6) {
            Spacer()
            albumArtThumbnail
            trackInfo
            Spacer()
        }
        .padding(12)
    }

    @ViewBuilder
    private var albumArtThumbnail: some View {
        if let uiImage = entry.albumArtThumbnailImage {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
        } else {
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 60, height: 60)
        }
    }

    @ViewBuilder
    private var trackInfo: some View {
        if let track = entry.nowPlaying {
            VStack(spacing: 3) {
                Text(track.trackTitle)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                if let artist = track.artistName {
                    Text(artist)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
            }
        } else {
            VStack(spacing: 3) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.6))
                Text(WidgetLocalizedStrings.brandName)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Widget

struct NowPlayingStandByWidget: Widget {
    static let kind = "com.provenance-emu.widget.nowplaying-standby"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NowPlayingStandByProvider()) { entry in
            NowPlayingStandByView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.now-playing-standby.display-name", defaultValue: "Now Playing — StandBy", comment: "Now Playing StandBy widget display name"))
        .description(
            String(
                localized: "widget.now-playing-standby.description",
                defaultValue: "Shows album art and track info while game music plays. Designed for nightstand use in StandBy mode.",
                comment: "Now Playing StandBy widget description"
            )
        )
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    NowPlayingStandByWidget()
} timeline: {
    NowPlayingStandByEntry(
        date: Date(),
        nowPlaying: WidgetNowPlayingEntry(
            trackTitle: "Gusty Garden Galaxy",
            artistName: "Mahito Yokota",
            albumTitle: "Super Mario Galaxy"
        ),
        fallbackGame: nil
    )
    NowPlayingStandByEntry(date: Date(), nowPlaying: nil, fallbackGame: nil)
}
#endif
