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
import PVLibrary

// MARK: - Timeline Entry

struct NowPlayingEntry: TimelineEntry {
    let date: Date
    let nowPlaying: WidgetNowPlayingEntry?
    let gameCount: Int

    /// Accessory-sized album art, decoded on demand from
    /// `WidgetNowPlayingEntry.albumArtPath` rather than carried as bytes in the entry.
    var albumArtImage: UIImage? {
        guard let path = nowPlaying?.albumArtPath else { return nil }
        return WidgetSharedDefaults.artworkImage(
            forRelativePath: path,
            maxPixelSize: WidgetArtworkPixelBudget.accessory
        )
    }
}

// MARK: - Timeline Provider

struct NowPlayingProvider: TimelineProvider {
    /// Fallback refresh cadence, in minutes. Immediate updates arrive via
    /// `WidgetCenter.reloadAllTimelines()` from `WidgetDataWriter`, so frequent polling
    /// would only waste background budget.
    private static let refreshIntervalMinutes = 60

    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), nowPlaying: nil, gameCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(
            byAdding: .minute,
            value: Self.refreshIntervalMinutes,
            to: Date()
        ) ?? Date()
        completion(Timeline(entries: [currentEntry()], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> NowPlayingEntry {
        NowPlayingEntry(
            date: Date(),
            nowPlaying: WidgetSharedDefaults.loadNowPlaying(),
            gameCount: WidgetSharedDefaults.loadGameCount()
        )
    }
}

// MARK: - Views

struct NowPlayingInlineView: View {
    let entry: NowPlayingEntry

    var body: some View {
        if let track = entry.nowPlaying {
            Label {
                if let artist = track.artistName {
                    Text(
                        String(
                            format: NSLocalizedString(
                                "widget.now-playing.track-line %@ — %@",
                                bundle: .main,
                                comment: "Now Playing title and artist line"
                            ),
                            locale: Locale.current,
                            track.trackTitle,
                            artist
                        )
                    )
                } else {
                    Text(track.trackTitle)
                }
            } icon: {
                Image(systemName: "music.note")
            }
        } else {
            Label {
                Text(
                    String(
                        format: NSLocalizedString(
                            "widget.now-playing.brand-games-count %lld",
                            bundle: .main,
                            comment: "Now Playing fallback branded game count"
                        ),
                        locale: Locale.current,
                        entry.gameCount
                    )
                )
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
                    Text(String(localized: "widget.now-playing.nothing-playing", defaultValue: "Nothing Playing", comment: "Now Playing empty title"))
                        .font(.headline)
                        .lineLimit(1)
                    Text(WidgetLocalizedStrings.brandName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var albumArtView: some View {
        if let uiImage = entry.albumArtImage {
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
        .widgetURL(PVLibraryScreenURL)
    }
}

// MARK: - Widget

struct NowPlayingWidget: Widget {
    static let kind = "com.provenance-emu.widget.nowplaying"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NowPlayingProvider()) { entry in
            NowPlayingEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "widget.now-playing.display-name", defaultValue: "Now Playing", comment: "Now Playing widget display name"))
        .description(
            String(
                localized: "widget.now-playing.description",
                defaultValue: "Shows the current game music track, or your library count when nothing is playing.",
                comment: "Now Playing widget description"
            )
        )
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
