//
//  GameLiveActivityWidget.swift
//  ProvenanceWidgets
//
//  Live Activity / Dynamic Island UI for an active Provenance gameplay session.
//
//  Renders three presentation surfaces:
//    • Compact (Dynamic Island pill) — game title + system badge + pause indicator
//    • Expanded (Dynamic Island panel) — cover art, title, system, elapsed time,
//      achievement progress bar (when RA is active), last-save hint
//    • Lock Screen (expanded notification-style) — same content as expanded
//
//  The `ActivityConfiguration` here references `GameActivityAttributes` from
//  PVLiveActivities, which the ProvenanceWidgets extension imports.
//

#if os(iOS)
import ActivityKit
import PVLiveActivities
import SwiftUI
import WidgetKit

// MARK: - Widget declaration

// iOS 17+ deployment target means ActivityKit (16.2+) is always available.
struct GameLiveActivityWidget: Widget {
    static let kind = "com.provenance-emu.live-activity.game"

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GameActivityAttributes.self) { context in
            // Lock Screen / StandBy presentation
            GameLockScreenLiveActivityView(context: context)
                .containerBackground(.fill.tertiary, for: .widget)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded panel (long-press or tap on pill)
                DynamicIslandExpandedRegion(.leading) {
                    GameArtworkThumbnail(artworkPath: context.attributes.artworkPath)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.gameTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        Text(context.attributes.systemName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: context.state.isPaused ? "pause.fill" : "gamecontroller.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(context.state.isPaused ? .orange : .green)
                        Text(context.state.elapsedTimeString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let fraction = context.state.achievementFraction {
                        AchievementProgressBar(
                            fraction: fraction,
                            points: context.state.achievementPoints ?? 0,
                            total: context.state.achievementTotal ?? 0
                        )
                        .padding(.horizontal, 4)
                    }
                }
            } compactLeading: {
                // Compact pill — left side: system icon or artwork thumbnail
                GameArtworkThumbnail(artworkPath: context.attributes.artworkPath)
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
            } compactTrailing: {
                // Compact pill — right side: pause icon or elapsed time
                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                } else {
                    Text(context.state.elapsedTimeString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } minimal: {
                // Minimal view (two activities competing — show just the game icon)
                GameArtworkThumbnail(artworkPath: context.attributes.artworkPath)
                    .frame(width: 16, height: 16)
                    .clipShape(Circle())
            }
        }
    }
}

// MARK: - Lock Screen view

private struct GameLockScreenLiveActivityView: View {
    let context: ActivityViewContext<GameActivityAttributes>

    var body: some View {
        HStack(spacing: 12) {
            GameArtworkThumbnail(artworkPath: context.attributes.artworkPath)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(context.attributes.gameTitle)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Spacer()
                    StatusPill(isPaused: context.state.isPaused)
                }
                Text(context.attributes.systemName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let fraction = context.state.achievementFraction {
                    AchievementProgressBar(
                        fraction: fraction,
                        points: context.state.achievementPoints ?? 0,
                        total: context.state.achievementTotal ?? 0
                    )
                } else if let points = context.state.achievementPoints, points > 0 {
                    Label("\(points) pts unlocked", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }

                HStack {
                    Label(context.state.elapsedTimeString, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let saveDate = context.state.lastSaveDate {
                        Spacer()
                        Label {
                            Text(saveDate, style: .relative) + Text(" ago")
                        } icon: {
                            Image(systemName: "square.and.arrow.down")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Reusable sub-views

/// Displays box art loaded from an App Group–relative path, falling back to a
/// controller icon when artwork is unavailable or not yet downloaded.
private struct GameArtworkThumbnail: View {
    let artworkPath: String?

    var body: some View {
        if let path = artworkPath,
           let containerURL = FileManager.default.containerURL(
               forSecurityApplicationGroupIdentifier: pvWidgetAppGroupID
           ) {
            let fileURL = containerURL.appendingPathComponent(path)
            if let data = try? Data(contentsOf: fileURL),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallbackIcon
            }
        } else {
            fallbackIcon
        }
    }

    private var fallbackIcon: some View {
        Image(systemName: "gamecontroller.fill")
            .font(.system(size: 24))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
    }
}

/// Thin progress bar showing RetroAchievements unlock progress.
private struct AchievementProgressBar: View {
    let fraction: Double
    let points: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.25))
                        .frame(height: 4)
                    Capsule()
                        .fill(.yellow)
                        .frame(width: geo.size.width * fraction, height: 4)
                }
            }
            .frame(height: 4)
            Text("\(points) / \(total) pts")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// Small pill showing "Playing" (green) or "Paused" (orange).
private struct StatusPill: View {
    let isPaused: Bool

    var body: some View {
        Label(
            isPaused ? "Paused" : "Playing",
            systemImage: isPaused ? "pause.fill" : "play.fill"
        )
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundStyle(isPaused ? .orange : .green)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule().fill((isPaused ? Color.orange : Color.green).opacity(0.15))
        )
    }
}

// MARK: - App Group ID (widget-local copy)

/// Local copy of the App Group identifier used to resolve artwork paths.
/// Must stay in sync with `PVAppIntents/AppGroupID.swift` and `WidgetSharedDefaults.appGroupID`.
private var pvWidgetAppGroupID: String {
    let raw = Bundle.main.infoDictionary?["APP_GROUP_IDENTIFIER"] as? String
    guard let raw, !raw.isEmpty, !raw.contains("$(") else {
        return "group.org.provenance-emu.provenance"
    }
    return raw
}

// MARK: - Preview

#Preview("Lock Screen", as: .content, using: GameActivityAttributes(
    gameTitle: "Super Mario World",
    systemName: "SNES",
    gameMD5: "preview",
    artworkPath: nil
)) {
    GameLiveActivityWidget()
} contentStates: {
    GameActivityAttributes.ContentState(isPaused: false, elapsedSeconds: 2700)
    GameActivityAttributes.ContentState(isPaused: true, elapsedSeconds: 4500, achievementPoints: 120, achievementTotal: 500)
}
#endif
