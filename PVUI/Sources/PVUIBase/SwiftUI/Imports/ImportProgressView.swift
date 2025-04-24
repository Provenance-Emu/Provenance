//
//  ImportProgressView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVLibrary
import PVThemes
import Perception
import Combine
import PVSettings
import Defaults
import PVPrimitives

/// A view that displays the progress of importing games
/// Auto-hides when all items are completed or errored
public struct ImportProgressView: View {
    /// ViewModel to handle mutable state
    @StateObject private var viewModel: ViewModel
    // MARK: - Properties
    
    /// The game importer to track
    public var gameImporter: any GameImporting
    
    /// The updates controller for accessing the import queue
    @ObservedObject public var updatesController: PVGameLibraryUpdatesController
    
    /// iCloud sync tracking
    @Default(.iCloudSync) private var iCloudSyncEnabled
    
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
        self._viewModel = StateObject(wrappedValue: ViewModel(gameImporter: gameImporter))
    }
    
    // MARK: - Body
    
    public var body: some View {
        // Fixed height approach to prevent flickering
        VStack {
            WithPerceptionTracking {
                if !viewModel.importQueueItems.isEmpty || (iCloudSyncEnabled && viewModel.isSyncing) {
                    contentView
                        .onTapGesture {
                            onTap?()
                        }
                        .fixedSize(horizontal: false, vertical: true) // Fix the height to prevent layout shifts
                } else {
                    // Empty spacer with a fixed height when no items to prevent layout shifts
                    Color.clear.frame(height: 10)
                }
            }
        }
        // Disable animations on this section to prevent flickering
        .animation(nil, value: viewModel.importQueueItems.count)
        .onAppear {
            ILOG("ImportProgressView: View appeared")
            // Initialize the view model
            viewModel.setupTracking(iCloudEnabled: iCloudSyncEnabled)
        }
        .onDisappear {
            ILOG("ImportProgressView: View disappeared")
            // Clean up resources
            viewModel.cleanup()
        }
    }
    
    // MARK: - Content Views
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with count of imports
            HStack {
                WithPerceptionTracking {
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
                    } else {
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
            
            // iCloud sync status (only show if iCloud sync is enabled)
            if iCloudSyncEnabled && viewModel.isSyncing {
                iCloudSyncStatusView
            }
            
            // Progress bar with retrowave styling
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
                WithPerceptionTracking {
                    let processedCount = viewModel.importQueueItems.filter { $0.status == .success || $0.status == .failure }.count
                    let progress = viewModel.importQueueItems.isEmpty ? 0.0 : Double(processedCount) / Double(viewModel.importQueueItems.count)
                    
                    // Create a GeometryReader to get the actual width of the container
                    GeometryReader { geometry in
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        // Calculate width as a percentage of the available width
                        // Use max to ensure a minimum visible width
                        .frame(width: max(12, progress * geometry.size.width), height: 8)
                        .cornerRadius(4)
                        .padding(2)
                    }
                    // Set a fixed height for the GeometryReader
                    .frame(height: 12)
                }
            }
            
            // Status details
            WithPerceptionTracking {
                HStack(spacing: 12) {
                    statusCountView(count: viewModel.importQueueItems.filter { $0.status == .queued }.count, label: "QUEUED", color: .gray)
                    statusCountView(count: viewModel.importQueueItems.filter { $0.status == .processing }.count, label: "PROCESSING", color: .retroBlue)
                    statusCountView(count: viewModel.importQueueItems.filter { $0.status == .success }.count, label: "COMPLETED", color: .green)
                    statusCountView(count: viewModel.importQueueItems.filter { $0.status == .failure }.count, label: "FAILED", color: .retroPink)
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
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
        )
        .shadow(color: Color.retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
    }
    
    /// iCloud sync status view - compact version
    private var iCloudSyncStatusView: some View {
        WithPerceptionTracking {
            HStack(spacing: 8) {
                Image(systemName: "icloud")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.retroBlue)
                
                Text("iCLOUD")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.retroBlue)
                
                // Show sync counts in a compact format
                HStack(spacing: 8) {
                    if viewModel.pendingDownloads > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8))
                            Text("\(viewModel.pendingDownloads)")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.retroBlue)
                    }
                    
                    if viewModel.pendingUploads > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 8))
                            Text("\(viewModel.pendingUploads)")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.retroPink)
                    }
                    
                    if viewModel.newFilesCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "plus")
                                .font(.system(size: 8))
                            Text("\(viewModel.newFilesCount)")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundColor(.retroPurple)
                    }
                }
                
                // Animated indicator when syncing
                if viewModel.isSyncing {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 8))
                        .foregroundColor(.retroPink)
                        .rotationEffect(Angle(degrees: viewModel.animatedProgressOffset))
                        .animation(
                            Animation.linear(duration: 2.0)
                                .repeatForever(autoreverses: false),
                            value: viewModel.animatedProgressOffset
                        )
                        .onAppear {
                            viewModel.startAnimation()
                        }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.retroBlack.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 0.5
                            )
                    )
            )
        }
    }
    
    /// Helper view for status counts
    @ViewBuilder
    private func statusCountView(count: Int, label: String, color: Color) -> some View {
        if count > 0 {
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(color)
                
                Text(label)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(color.opacity(0.7))
            }
        }
    }
    
    /// Update visibility based on queue state - UNUSED, keeping for reference
    private func updateVisibility(for queue: [ImportQueueItem]) {
        // This function is no longer used - we're relying on SwiftUI's conditional rendering instead
        // Check if all items are completed or errored
        let allDone = queue.allSatisfy { $0.status == .success || $0.status == .failure }
        
        if allDone {
            // If all items are done, log it
            ILOG("ImportProgressView: All items done")
        }
    }
    
    /// Initial refresh of the import queue
    private func initialRefresh() {
        Task {
            // Get the current import queue
            let queue = await gameImporter.importQueue
            
            // Update on the main thread
            await MainActor.run {
                ILOG("ImportProgressView: Initial refresh with \(queue.count) items")
                
                // Update the view model's queue items
                viewModel.importQueueItems = queue
                
                // Log queue state for debugging
                if !queue.isEmpty {
                    ILOG("ImportProgressView: Initial refresh - Queue has \(queue.count) items")
                }
            }
        }
    }
    
    // MARK: - ViewModel
    
    /// ViewModel class to handle mutable state
    class ViewModel: ObservableObject {
        // MARK: - Properties
        
        /// The game importer to track
        private let gameImporter: any GameImporting
        
        // No longer need the updates controller here
        
        /// Track iCloud sync activity
        @Published var pendingDownloads = 0
        @Published var pendingUploads = 0
        @Published var newFilesCount = 0
        @Published var isSyncing = false
        
        /// Subscriptions for iCloud sync tracking
        private var syncSubscriptions = Set<AnyCancellable>()
        
        /// State to hold the import queue items
        @Published var importQueueItems: [ImportQueueItem] = []
        
        // Using the existing ImportQueueItem model from PVLibrary
        
        /// Timer for hiding the view after a delay
        private var hideTimer: AnyCancellable?
        
        /// Animation states for retrowave effects
        @Published var glowOpacity: Double = 0.7
        
        /// Animation state for iCloud sync progress
        @Published var animatedProgressOffset: CGFloat = 0
        
        // MARK: - Initialization
        
        init(gameImporter: any GameImporting) {
            self.gameImporter = gameImporter
            
            // Set up subscription to the import queue
            setupQueueSubscription()
        }
        
        // MARK: - Public Methods
        
        /// Start animation for progress bar
        func startAnimation() {
            animatedProgressOffset = 360
        }
        
        /// Setup tracking based on iCloud enabled status
        func setupTracking(iCloudEnabled: Bool) {
            // Setup queue subscription
            setupQueueSubscription()
            
            // Setup iCloud sync tracking if enabled
            if iCloudEnabled {
                Task {
                    await setupSyncTracking()
                }
            }
        }
        
        /// Clean up resources
        func cleanup() {
            // Cancel the timer when the view disappears
            hideTimer?.cancel()
            
            // Cancel sync subscriptions
            syncSubscriptions.forEach { $0.cancel() }
            syncSubscriptions.removeAll()
        }
        
        // MARK: - Private Methods
        
        /// Set up subscription to the import queue
        private func setupQueueSubscription() {
            // Get the queue publisher from the game importer
            if let gameImporter = gameImporter as? GameImporter {
                // Subscribe to the import queue publisher
                gameImporter.importQueuePublisher
                    .receive(on: RunLoop.main)
                    .sink { [weak self] queue in
                        guard let self = self else { return }
                        
                        // Update our queue items
                        self.importQueueItems = queue
                        
                        // Check if we should hide the view
                        self.checkHideTimer()
                    }
                    .store(in: &syncSubscriptions)
                
                // Initial fetch of queue
                Task {
                    let queue = await gameImporter.importQueue
                    await MainActor.run {
                        self.importQueueItems = queue
                        self.checkHideTimer()
                    }
                }
            }
        }
        
        /// Check if we should hide the view based on queue state
        private func checkHideTimer() {
            // If there are no items or all are completed/failed, hide the view after a delay
            if importQueueItems.isEmpty || importQueueItems.allSatisfy({ $0.status == .success || $0.status == .failure }) {
                // Only hide if there's also no iCloud sync activity
                if !isSyncing {
                    // Set a timer to hide the view after a delay
                    hideTimer?.cancel()
                    let timerSubscription = Timer.publish(every: 3, on: .main, in: .common)
                        .autoconnect()
                        .sink { [weak self] _ in
                            self?.hideTimer?.cancel()
                            self?.hideTimer = nil
                            self?.importQueueItems = []
                        }
                    
                    hideTimer = timerSubscription
                }
            } else {
                // Cancel any existing hide timer
                hideTimer?.cancel()
            }
        }
        
        /// Setup tracking for iCloud sync status
        private func setupSyncTracking() async {
            // Only setup if not already setup
            guard syncSubscriptions.isEmpty else { return }
            
            // Subscribe to the CloudKit syncer store for changes in active syncers
            let publisher = CloudKitSyncerStore.shared.syncersPublisher
            
            let subscription = publisher
                .receive(on: RunLoop.main)
                .sink { [weak self] (syncers: [SyncProvider]) in
                    Task {
                        // Clear existing syncer-specific subscriptions
                        self?.clearSyncerSubscriptions()
                        
                        // Set up tracking for each syncer
                        await self?.trackSyncers(syncers)
                    }
                }
            
            syncSubscriptions.insert(subscription)
            
            // Initial setup with current syncers
            if let syncers = getSyncers() {
                // Track the syncers
                await trackSyncers(syncers)
            }
        }
        
        /// Track all syncers for activity
        private func trackSyncers(_ syncers: [SyncProvider]) async {
            for syncer in syncers {
                // Track pending downloads
                let downloadSubscription = await syncer.pendingFilesToDownload.countPublisher
                    .receive(on: RunLoop.main)
                    .sink { [weak self] count in
                        self?.pendingDownloads = count
                        self?.updateSyncStatus()
                    }
                
                // Track new files
                let newFilesSubscription = await syncer.newFiles.countPublisher
                    .receive(on: RunLoop.main)
                    .sink { [weak self] count in
                        self?.newFilesCount = count
                        self?.updateSyncStatus()
                    }
                
                // Track uploaded files
                let uploadSubscription = await syncer.uploadedFiles.countPublisher
                    .receive(on: RunLoop.main)
                    .sink { [weak self] count in
                        self?.pendingUploads = count
                        self?.updateSyncStatus()
                    }
                
                // Add all subscriptions to our set
                syncSubscriptions.insert(downloadSubscription)
                syncSubscriptions.insert(newFilesSubscription)
                syncSubscriptions.insert(uploadSubscription)
            }
        }
        
        /// Clear syncer-specific subscriptions
        private func clearSyncerSubscriptions() {
            // Cancel all existing subscriptions
            syncSubscriptions.forEach { $0.cancel() }
            syncSubscriptions.removeAll()
        }
        
        /// Get active syncers from the CloudKit sync store
        private func getSyncers() -> [SyncProvider]? {
            // Get the actual syncer instances from the store
            return CloudKitSyncerStore.shared.activeSyncers
        }
        
        /// Update the sync status based on current counts
        private func updateSyncStatus() {
            isSyncing = pendingDownloads > 0 || pendingUploads > 0 || newFilesCount > 0
            
            // If sync status changed, update the view hiding logic
            checkHideTimer()
        }
    }
}
