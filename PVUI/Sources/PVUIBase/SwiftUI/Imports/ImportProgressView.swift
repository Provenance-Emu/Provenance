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
            // Header with count of imports or iCloud sync
            HStack {
                WithPerceptionTracking {
                    if !viewModel.importQueueItems.isEmpty {
                        Text("IMPORTING \(viewModel.importQueueItems.count) FILES")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.retroBlue)
                        Spacer()
                        
                        // Show processing status if any item is processing
                        if viewModel.importQueueItems.contains(where: { $0.status == .processing }) {
                            Text("PROCESSING")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.retroPink)
                        }
                    } else if iCloudSyncEnabled && viewModel.isSyncing {
                        Text("iCLOUD SYNC")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.retroBlue)
                        Spacer()
                    }
                }
            }
            
            // Progress bar for imports (only show if there are imports)
            if !viewModel.importQueueItems.isEmpty {
                // Simple progress view for now
                ProgressView()
                    .tint(Color.retroPink)
            }
            
            // Show iCloud sync status if enabled and active
            if iCloudSyncEnabled && (viewModel.isSyncing || !viewModel.importQueueItems.isEmpty) {
                iCloudSyncStatusView
            }
            
            // Import queue items list
            ForEach(viewModel.importQueueItems) { item in
                VStack(alignment: .leading) {
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Text(item.status.description)
                        .font(.system(size: 8))
                        .foregroundColor(item.status.color)
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    /// iCloud sync status view
    private var iCloudSyncStatusView: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "icloud")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.retroBlue)
                    
                    Text(viewModel.isSyncing ? "iCLOUD SYNC ACTIVE" : "iCLOUD SYNC READY")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.retroBlue)
                    
                    Spacer()
                    
                    // Show sync counts
                    if viewModel.pendingDownloads > 0 || viewModel.pendingUploads > 0 || viewModel.newFilesCount > 0 {
                        HStack(spacing: 8) {
                            if viewModel.pendingDownloads > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 10))
                                    Text("\(viewModel.pendingDownloads)")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.retroBlue)
                            }
                            
                            if viewModel.pendingUploads > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.circle")
                                        .font(.system(size: 10))
                                    Text("\(viewModel.pendingUploads)")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.retroPink)
                            }
                            
                            if viewModel.newFilesCount > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 10))
                                    Text("\(viewModel.newFilesCount)")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.retroPurple)
                            }
                        }
                    } else if viewModel.isSyncing {
                        // Show sync indicator when syncing but no counts
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                                .foregroundColor(.retroPink)
                        }
                    }
                }
                
                // Progress bar for iCloud sync - only show when actively syncing
                if viewModel.isSyncing {
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.retroBlack.opacity(0.7))
                            .frame(height: 4)
                        
                        // Progress indicator with animation
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPink]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 4)
                            .frame(width: 50)
                            .offset(x: viewModel.animatedProgressOffset)
                            .animation(
                                Animation.linear(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: viewModel.animatedProgressOffset
                            )
                            .onAppear {
                                viewModel.startAnimation()
                            }
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.retroBlack.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                LinearGradient(
                                    gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
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
            animatedProgressOffset = 100
        }
        
        /// Setup tracking based on iCloud enabled status
        func setupTracking(iCloudEnabled: Bool) {
            // Setup queue subscription
            setupQueueSubscription()
            
            // Setup iCloud sync tracking if enabled
            if iCloudEnabled {
                setupSyncTracking()
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
        private func setupSyncTracking() {
            // Only setup if not already setup
            guard syncSubscriptions.isEmpty else { return }
            
            // Subscribe to the syncer store for changes in active syncers
            let subscription = iCloudSyncerStore.shared.syncersPublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] syncers in
                    // Clear existing syncer-specific subscriptions
                    self?.clearSyncerSubscriptions()
                    
                    // Set up tracking for each syncer
                    self?.trackSyncers(syncers)
                }
            
            syncSubscriptions.insert(subscription)
            
            // Initial setup with current syncers
            if let syncers = getSyncers() {
                // Track the syncers
                trackSyncers(syncers)
            }
        }
        
        /// Track all syncers for activity
        private func trackSyncers(_ syncers: [iCloudContainerSyncer]) {
            for syncer in syncers {
                // Track pending downloads
                let downloadSubscription = syncer.pendingFilesToDownload.countPublisher
                    .receive(on: RunLoop.main)
                    .sink { [weak self] count in
                        self?.pendingDownloads = count
                        self?.updateSyncStatus()
                    }
                
                // Track new files
                let newFilesSubscription = syncer.newFiles.countPublisher
                    .receive(on: RunLoop.main)
                    .sink { [weak self] count in
                        self?.newFilesCount = count
                        self?.updateSyncStatus()
                    }
                
                // Track uploaded files
                let uploadSubscription = syncer.uploadedFiles.countPublisher
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
        
        /// Get active syncers from iCloudSync
        private func getSyncers() -> [iCloudContainerSyncer]? {
            // Get the actual syncer instances from the store
            return iCloudSyncerStore.shared.activeSyncers
        }
        
        /// Update the sync status based on current counts
        private func updateSyncStatus() {
            isSyncing = pendingDownloads > 0 || pendingUploads > 0 || newFilesCount > 0
            
            // If sync status changed, update the view hiding logic
            checkHideTimer()
        }
    }
}
