//
//  NowPlayingWidget.swift
//  ProvenanceWidgets
//
//  Created by Joseph Mattiello on 3/19/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#if os(iOS)
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Timeline Entry

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let nowPlaying: WidgetNowPlayingEntry?
    let gameCount: Int
}

// MARK: - Timeline Provider

struct NowPlayingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), nowPlaying: nil, gameCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        let entry = NowPlayingEntry(
            date: Date(),
            nowPlaying: WidgetSharedDefaults.loadNowPlaying(),
            gameCount: WidgetSharedDefaults.loadGameCount()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let entry = NowPlayingEntry(
            date: Date(),
            nowPlaying: WidgetSharedDefaults.loadNowPlaying(),
            gameCount: WidgetSharedDefaults.loadGameCount()
        )
        // Refresh every 5 minutes so track info stays current
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Views

struct NowPlayingInlineView: View {
    let entry: NowPlayingEntry

    var body: some View {
        if let track = entry.nowPlaying {
            Label {
                if let artist = track.artistName {
                    Text("\(track.trackTitle) — \(artist)")
                } else {
                    Text(track.trackTitle)
                }
            } icon: {
                Image(systemName: "music.note")
            }
        } else {
            Label {
                Text("Provenance — \(entry.gameCount) games")
            } icon: {
                Image(systemName: "gamecontroller.fill")
            }
        }
    }
}

struct NowPlayingRectangularView: View {
    let entry: NowPlayingEntry

    var body: some View {
        HStack(spacing: 8) {
            albumArtView
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                if let track = entry.nowPlaying {
                    Text(track.trackTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    if let artist = track.artistName {
                        Text(artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let album = track.albumTitle {
                        Text(album)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                } else {
                    Text("Nothing Playing")
                        .font(.headline)
                        .lineLimit(1)
                    Text("Provenance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var albumArtView: some View {
        if let track = entry.nowPlaying,
           let path = track.albumArtPath,
           let url = WidgetSharedDefaults.artworkURL(forRelativePath: path),
           let uiImage = UIImage(contentsOfFile: url.path) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .foregroundStyle(.secondary)
        }
    }
}

struct NowPlayingEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: NowPlayingEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                NowPlayingInlineView(entry: entry)
            case .accessoryRectangular:
                NowPlayingRectangularView(entry: entry)
            default:
                NowPlayingInlineView(entry: entry)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "provenance://screen/library"))
    }
}

// MARK: - Widget

struct NowPlayingWidget: Widget {
    static let kind = "com.provenance-emu.widget.nowplaying"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NowPlayingProvider()) { entry in
            NowPlayingEntryView(entry: entry)
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the current game music track, or your library count when nothing is playing.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular])
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    NowPlayingWidget()
} timeline: {
    NowPlayingEntry(
        date: Date(),
        nowPlaying: WidgetNowPlayingEntry(
            trackTitle: "Dire Dire Docks",
            artistName: "Koji Kondo",
            albumTitle: "Super Mario 64"
        ),
        gameCount: 42
    )
    NowPlayingEntry(date: Date(), nowPlaying: nil, gameCount: 42)
}
#endif
