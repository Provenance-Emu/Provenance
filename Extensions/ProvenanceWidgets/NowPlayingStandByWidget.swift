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
import WidgetKit

// MARK: - Timeline Entry

struct NowPlayingStandByEntry: TimelineEntry {
    let date: Date
    let nowPlaying: WidgetNowPlayingEntry?
    let fallbackGame: WidgetGameEntry?
}

// MARK: - Timeline Provider

struct NowPlayingStandByProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingStandByEntry {
        NowPlayingStandByEntry(date: Date(), nowPlaying: nil, fallbackGame: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingStandByEntry) -> Void) {
        let entry = NowPlayingStandByEntry(
            date: Date(),
            nowPlaying: WidgetSharedDefaults.loadNowPlaying(),
            fallbackGame: WidgetSharedDefaults.loadRecentGames().first
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingStandByEntry>) -> Void) {
        let entry = NowPlayingStandByEntry(
            date: Date(),
            nowPlaying: WidgetSharedDefaults.loadNowPlaying(),
            fallbackGame: WidgetSharedDefaults.loadRecentGames().first
        )
        // Poll frequently so track changes show quickly
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 2, to: Date()) ?? Date()
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
        .widgetURL(URL(string: "provenance://nowplaying"))
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let track = entry.nowPlaying,
           let path = track.albumArtPath,
           let url = WidgetSharedDefaults.artworkURL(forRelativePath: path),
           let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
                .overlay(.black.opacity(0.45))
        } else if let game = entry.fallbackGame,
                  let path = game.artworkPath,
                  let url = WidgetSharedDefaults.artworkURL(forRelativePath: path),
                  let uiImage = UIImage(contentsOfFile: url.path) {
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
        if let track = entry.nowPlaying,
           let path = track.albumArtPath,
           let url = WidgetSharedDefaults.artworkURL(forRelativePath: path),
           let uiImage = UIImage(contentsOfFile: url.path) {
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
        fallbackGame: nil
    )
    NowPlayingStandByEntry(date: Date(), nowPlaying: nil, fallbackGame: nil)
}
#endif
