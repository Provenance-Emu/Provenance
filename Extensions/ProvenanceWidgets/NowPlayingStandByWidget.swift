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

// MARK: - Timeline Entry

struct NowPlayingStandByEntry: TimelineEntry {
    let date: Date
    let nowPlaying: WidgetNowPlayingEntry?
    let fallbackGame: WidgetGameEntry?
    /// Pre-loaded album art bytes for the now-playing track. Nil when unavailable.
    /// Populated by the timeline provider to avoid synchronous disk I/O during view rendering.
    let albumArtImageData: Data?
    /// Pre-loaded artwork bytes for the fallback game (shown when nothing is playing).
    /// Populated by the timeline provider to avoid synchronous disk I/O during view rendering.
    let fallbackArtworkImageData: Data?
}

// MARK: - Timeline Provider

struct NowPlayingStandByProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingStandByEntry {
        NowPlayingStandByEntry(date: Date(), nowPlaying: nil, fallbackGame: nil, albumArtImageData: nil, fallbackArtworkImageData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingStandByEntry) -> Void) {
        let nowPlaying = WidgetSharedDefaults.loadNowPlaying()
        let fallbackGame = WidgetSharedDefaults.loadRecentGames().first
        let albumArtData = nowPlaying?.albumArtPath.flatMap { WidgetSharedDefaults.artworkData(forRelativePath: $0) }
        let fallbackData = fallbackGame?.artworkPath.flatMap { WidgetSharedDefaults.artworkData(forRelativePath: $0) }
        let entry = NowPlayingStandByEntry(
            date: Date(),
            nowPlaying: nowPlaying,
            fallbackGame: fallbackGame,
            albumArtImageData: albumArtData,
            fallbackArtworkImageData: fallbackData
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingStandByEntry>) -> Void) {
        let nowPlaying = WidgetSharedDefaults.loadNowPlaying()
        let fallbackGame = WidgetSharedDefaults.loadRecentGames().first
        let albumArtData = nowPlaying?.albumArtPath.flatMap { WidgetSharedDefaults.artworkData(forRelativePath: $0) }
        let fallbackData = fallbackGame?.artworkPath.flatMap { WidgetSharedDefaults.artworkData(forRelativePath: $0) }
        let entry = NowPlayingStandByEntry(
            date: Date(),
            nowPlaying: nowPlaying,
            fallbackGame: fallbackGame,
            albumArtImageData: albumArtData,
            fallbackArtworkImageData: fallbackData
        )
        // Use a 10-minute fallback refresh; immediate updates use WidgetCenter.reloadAllTimelines()
        // via WidgetDataWriter when now-playing changes.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
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
        .widgetURL(URL(string: "provenance://screen/library"))
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let data = entry.albumArtImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .overlay(.black.opacity(0.45))
        } else if let data = entry.fallbackArtworkImageData, let uiImage = UIImage(data: data) {
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
        if let data = entry.albumArtImageData, let uiImage = UIImage(data: data) {
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
                Text("Provenance")
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
        .configurationDisplayName("Now Playing — StandBy")
        .description("Shows album art and track info while game music plays. Designed for nightstand use in StandBy mode.")
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
        fallbackGame: nil,
        albumArtImageData: nil,
        fallbackArtworkImageData: nil
    )
    NowPlayingStandByEntry(date: Date(), nowPlaying: nil, fallbackGame: nil, albumArtImageData: nil, fallbackArtworkImageData: nil)
}
#endif
