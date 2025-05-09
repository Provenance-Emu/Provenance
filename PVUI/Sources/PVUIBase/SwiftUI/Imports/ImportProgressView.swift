import SwiftUI
import PVLibrary
import PVSettings
import PVThemes
import Defaults
import PVSupport
import PVLogging
#if DEBUG
import PVLibrary // For CoreDataStack, CloudSyncManager
import PVPrimitives // For ProgressInfo, FileRecoveryState
#endif

/// A view that displays the progress of importing games and iCloud sync status.
/// Reflects an older UI style with an external ViewModel.
public struct ImportProgressView: View {
    // MARK: - Properties

    /// Use the external, updated ViewModel.
    @StateObject private var viewModel: ImportProgressViewModel

    /// The game importer to track (passed to ViewModel).
    public var gameImporter: any GameImporting

    /// The updates controller (passed from parent, ViewModel might observe its effects via gameImporter or notifications).
    @ObservedObject public var updatesController: PVGameLibraryUpdatesController

    /// Callback when the view is tapped.
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
        // Initialize the external ViewModel. iCloudSyncEnabled is now handled internally by the ViewModel.
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(gameImporter: gameImporter, updatesController: updatesController))
    }

    // Convenience initializer (if still needed, ensure it aligns with the primary one)
    // If updatesController is not directly used by the View or its specific new logic,
    // and only gameImporter is passed to ViewModel, this might be simplified or removed
    // if the primary init serves all cases.
    // For now, keeping it consistent with existing API.
    public init(
        gameImporter: any GameImporting,
        updatesController: PVGameLibraryUpdatesController
    ) {
        self.init(gameImporter: gameImporter, updatesController: updatesController, onTap: nil)
    }

    // MARK: - Body

    public var body: some View {
        // Logic to show/hide based on ViewModel's `shouldShow` property
        // which consolidates import queue, iCloud sync, and other activities.
        Group{
            if viewModel.shouldShow {
                contentView
                    .onTapGesture {
                        onTap?()
                    }
                    .fixedSize(horizontal: false, vertical: true) // Fix the height to prevent layout shifts
                // The old code had .animation(nil, value: viewModel.importQueueItems.count)
                // We might want a more general animation value like viewModel.shouldShow or a combination.
                // For now, respecting the old structure's animation target if relevant.
                // Let's use shouldShow as the primary driver for appearance/disappearance animation.
                    .animation(.easeInOut(duration: 0.3), value: viewModel.shouldShow)
                    .transition(.opacity.combined(with: .move(edge: .bottom))) // Example transition
            } else {
                EmptyView()
                    .frame(height: 10) // Match old behavior of occupying minimal space
            }
        }
        // .onAppear and .onChange for setupTracking are no longer needed as ViewModel handles iCloudSyncEnabled internally.
        // .onAppear {
        //     ILOG("ImportProgressView: Appeared. Setting up tracking.")
        //     viewModel.setupTracking(iCloudEnabled: iCloudSyncEnabled)
        // }
        // .onChange(of: iCloudSyncEnabled) { newValue in
        //     ILOG("ImportProgressView: iCloudSyncEnabled changed to \(newValue). Updating tracking.")
        //     viewModel.setupTracking(iCloudEnabled: newValue)
        // }
        .onDisappear {
            ILOG("ImportProgressView: Disappeared. Cleaning up.")
            // ViewModel's deinit should handle major cleanup if it's an @StateObject.
            // Explicit cleanup can be called if needed for specific tasks before deinit.
            // viewModel.cleanup() // The old view model called this.
        }
    }
    
    // MARK: - Helper Views
    private var headerView: some View {
        // Header with count of imports
        HStack {
            // Assuming viewModel.importQueueItems is correctly populated by the external ViewModel
            Text(viewModel.importQueueItems.isEmpty ? "" : "IMPORTING \(viewModel.importQueueItems.count) FILES")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.retroBlue)
            Spacer()

            // Show processing status if any item is processing
            if viewModel.importQueueItems.contains(where: { $0.status == .processing }) {
                Text("PROCESSING")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.retroPink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.retroBlack.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.retroPink, lineWidth: 1)
                            )
                    )
            } else if !viewModel.importQueueItems.isEmpty {
                Text("WAITING")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.retroGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.retroBlack.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color.retroGreen, lineWidth: 1)
                            )
                    )
            }
        }
    }
    
    private var progressBarsView: some View {
        // Progress bar for imports with retrowave styling
        // This progress reflects importQueueItems only, as per old UI
        ZStack(alignment: .leading) {
            // Background track
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.retroBlack.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .frame(height: 12)

            // Progress fill - count both completed and failed items for progress
            let processedCount = viewModel.importQueueItems.filter { $0.status == .success || $0.status.isFailure }.count
            let progress = viewModel.importQueueItems.isEmpty ? 0.0 : Double(processedCount) / Double(viewModel.importQueueItems.count)

            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [.retroPink, .retroBlue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: max(12, progress * geometry.size.width), height: 8)
                .cornerRadius(4)
                .padding(2)
            }
            .frame(height: 12)
        }
    }
    
    @ViewBuilder
    private var statusDetailsView: some View {
        // Group was here, let ViewBuilder handle the conditional content directly
        if viewModel.showOldProgressSystem {
            // Existing logic for game importer based status - NOW USES VIEWMODEL
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    statusCountView(title: "Total", count: viewModel.totalImportFileCount, color: .gray) // Use viewModel and title:
                    statusCountView(title: "Processed", count: viewModel.processedFilesCount, color: .blue) // Use viewModel and title:
                    statusCountView(title: "New", count: viewModel.newFilesCount, color: .green) // Use viewModel and title:
                }
                HStack(spacing: 10) {
                    statusCountView(title: "Errors", count: viewModel.errorFilesCount, color: .red) // Use viewModel and title:
                    Spacer() // Ensure it takes available space if needed
                }
                if let currentImport = viewModel.importProgress?.detail, !currentImport.isEmpty {
                    Text(currentImport)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundColor(.gray)
                }
            }
        } else {
            // Newer logic using viewModel counts directly
            HStack(spacing: 20) {
                statusCountView(title: "Total", count: viewModel.totalImportFileCount, color: .gray)
                statusCountView(title: "Processed", count: viewModel.processedFilesCount, color: .blue)
                statusCountView(title: "New", count: viewModel.newFilesCount, color: .green)
                statusCountView(title: "Errors", count: viewModel.errorFilesCount, color: .red)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.retroBlack.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }

    // MARK: - Content Views

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            progressBarsView
            statusDetailsView // Existing view for counts
            
            // New section for scrollable log messages
            if !viewModel.statusLogMessages.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(viewModel.statusLogMessages) { message in
                            Text(message.message)
                                .font(.caption2)
                                .foregroundColor(messageColor(for: message.type))
                                .lineLimit(2) // Optionally limit lines per message
                        }
                    }
                    .padding(.horizontal, 4) // Padding inside the scroll content
                }
                .frame(maxHeight: 80) // Limit the height of the log area
                .background(Color.black.opacity(0.1)) // Optional background for distinction
                .cornerRadius(4)
            }

            // Conditionally show iCloud sync status
            if viewModel.iCloudSyncEnabledSetting {
                iCloudSyncStatusView
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(RetroTheme.retroBlackClear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [.retroPink, .retroBlue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .compositingGroup() // Ensures proper rendering of the transparency and overlay
        .shadow(color: .retroPink.opacity(0.5), radius: 5, x: 0, y: 3)
    }
    
    // Helper function to determine message color based on type
    private func messageColor(for type: StatusMessageManager.StatusMessage.MessageType) -> Color {
        switch type {
        case .info: return .gray
        case .success: return .retroGreen
        case .warning: return .retroOrange
        case .error: return .red
        case .progress: return .retroPurple
        }
    }

    /// iCloud sync status view - compact version (from old UI structure)
    private var iCloudSyncStatusView: some View {
        HStack {
            Image(systemName: "icloud")
                .foregroundColor(.retroBlue)
            Text(viewModel.iCloudStatusMessage) // Use property directly, not a binding for Text
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Spacer()
            if viewModel.isSyncing { // Already using isSyncing here which is correct
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.7)
            }
        }
    }

    /// File Recovery Status View (Placeholder)
    private var fileRecoveryStatusView: some View {
        HStack {
            Image(systemName: "bandage") // Example icon
                .foregroundColor(.orange)
            Text("File Recovery: \(viewModel.fileRecoveryStateDisplayString)") // Use display string
                .font(.system(size: 10))
                .foregroundColor(.gray)
            Spacer()
            if viewModel.fileRecoveryProgress != nil {
                ProgressView(value: Double(viewModel.fileRecoveryProgress?.current ?? 0), total: Double(viewModel.fileRecoveryProgress?.total ?? 1))
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 50)
            }
        }
    }

    // MARK: - Status Count View (Helper from old structure)
    private func statusCountView(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color.opacity(0.7))
        }
    }

    // MARK: - Log Display View (from old structure)
    private var logDisplayView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LOGS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.retroPurple) // Or another distinct retro color
                .padding(.bottom, 2)
            
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(viewModel.logMessages) { logEntry in
                        HStack(alignment: .top) {
                            Text("[" + logEntry.timestamp.formatted(date: .omitted, time: .standard) + "]")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(.gray)
                            Text(logEntry.message)
                                .font(.system(size: 8))
                                .foregroundColor(colorForLogType(logEntry.type))
                                .lineLimit(nil) // Allow multiple lines
                                .fixedSize(horizontal: false, vertical: true) // Wrap text
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading) // Ensure VStack takes full width for alignment
            }
            .frame(maxHeight: 80) // Limit the height of the scrollable log area
            .background(Color.black.opacity(0.2))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.retroPurple.opacity(0.5), lineWidth: 1)
            )
        }
        .padding(.top, 6)
    }

    private func colorForLogType(_ type: StatusMessageManager.StatusMessage.MessageType) -> Color {
        switch type {
        case .info:
            return .retroBlue
        case .warning:
            return .yellow // Or Color.retroOrange if available
        case .error:
            return .retroPink
        case .success:
            return .retroGreen
        case .progress:
            return .retroPurple // Using retroPurple for progress messages
        }
    }
}
