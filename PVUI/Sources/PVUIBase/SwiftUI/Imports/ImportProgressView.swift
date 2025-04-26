//
//  ImportProgressView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/22/24.
//

import Combine
import Defaults
import PVLibrary
import PVLogging
import PVPrimitives
import PVSettings
import PVThemes
import PVUIBase
import Perception
import SwiftUI

/// A view that displays the progress of importing games and sync operations
/// Shows progress bars at the top and recent log messages below
public struct ImportProgressView: View {
    /// ViewModel to handle mutable state
    @StateObject private var viewModel: ImportProgressViewModel

    // MARK: - Properties

    /// The game importer to track
    public var gameImporter: any GameImporting

    /// The updates controller for accessing the import queue
    @ObservedObject public var updatesController: PVGameLibraryUpdatesController

    /// iCloud sync tracking
    @Default(.iCloudSync) private var iCloudSyncEnabled

    /// Maximum number of log messages to display
    private let maxLogMessages = 10

    /// Callback when the view is tapped
    public var onTap: (() -> Void)?

    // MARK: - Initialization

    public init(
        gameImporter: any GameImporting,
        updatesController: PVGameLibraryUpdatesController,
        onTap: (() -> Void)? = nil
    ) {
        self.gameImporter = gameImporter
        self.updatesController = updatesController
        self.onTap = onTap
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(gameImporter: gameImporter))
    }

    // MARK: - Body

    public var body: some View {
        WithPerceptionTracking {
            if viewModel.shouldShow || !viewModel.importQueueItems.isEmpty
                || (iCloudSyncEnabled && viewModel.isSyncing) || !viewModel.logMessages.isEmpty
            {
                contentView
                    .onTapGesture {
                        onTap?()  // Call the tap callback if provided
                    }
            } else {
                // Empty spacer with a fixed height when no items to prevent layout shifts
                Color.clear.frame(height: 10)
            }
        }
        // Disable animations on this section to prevent flickering
        .animation(nil, value: viewModel.importQueueItems.count)
        .onAppear {
            ILOG("ImportProgressView: View appeared")
            // Initialize the view model
            viewModel.setupTracking(iCloudEnabled: iCloudSyncEnabled)
            viewModel.startAnimations()
        }
        .onDisappear {
            ILOG("ImportProgressView: View disappeared")
            // Clean up resources
            viewModel.cleanup()
        }
    }

    // MARK: - Content Views

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress bars section
            VStack(alignment: .leading, spacing: 8) {
                // Active progress bars
                ForEach(viewModel.activeProgressBars) { progressInfo in
                    progressBar(for: progressInfo)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.7),
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )

            // Log messages section
            if !viewModel.logMessages.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.logMessages.prefix(maxLogMessages)) { message in
                            HStack(spacing: 8) {
                                // Icon
                                Image(systemName: iconForMessageType(message.type))
                                    .font(.system(size: 12))
                                    .foregroundColor(colorForMessageType(message.type))

                                // Message text
                                Text(message.message)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)

                                Spacer()

                                // Timestamp
                                Text(timeString(from: message.timestamp))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(4)
                        }
                    }
                }
                .frame(maxHeight: 300)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.85))
        .cornerRadius(12)
        .shadow(color: Color.retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
    }

    // Progress bar component
    private func progressBar(for progress: ProgressInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title and progress count
            HStack {
                Text(progress.detail ?? "Progress")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(progressColor(for: progress.detail))

                Spacer()

                Text("\(progress.current)/\(progress.total) (\(Int(progress.progress * 100))%)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(progressColor(for: progress.detail).opacity(0.9))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 8)
                        .cornerRadius(4)

                    // Progress fill
                    Rectangle()
                        .fill(progressColor(for: progress.detail))
                        .frame(width: max(4, CGFloat(progress.progress) * geometry.size.width), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Helper Methods

    /// Get the color for a progress bar based on its detail
    private func progressColor(for detail: String?) -> Color {
        guard let detail = detail else { return .retroBlue }

        let lowercaseDetail = detail.lowercased()
        if lowercaseDetail.contains("recovery") { return .retroBlue }
        if lowercaseDetail.contains("cleanup") { return .retroPink }
        if lowercaseDetail.contains("cache") { return .retroPurple }
        if lowercaseDetail.contains("cloudkit") || lowercaseDetail.contains("icloud") {
            return .retroBlue
        }
        return .retroBlue
    }

    /// Get the icon for a message type
    private func iconForMessageType(_ type: StatusMessage.MessageType) -> String {
        switch type {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .progress: return "arrow.clockwise.circle"
        }
    }

    /// Get the color for a message type
    private func colorForMessageType(_ type: StatusMessage.MessageType) -> Color {
        switch type {
        case .info: return .retroBlue
        case .success: return .green
        case .warning: return .orange
        case .error: return .retroPink
        case .progress: return .retroPurple
        }
    }

    /// Format a timestamp as a string
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Comprehensive sync status view - compact version
    private var syncStatusView: some View {
        HStack(spacing: 12) {
            // Import Status
            if !viewModel.importQueueItems.isEmpty {
                syncStatusItem(
                    title: "IMPORTING",
                    count: viewModel.importQueueItems.count,
                    detail: "Files",
                    color: .retroBlue,
                    iconName: "square.and.arrow.down",
                    isActive: true
                )
            }

            // CloudKit Sync Status
            if iCloudSyncEnabled {
                switch viewModel.syncStatus {
                case .idle:
                    if viewModel.pendingUploads > 0 || viewModel.pendingDownloads > 0 {
                        syncStatusItem(
                            title: "CLOUDKIT",
                            count: viewModel.pendingUploads + viewModel.pendingDownloads,
                            detail: "Pending Sync",
                            color: .retroPurple,
                            iconName: "icloud",
                            isActive: false
                        )
                    }
                case .syncing:
                    syncStatusItem(
                        title: "CLOUDKIT",
                        count: nil,
                        detail: "Syncing",
                        color: .retroBlue,
                        iconName: "icloud",
                        isActive: true
                    )
                case .initialSync:
                    let progress = viewModel.initialSyncProgress
                    let total =
                    (progress?.romsTotal ?? 0) + (progress?.saveStatesTotal ?? 0)
                    + (progress?.biosTotal ?? 0)
                    let current =
                    (progress?.romsCompleted ?? 0) + (progress?.saveStatesCompleted ?? 0)
                    + (progress?.biosCompleted ?? 0)

                    syncStatusItem(
                        title: "CLOUDKIT",
                        count: current,
                        total: total,
                        detail: "Initial Sync",
                        color: .retroPink,
                        iconName: "icloud",
                        isActive: true
                    )
                case .uploading:
                    syncStatusItem(
                        title: "CLOUDKIT",
                        count: viewModel.pendingUploads,
                        detail: "Uploading",
                        color: .retroBlue,
                        iconName: "arrow.up.icloud",
                        isActive: true
                    )
                case .downloading:
                    syncStatusItem(
                        title: "CLOUDKIT",
                        count: viewModel.pendingDownloads,
                        detail: "Downloading",
                        color: .retroBlue,
                        iconName: "arrow.down.icloud",
                        isActive: true
                    )
                case .error(let error):
                    syncStatusItem(
                        title: "CLOUDKIT",
                        count: nil,
                        detail: "Error: \(error.localizedDescription)",
                        color: .retroPink,
                        iconName: "exclamationmark.icloud",
                        isActive: false
                    )
                case .disabled:
                    EmptyView()
                }
            }

            // File Recovery Status
            if viewModel.fileRecoveryState == .inProgress {
                if let progress = viewModel.fileRecoveryProgress {
                    syncStatusItem(
                        title: "RECOVERY",
                        count: progress.current,
                        total: progress.total,
                        detail: progress.detail ?? "Files",
                        color: .retroPurple,
                        iconName: "arrow.clockwise.icloud",
                        isActive: true
                    )
                } else {
                    syncStatusItem(
                        title: "RECOVERY",
                        count: nil,
                        detail: "In Progress",
                        color: .retroPurple,
                        iconName: "arrow.clockwise.icloud",
                        isActive: true
                    )
                }
            }
        }
        .font(.system(size: 8))
    }

    /// Helper view for status counts
    @ViewBuilder
    private func statusCountView(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    /// Create a sync status item with icon, title, and progress info
    private func syncStatusItem(
        title: String, count: Int?, total: Int? = nil, detail: String, color: Color, iconName: String,
        isActive: Bool
    ) -> some View {
        HStack(spacing: 6) {
            // Icon with glow effect
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.7), radius: isActive ? 3 : 1, x: 0, y: 0)

            VStack(alignment: .leading, spacing: 2) {
                // Title with status
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(color)

                    if isActive {
                        // Animated activity indicator
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                            .opacity(viewModel.glowOpacity)
                    }
                }

                // Progress detail
                HStack(spacing: 4) {
                    if let count = count {
                        if let total = total {
                            Text("\(count)/\(total)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(color.opacity(0.8))
                        } else {
                            Text("\(count)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(color.opacity(0.8))
                        }
                    }

                    Text(detail)
                        .font(.system(size: 8))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.7), color.opacity(0.3)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Public Methods

    /// Start animation for progress bar
    func startAnimation() {
        // Delegate to view model
        viewModel.startAnimations()
    }

    /// Add a log message
    func addLogMessage(_ message: String, type: StatusMessage.MessageType = .info) {
        // Delegate to view model
        viewModel.addLogMessage(message, type: type)
    }

    /// Update a progress bar or add a new one
    func updateProgress(id: String, detail: String?, current: Int, total: Int) {
        // Delegate to view model
        viewModel.updateProgress(id: id, detail: detail, current: current, total: total)
    }

    /// Remove a progress bar
    func removeProgress(id: String) {
        // Delegate to view model
        viewModel.removeProgress(id: id)
    }

}
