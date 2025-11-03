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
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Sync Analytics")
                    .font(.headline)
                    .foregroundColor(.retroPink)

                Spacer()

                if #available(tvOS 17.0, *) {
                    Button(action: {
                        analytics.resetAnalytics()
                    }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundColor(.retroBlue)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                } else {
                    // Fallback on earlier versions
                }
            }

            // Main stats
            VStack(alignment: .leading, spacing: 8) {
                // Sync counts
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Syncs")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(analytics.totalSyncs)")
                            .font(.title3)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Successful")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(analytics.successfulSyncs)")
                            .font(.title3)
                            .foregroundColor(.green)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Failed")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(analytics.failedSyncs)")
                            .font(.title3)
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)

                Divider()
                    .background(Color.retroPurple.opacity(0.5))

                // Data transferred
                HStack {
                    VStack(alignment: .leading) {
                        Text("Uploaded")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(ByteCountFormatter.string(fromByteCount: analytics.totalBytesUploaded, countStyle: .file))
                            .font(.subheadline)
                            .foregroundColor(.retroBlue)
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Downloaded")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(ByteCountFormatter.string(fromByteCount: analytics.totalBytesDownloaded, countStyle: .file))
                            .font(.subheadline)
                            .foregroundColor(.retroBlue)
                    }
                }
                .padding(.vertical, 4)

                Divider()
                    .background(Color.retroPurple.opacity(0.5))

                // Timing information
                HStack {
                    VStack(alignment: .leading) {
                        Text("Last Sync")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Group {
                            if let lastSyncTime = analytics.lastSyncTime {
                                if #available(iOS 15.0, tvOS 15.0, *) {
                                    Text(lastSyncTime.formatted(date: .abbreviated, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                } else {
                                    Text(formatDate(lastSyncTime))
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                            } else {
                                Text("Never")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Avg Duration")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(String(format: "%.2fs", analytics.averageSyncDuration))
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                }
                .padding(.vertical, 4)

                // Current operation if syncing
                if analytics.isSyncing {
                    Divider()
                        .background(Color.retroPurple.opacity(0.5))

                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.retroPink)
                            .rotationEffect(.degrees(analytics.isSyncing ? 360 : 0))
                            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: analytics.isSyncing)

                        Text("Syncing: \(analytics.currentSyncOperation)")
                            .font(.subheadline)
                            .foregroundColor(.retroPink)
                    }
                    .padding(.vertical, 4)
                }

                // Last error if any
                if let error = analytics.lastSyncError {
                    Divider()
                        .background(Color.retroPurple.opacity(0.5))

                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)

                        Text("Last Error: \(error.localizedDescription)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)

            // Sync history toggle
            if #available(tvOS 17.0, *) {
                Button(action: {
                    withAnimation {
                        showHistory.toggle()
                    }
                }) {
                    HStack {
                        Text(showHistory ? "Hide Sync History" : "Show Sync History")
                            .font(.subheadline)
                            .foregroundColor(.retroBlue)

                        Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                            .foregroundColor(.retroBlue)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
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
            Text("Recent Sync Operations")
                .font(.subheadline)
                .foregroundColor(.retroPurple)
                .padding(.bottom, 4)

            if analytics.syncHistory.isEmpty {
                Text("No sync history available")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(analytics.syncHistory) { operation in
                    syncHistoryItemView(operation)
                }
            }
        }
        .padding()
        .background(Color.retroBlack.opacity(0.3))
        .cornerRadius(10)
    }

    private func syncHistoryItemView(_ operation: SyncOperation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Status icon
                Image(systemName: operation.success ? "checkmark.circle" : "xmark.circle")
                    .foregroundColor(operation.success ? .green : .red)

                // Operation name
                Text(operation.operation)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Spacer()

                // Timestamp
                Group {
                    if #available(iOS 15.0, tvOS 15.0, *) {
                        Text(operation.timestamp.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.gray)
                    } else {
                        Text(formatTime(operation.timestamp))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            // Details
            HStack {
                Text("Duration: \(String(format: "%.2fs", operation.duration))")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                if operation.bytesUploaded > 0 {
                    Text("↑ \(ByteCountFormatter.string(fromByteCount: operation.bytesUploaded, countStyle: .file))")
                        .font(.caption)
                        .foregroundColor(.retroBlue)
                }

                if operation.bytesDownloaded > 0 {
                    Text("↓ \(ByteCountFormatter.string(fromByteCount: operation.bytesDownloaded, countStyle: .file))")
                        .font(.caption)
                        .foregroundColor(.retroBlue)
                }
            }

            // Error message if any
            if let errorMessage = operation.errorMessage {
                Text("Error: \(errorMessage)")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .padding(.top, 2)
            }

            Divider()
                .background(Color.retroPurple.opacity(0.3))
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
