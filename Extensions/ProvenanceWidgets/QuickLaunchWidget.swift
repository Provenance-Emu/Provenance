//
//  QuickLaunchWidget.swift
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

struct QuickLaunchEntry: TimelineEntry {
    let date: Date
    let game: WidgetGameEntry?
    let gameCount: Int
    /// Pre-loaded artwork bytes for the most-recently-played game. Nil when unavailable.
    /// Populated by the timeline provider to avoid synchronous disk I/O during view rendering.
    let artworkImageData: Data?
}

// MARK: - Timeline Provider

struct QuickLaunchProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickLaunchEntry {
        QuickLaunchEntry(date: Date(), game: nil, gameCount: 0, artworkImageData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickLaunchEntry) -> Void) {
        let games = WidgetSharedDefaults.loadRecentGames()
        let game = games.first
        let imageData = game?.artworkPath.flatMap { WidgetSharedDefaults.artworkData(forRelativePath: $0) }
        let entry = QuickLaunchEntry(
            date: Date(),
            game: game,
            gameCount: WidgetSharedDefaults.loadGameCount(),
            artworkImageData: imageData
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickLaunchEntry>) -> Void) {
        let games = WidgetSharedDefaults.loadRecentGames()
        let game = games.first
        let imageData = game?.artworkPath.flatMap { WidgetSharedDefaults.artworkData(forRelativePath: $0) }
        let entry = QuickLaunchEntry(
            date: Date(),
            game: game,
            gameCount: WidgetSharedDefaults.loadGameCount(),
            artworkImageData: imageData
        )
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Views

struct QuickLaunchCircularView: View {
    let entry: QuickLaunchEntry

    var body: some View {
        ZStack {
            if let data = entry.artworkImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(.secondary)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.primary)
            }
        }
        .widgetLabel {
            Text(entry.game?.title ?? "Provenance")
                .truncationMode(.tail)
        }
    }
}

struct QuickLaunchRectangularView: View {
    let entry: QuickLaunchEntry

    var body: some View {
        HStack(spacing: 8) {
            if let data = entry.artworkImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 28))
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.game?.title ?? "Provenance")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if let game = entry.game {
                    Text(game.systemName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let lastPlayed = game.lastPlayedDate {
                        Text(lastPlayed.relativeDescription)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("\(entry.gameCount) games")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuickLaunchInlineView: View {
    let entry: QuickLaunchEntry

    var body: some View {
        if let game = entry.game {
            Label {
                Text(game.title)
            } icon: {
                Image(systemName: "gamecontroller.fill")
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

struct QuickLaunchEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: QuickLaunchEntry

    var deepLinkURL: URL {
        if let game = entry.game {
            var components = URLComponents()
            components.scheme = "provenance"
            components.host = "open"
            components.queryItems = [URLQueryItem(name: "md5", value: game.id)]
            return components.url ?? URL(string: "provenance://")!
        }
        return URL(string: "provenance://")!
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                QuickLaunchCircularView(entry: entry)
            case .accessoryRectangular:
                QuickLaunchRectangularView(entry: entry)
            case .accessoryInline:
                QuickLaunchInlineView(entry: entry)
            default:
                QuickLaunchCircularView(entry: entry)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(deepLinkURL)
    }
}

// MARK: - Widget

struct QuickLaunchWidget: Widget {
    static let kind = "com.provenance-emu.widget.quicklaunch"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: QuickLaunchProvider()) { entry in
            QuickLaunchEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Launch")
        .description("Tap to launch your last-played game.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Date Helper

private extension Date {
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Preview

#Preview(as: .accessoryRectangular) {
    QuickLaunchWidget()
} timeline: {
    QuickLaunchEntry(
        date: Date(),
        game: WidgetGameEntry(
            id: "preview",
            title: "Super Mario World",
            systemName: "SNES",
            artworkPath: nil,
            lastPlayedDate: Date(timeIntervalSinceNow: -7200)
        ),
        gameCount: 42,
        artworkImageData: nil
    )
}
#endif
