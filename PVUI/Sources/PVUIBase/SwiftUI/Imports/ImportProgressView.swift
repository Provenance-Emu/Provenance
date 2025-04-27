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

    /// State to control the presentation of the status control view
    @State private var showStatusControl: Bool = false

    // MARK: - Initialization

    public init(
        gameImporter: any GameImporting,
        updatesController: PVGameLibraryUpdatesController
    ) {
        self.gameImporter = gameImporter
        self.updatesController = updatesController
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(gameImporter: gameImporter))
    }

    // MARK: - Body

    public var body: some View {
        WithPerceptionTracking {
            ZStack {
                if !viewModel.activeProgressBars.isEmpty {
                    contentView
                        .onTapGesture {
                            showStatusControl = true  // Show the status control view
                        }
                        .onAppear {
                            DLOG("ImportProgressView appeared with \(viewModel.activeProgressBars.count) progress bars and \(viewModel.logMessages.count) messages")
                        }
                        .fullScreenCover(isPresented: $showStatusControl) {
                            RetroStatusFullscreenView(isPresented: $showStatusControl)
                        }
                }
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
            // Compact header with title and sync status
            HStack {
                // Title with glow effect - smaller font
                Text("SYSTEM STATUS")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(RetroTheme.retroPink)
                    .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2, x: 0, y: 0)
                
                Spacer()
                
                // Sync status indicators - more compact
                if iCloudSyncEnabled && (viewModel.pendingUploads > 0 || viewModel.pendingDownloads > 0) {
                    HStack(spacing: 4) {
                        Image(systemName: "icloud")
                            .font(.system(size: 10))
                            .foregroundColor(RetroTheme.retroBlue)
                        
                        Text("\(viewModel.pendingUploads + viewModel.pendingDownloads)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            .padding(.bottom, 4)
            
            // Thinner divider with gradient
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(RetroTheme.retroGradient)
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            
            // Progress bars section - more compact
            VStack(alignment: .leading, spacing: 4) {
                if !viewModel.activeProgressBars.isEmpty {
                    // Active progress bars
                    ForEach(viewModel.activeProgressBars) { progressInfo in
                        progressBar(for: progressInfo)
                    }
                }
                // No else clause - don't show anything when there are no operations
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
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

            // Tap to view more indicator with pulsing animation
            HStack(spacing: 8) {
                Spacer()
                
                Text("Tap for detailed logs and controls")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.8))
                
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(RetroTheme.retroBlue)
                    .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 2, x: 0, y: 0)
                    .modifier(PulseEffect(animatableParameter: viewModel.glowOpacity))
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink.opacity(0.3), RetroTheme.retroBlue.opacity(0.3)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .padding(.vertical, 8)
        .background(
            ZStack {
                // Dark background
                Color.black.opacity(0.9)
                
                // Subtle grid pattern
                RetroTheme.RetroGridView()
                    .opacity(0.05)
            }
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(LinearGradient(
                    gradient: Gradient(colors: [RetroTheme.retroPink.opacity(0.5), RetroTheme.retroBlue.opacity(0.5)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1.5)
        )
        .shadow(color: RetroTheme.retroPink.opacity(0.4), radius: 8, x: 0, y: 2)
    }

    // Progress bar component
    private func progressBar(for progressInfo: ProgressInfo) -> some View {
        let progress = min(1.0, max(0.0, Double(progressInfo.current) / Double(progressInfo.total)))
        let percent = Int(progress * 100)
        let color = progressColor(for: progressInfo.detail)
        
        return VStack(alignment: .leading, spacing: 4) {
            // Operation label and progress percentage
            HStack {
                // Icon based on operation type
                Image(systemName: iconForOperation(progressInfo.detail ?? ""))
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.7), radius: 2, x: 0, y: 0)
                
                // Operation label
                Text(progressInfo.detail ?? "Operation")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                    .lineLimit(1)
                
                Spacer()
                
                // Progress fraction and percentage
                Text("\(progressInfo.current)/\(progressInfo.total) (\(percent)%)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(color.opacity(0.8))
            }
            
            // Progress bar
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 12)
                    .cornerRadius(6)
                
                // Progress fill
                Rectangle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [color, color.opacity(0.7)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(12, progress * UIScreen.main.bounds.width * 0.7), height: 12)
                    .cornerRadius(6)
                
                // Animated glow effect for active progress
                if progress < 1.0 && progress > 0.0 {
                    Rectangle()
                        .fill(color.opacity(0.4))
                        .frame(width: 20, height: 12)
                        .cornerRadius(6)
                        .offset(x: viewModel.animatedProgressOffset)
                        .mask(
                            Rectangle()
                                .frame(width: progress * UIScreen.main.bounds.width * 0.7, height: 12)
                                .cornerRadius(6)
                        )
                }
                
                // Small circle indicator
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .padding(.leading, 3)
            }
            .frame(height: 12)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(LinearGradient(
                    gradient: Gradient(colors: [color.opacity(0.5), color.opacity(0.2)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 0)
    }

    /// Get the color for a progress bar based on its detail
    private func progressColor(for detail: String?) -> Color {
        guard let detail = detail else { return .retroBlue }

        let lowercaseDetail = detail.lowercased()
        if lowercaseDetail.contains("recovery") { return .retroBlue }
        if lowercaseDetail.contains("cleanup") { return .retroPink }
        if lowercaseDetail.contains("cache") || lowercaseDetail.contains("optimization") { return .retroPurple }
        if lowercaseDetail.contains("extract") { return .retroPink }
        if lowercaseDetail.contains("scan") { return .retroPurple }
        if lowercaseDetail.contains("import") { return .retroPink }
        if lowercaseDetail.contains("download") { return .retroBlue }
        if lowercaseDetail.contains("upload") { return .retroPink }
        if lowercaseDetail.contains("sync") { return .retroBlue }
        if lowercaseDetail.contains("cloud") { return .retroBlue }
        if lowercaseDetail.contains("warning") { return .orange }
        
        return .retroBlue
    }

    /// Get the icon for a message type
    private func iconForMessageType(_ type: StatusMessage.MessageType) -> String {
        switch type {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .progress: return "arrow.clockwise.circle"
        }
    }

    /// Get the color for a message type
    private func colorForMessageType(_ type: StatusMessage.MessageType) -> Color {
        switch type {
        case .info: return .retroBlue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .progress: return .retroPurple
        }
    }

    /// Format a timestamp as a time string
    private func timeString(from date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Helper function to get icon for operation type
    private func iconForOperation(_ detail: String) -> String {
        let lowercaseDetail = detail.lowercased()
        
        if lowercaseDetail.contains("recovery") { return "arrow.clockwise.icloud" }
        if lowercaseDetail.contains("cleanup") { return "trash" }
        if lowercaseDetail.contains("cache") || lowercaseDetail.contains("optimization") { return "gear" }
        if lowercaseDetail.contains("extract") { return "doc.zipper" }
        if lowercaseDetail.contains("scan") { return "magnifyingglass" }
        if lowercaseDetail.contains("import") { return "square.and.arrow.down" }
        if lowercaseDetail.contains("download") { return "arrow.down.circle" }
        if lowercaseDetail.contains("upload") { return "arrow.up.circle" }
        if lowercaseDetail.contains("sync") { return "arrow.triangle.2.circlepath" }
        if lowercaseDetail.contains("cloud") { return "icloud" }
        if lowercaseDetail.contains("warning") { return "exclamationmark.triangle" }
        
        return "circle"
    }
    
    // Pulse animation effect
    struct PulseEffect: AnimatableModifier {
        var animatableParameter: Double
        
        func body(content: Content) -> some View {
            content
                .scaleEffect(1.0 + 0.1 * animatableParameter)
                .opacity(0.5 + 0.5 * animatableParameter)
        }
    }
    
    /// A fullscreen view that displays the RetroStatusControlView
    struct RetroStatusFullscreenView: View {
        // MARK: - Properties
        
        /// Binding to control the presentation of the view
        @Binding var isPresented: Bool
        
        // MARK: - Body
        
        var body: some View {
            ZStack {
                // Background with grid pattern for retrowave aesthetic
                RetroTheme.retroBlack
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        RetroTheme.RetroGridView()
                            .opacity(0.2)
                    )
                
                // Fixed header and scrollable content container
                VStack(alignment: .leading, spacing: 0) {
                    // Fixed header with close button
                    HStack {
                        Text("System Status")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(RetroTheme.retroPink)
                            .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 3, x: 0, y: 0)
                        
                        Spacer()
                        
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(RetroTheme.retroBlue)
                                .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 3, x: 0, y: 0)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(RetroTheme.retroDarkBlue.opacity(0.7))
                    .overlay(
                        Rectangle()
                            .frame(height: 2)
                            .foregroundStyle(RetroTheme.retroGradient)
                            .offset(y: 1),
                        alignment: .bottom
                    )
                    
                    // Scrollable content area
                    ScrollView {
                        // Status control view with fixed height to prevent jumping
                        RetroStatusControlView()
                            .padding()
                            .frame(minHeight: 400, alignment: .top) // Fixed minimum height to prevent jumping
                    }
                }
            }
        }
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
        
        // Force an update
        viewModel.objectWillChange.send()
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
        
        // Force the view to show
        DispatchQueue.main.async {
            self.viewModel.shouldShow = true
            self.viewModel.objectWillChange.send()
        }
    }

    /// Remove a progress bar
    func removeProgress(id: String) {
        // Delegate to view model
        viewModel.removeProgress(id: id)
    }

}
