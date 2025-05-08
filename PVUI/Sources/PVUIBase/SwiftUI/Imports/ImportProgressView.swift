import SwiftUI
import PVLibrary
import PVSettings
import PVThemes
import Defaults

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

    /// iCloud sync preference from user settings.
    @Default(.iCloudSync) private var iCloudSyncEnabled

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
        // Initialize the external ViewModel
        self._viewModel = StateObject(wrappedValue: ImportProgressViewModel(gameImporter: gameImporter))
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
        // Call setupTracking in onAppear and when iCloudSyncEnabled changes.
        // The ViewModel's init handles initial subscriptions.
        // onAppear ensures the ViewModel has the latest iCloudSyncEnabled state from this View instance.
        .onAppear {
            ILOG("ImportProgressView: Appeared. Setting up tracking.")
            viewModel.setupTracking(iCloudEnabled: iCloudSyncEnabled)
        }
        .onChange(of: iCloudSyncEnabled) { newValue in
            ILOG("ImportProgressView: iCloudSyncEnabled changed to \(newValue). Updating tracking.")
            viewModel.setupTracking(iCloudEnabled: newValue)
        }
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
            let processedCount = viewModel.importQueueItems.filter { $0.status == .success || $0.status == .failure }.count
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
    
    private var statusDetailsView: some View {
        // Status details for import queue
        HStack(spacing: 12) {
            statusCountView(count: viewModel.importQueueItems.filter { $0.status == .queued }.count, label: "QUEUED", color: .gray)
            statusCountView(count: viewModel.importQueueItems.filter { $0.status == .processing }.count, label: "PROCESSING", color: .retroBlue)
            statusCountView(count: viewModel.importQueueItems.filter { $0.status == .success }.count, label: "COMPLETED", color: .green)
            statusCountView(count: viewModel.importQueueItems.filter { $0.status == .failure }.count, label: "FAILED", color: .retroPink)
            Spacer()
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
        VStack(alignment: .leading, spacing: 6) {

            headerView
            
            // iCloud sync status (only show if iCloud sync is enabled by user AND active in ViewModel)
            if iCloudSyncEnabled && viewModel.isSyncing {
                iCloudSyncStatusView
            }

            progressBarsView

            statusDetailsView

            // Log display (new section)
            if !viewModel.logMessages.isEmpty {
                logDisplayView
            }
        }
        .padding(12)
        .background(
            backgroundView
        )
        .shadow(color: Color.retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
    }

    /// iCloud sync status view - compact version (from old UI structure)
    private var iCloudSyncStatusView: some View {
        // Sourcing data from the external viewModel (viewModel.syncStatus, viewModel.initialSyncProgress)
        Group {
            switch viewModel.syncStatus {
            case .idle:
                Text("iCloud Sync: Idle")
                    .foregroundColor(.white)
            case .syncing:
                HStack {
                    Text("iCloud Sync: Syncing")
                        .foregroundColor(.retroBlue)
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .retroBlue)).scaleEffect(0.7)
                }
            case .initialSync:
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Initial iCloud Sync")
                            .foregroundColor(.retroPink)
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .retroPink)).scaleEffect(0.7)
                    }
                    if let progress = viewModel.initialSyncProgress { // This is CloudKitInitialSyncProgress from ViewModel
                        VStack(alignment: .leading, spacing: 2) {
                            if progress.romsTotal > 0 { Text("ROMs: \(progress.romsCompleted)/\(progress.romsTotal)").font(.caption).foregroundColor(.retroBlue) }
                            if progress.saveStatesTotal > 0 { Text("Save States: \(progress.saveStatesCompleted)/\(progress.saveStatesTotal)").font(.caption).foregroundColor(.retroPurple) }
                            if progress.biosTotal > 0 { Text("BIOS: \(progress.biosCompleted)/\(progress.biosTotal)").font(.caption).foregroundColor(.retroPink) }
                            if progress.batteryStatesTotal > 0 { Text("Battery States: \(progress.batteryStatesCompleted)/\(progress.batteryStatesTotal)").font(.caption).foregroundColor(.retroBlue) }
                            if progress.screenshotsTotal > 0 { Text("Screenshots: \(progress.screenshotsCompleted)/\(progress.screenshotsTotal)").font(.caption).foregroundColor(.retroPurple) }
                            if progress.deltaSkinsTotal > 0 { Text("Delta Skins: \(progress.deltaSkinsCompleted)/\(progress.deltaSkinsTotal)").font(.caption).foregroundColor(.retroPink) }
                            ProgressView(value: progress.overallProgress).progressViewStyle(LinearProgressViewStyle(tint: .retroPink))
                        }
                    }
                }
            case .uploading:
                HStack {
                    Text("iCloud Sync: Uploading")
                        .foregroundColor(.retroPink)
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .retroPink)).scaleEffect(0.7)
                }
            case .downloading:
                HStack {
                    Text("iCloud Sync: Downloading")
                        .foregroundColor(.retroPurple)
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .retroPurple)).scaleEffect(0.7)
                }
            case .error(let error):
                Text("iCloud Sync Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .lineLimit(1)
            case .disabled:
                Text("iCloud Sync: Disabled by User Setting or Error")
                    .foregroundColor(.gray)
            case .initializing:
                HStack {
                    Text("iCloud Sync: Initializing")
                        .foregroundColor(.retroOrange)
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .retroBlue)).scaleEffect(0.7)
                }
            }
        }
        .font(.system(size: 8))
    }

    /// Helper view for status counts (from old UI structure)
    @ViewBuilder
    private func statusCountView(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(color.opacity(0.7))
        }
    }

    /// Log display view (newly added)
    @ViewBuilder
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

// PreviewProvider if needed for iterative UI development
#if DEBUG
struct ImportProgressView_Previews: PreviewProvider {
    static let mockImporter = MockGameImporter() // Requires a mock GameImporter
    static let mockUpdatesController = PVGameLibraryUpdatesController(gameImporter: mockImporter)
    static let mockViewModel = ImportProgressViewModel(gameImporter: mockImporter)

    static var previews: some View {
        // Setup mockViewModel with some data for preview
        let _ = { // IIFE for setup
            mockViewModel.importQueueItems = [
                ImportQueueItem(url: URL(string: "file:///game1.zip")!, fileType: .zip),
                ImportQueueItem(url: URL(string: "file:///game2.nes")!, fileType: .game),
                ImportQueueItem(url: URL(string: "file:///game3.gb")!, fileType: .game)
            ]
            mockViewModel.logMessages = [
                StatusMessageManager.StatusMessage(message: "This is an informational message.", type: .info),
                StatusMessageManager.StatusMessage(message: "Warning: Something might be wrong.", type: .warning),
                StatusMessageManager.StatusMessage(message: "Error: Something went wrong! Attempting to fix this very long error message that should wrap around correctly and display fully.", type: .error),
                StatusMessageManager.StatusMessage(message: "Successfully completed an operation.", type: .success)
            ]
            mockViewModel.syncStatus = .initialSync
            mockViewModel.initialSyncProgress = .DUMMY_FOR_PREVIEW // Using the static dummy data
            mockViewModel.isSyncing = true
            mockViewModel.shouldShow = true // Make sure it's visible for preview
        }()

        return VStack(spacing: 20) {
            Text("Import Progress View Preview")
                .font(.title)

            ImportProgressView(
                gameImporter: mockImporter,
                updatesController: mockUpdatesController
            )
            // You can also inject the pre-configured mockViewModel directly if the View supports it for previews
            // Or, ensure the View's own @StateObject uses the mockImporter that populates the ViewModel correctly.
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .onAppear {
             // This ensures the preview displays the view as it would with live data
             // The viewModel inside the previewed ImportProgressView will call setupTracking
        }
    }
}
#endif
