//
//  CloudKitSyncAnalyticsView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLibrary
import PVLogging
import Combine

/// A reusable view component that displays CloudKit sync analytics
public struct CloudKitSyncAnalyticsView: View {
    // MARK: - Properties

    @ObservedObject private var analytics = CloudKitSyncAnalytics.shared
    @State private var showHistory = false

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header — retrowave section style
            HStack {
                Text("SYNC ANALYTICS")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.retroPink)

                Spacer()

                if #available(tvOS 17.0, *) {
                    Button(action: {
                        analytics.resetAnalytics()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text("RESET")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.5)
                        }
                        .foregroundColor(.retroPurple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.retroPurple.opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.retroPurple.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    // Fallback on earlier versions
                }
            }

            // Main stats
            VStack(alignment: .leading, spacing: 8) {
                // Sync counts — neon stat tiles
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TOTAL")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(analytics.totalSyncs)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SUCCESS")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(analytics.successfulSyncs)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.retroGreen)
                            .shadow(color: .retroGreen.opacity(0.4), radius: 4)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("FAILED")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(analytics.failedSyncs)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(.retroOrange)
                            .shadow(color: .retroOrange.opacity(0.4), radius: 4)
                    }
                }
                .padding(.vertical, 4)

                // Gradient divider
                Rectangle()
                    .fill(LinearGradient(colors: [.retroPurple.opacity(0.4), .retroPink.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)

                // Data transferred
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UPLOADED")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.5))
                        Text(ByteCountFormatter.string(fromByteCount: analytics.totalBytesUploaded, countStyle: .file))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.retroBlue)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DOWNLOADED")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.5))
                        Text(ByteCountFormatter.string(fromByteCount: analytics.totalBytesDownloaded, countStyle: .file))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.retroBlue)
                    }
                }
                .padding(.vertical, 4)

                // Gradient divider
                Rectangle()
                    .fill(LinearGradient(colors: [.retroPurple.opacity(0.4), .retroPink.opacity(0.2)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)

                // Timing information
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LAST SYNC")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.5))
                        Group {
                            if let lastSyncTime = analytics.lastSyncTime {
                                if #available(iOS 15.0, tvOS 15.0, *) {
                                    Text(lastSyncTime.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                } else {
                                    Text(formatDate(lastSyncTime))
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            } else {
                                Text("Never")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AVG DURATION")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                            .foregroundColor(.white.opacity(0.5))
                        Text(String(format: "%.2fs", analytics.averageSyncDuration))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 4)

                // Current operation if syncing
                if analytics.isSyncing {
                    Rectangle()
                        .fill(LinearGradient(colors: [.retroPink.opacity(0.5), .retroPurple.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.retroPink)
                            .shadow(color: .retroPink.opacity(0.6), radius: 4)
                            .rotationEffect(.degrees(analytics.isSyncing ? 360 : 0))
                            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: analytics.isSyncing)

                        Text("Syncing: \(analytics.currentSyncOperation)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.retroPink)
                    }
                    .padding(.vertical, 4)
                }

                // Last error if any
                if let error = analytics.lastSyncError {
                    Rectangle()
                        .fill(LinearGradient(colors: [.retroOrange.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)

                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.retroOrange)
                            .shadow(color: .retroOrange.opacity(0.5), radius: 3)

                        Text(error.localizedDescription)
                            .font(.system(size: 12))
                            .foregroundColor(.retroOrange.opacity(0.9))
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.retroPurple.opacity(0.4), Color.retroPink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )

            // Sync history toggle
            if #available(tvOS 17.0, *) {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showHistory.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12, weight: .semibold))
                        Text(showHistory ? "HIDE HISTORY" : "SHOW HISTORY")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.8)
                        Spacer()
                        Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.retroCyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.retroCyan.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.retroCyan.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 4)
            } else {
                // Fallback on earlier versions
            }

            // Sync history
            if showHistory {
                syncHistoryView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Subviews

    private var syncHistoryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT OPERATIONS")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundColor(.retroPink)
                .padding(.bottom, 2)

            if analytics.syncHistory.isEmpty {
                Text("No sync history available")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .padding()
            } else {
                ForEach(analytics.syncHistory) { operation in
                    syncHistoryItemView(operation)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.retroPurple.opacity(0.3), Color.retroBlue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func syncHistoryItemView(_ operation: SyncOperation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Status icon with glow
                Image(systemName: operation.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(operation.success ? .retroGreen : .retroOrange)
                    .shadow(color: (operation.success ? Color.retroGreen : Color.retroOrange).opacity(0.5), radius: 3)

                // Operation name
                Text(operation.operation)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                // Timestamp
                Group {
                    if #available(iOS 15.0, tvOS 15.0, *) {
                        Text(operation.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    } else {
                        Text(formatTime(operation.timestamp))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }

            // Details
            HStack {
                Text("\(String(format: "%.2fs", operation.duration))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                if operation.bytesUploaded > 0 {
                    Text("↑ \(ByteCountFormatter.string(fromByteCount: operation.bytesUploaded, countStyle: .file))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.retroBlue)
                }

                if operation.bytesDownloaded > 0 {
                    Text("↓ \(ByteCountFormatter.string(fromByteCount: operation.bytesDownloaded, countStyle: .file))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.retroCyan)
                }
            }

            // Error message if any
            if let errorMessage = operation.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.retroOrange.opacity(0.9))
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helper Functions

    /// Format date for older iOS versions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Format time for older iOS versions
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#if DEBUG
struct CloudKitSyncAnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.retroDarkBlue.edgesIgnoringSafeArea(.all)

            CloudKitSyncAnalyticsView()
                .padding()
        }
    }
}
#endif
