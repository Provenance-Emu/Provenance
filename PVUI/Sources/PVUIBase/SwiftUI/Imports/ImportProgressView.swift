//
//  ImportProgressView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 11/22/24.
//

import SwiftUI
import PVLibrary
import PVPrimitives
import Perception
import Combine
import PVSettings
import Defaults
import PVThemes
import PVLogging

/// A view that displays the progress of importing games and sync operations
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
    
    /// File recovery tracking
    @State private var fileRecoveryState: FileRecoveryState = .idle
    @State private var fileRecoveryProgress: ProgressInfo? = nil
    
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
        
        // Initialize file recovery state
        self.fileRecoveryState = .idle
        self.fileRecoveryProgress = nil
    }
    
    // MARK: - Body
    
    public var body: some View {
        // Fixed height approach to prevent flickering
        WithPerceptionTracking {
            if viewModel.shouldShow || !viewModel.importQueueItems.isEmpty || (iCloudSyncEnabled && viewModel.isSyncing) || fileRecoveryState == .inProgress {
                contentView
                    .onTapGesture {
                        onTap?() // Call the tap callback if provided
                    }
                    .onAppear {
                        viewModel.startAnimations()
                        setupNotificationObservers()
                    }
                    .onDisappear {
                        viewModel.cleanup()
                        NotificationCenter.default.removeObserver(self)
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
            headerView
            syncStatusRows
            progressRows
        }
        .padding(.vertical, 8)
        .background(RetroTheme.retroDarkBlue.opacity(0.8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.7)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.retroPink.opacity(0.3), radius: 5, x: 0, y: 0)
    }
    
    // Break up the complex view into smaller components
    private var headerView: some View {
        HStack {
            WithPerceptionTracking {
                if !viewModel.importQueueItems.isEmpty {
                    Text("ACTIVITY STATUS")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.retroPink)
                        .shadow(color: Color.retroPink.opacity(0.7), radius: 2, x: 0, y: 0)
                }
            }
            
            Spacer()
            
            // Cancel button if there are active operations
            if !viewModel.importQueueItems.isEmpty || viewModel.isSyncing || fileRecoveryState == .inProgress {
                Button {
                    // Cancel operation logic would go here
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.retroPink.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
        
    }
    
    private var syncStatusRows: some View {
        // Comprehensive sync status view
        ScrollView(.horizontal, showsIndicators: false) {
            syncStatusView
                .padding(.horizontal, 10)
        }
    }
    
    private var progressRows: some View {
        // Progress rows for active imports (limited to 2 for compactness)
        VStack(spacing: 4) {
            WithPerceptionTracking {
                ForEach(Array(viewModel.importQueueItems.filter { $0.status == .processing }.prefix(2)), id: \.id) { item in
                    // Simple progress row for now
                    HStack {
                        Text(item.url.lastPathComponent)
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        ProgressView()
                            .progressViewStyle(LinearProgressViewStyle(tint: .retroBlue))
                            .frame(width: 100)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
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
                    let total = (progress?.romsTotal ?? 0) + (progress?.saveStatesTotal ?? 0) + (progress?.biosTotal ?? 0)
                    let current = (progress?.romsCompleted ?? 0) + (progress?.saveStatesCompleted ?? 0) + (progress?.biosCompleted ?? 0)
                    
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
            if fileRecoveryState == .inProgress {
                if let progress = fileRecoveryProgress {
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
    private func syncStatusItem(title: String, count: Int?, total: Int? = nil, detail: String, color: Color, iconName: String, isActive: Bool) -> some View {
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
    
    /// Set up notification observers for file recovery
    private func setupNotificationObservers() {
        let nc = NotificationCenter.default
        
        // File recovery notifications
        nc.addObserver(forName: Notification.Name("iCloudFileRecoveryStarted"), object: nil, queue: .main) { [self] _ in
            fileRecoveryState = .inProgress
            fileRecoveryProgress = nil
        }
        
        nc.addObserver(forName: Notification.Name("iCloudFileRecoveryProgress"), object: nil, queue: .main) { [self] notification in
            guard let userInfo = notification.userInfo,
                  let currentNum = userInfo["current"] as? NSNumber,
                  let totalNum = userInfo["total"] as? NSNumber,
                  let message = userInfo["message"] as? String else { return }
            
            let current = currentNum.intValue
            let total = totalNum.intValue
            fileRecoveryProgress = ProgressInfo(current: current, total: total, detail: message)
        }
        
        nc.addObserver(forName: Notification.Name("iCloudFileRecoveryCompleted"), object: nil, queue: .main) { [self] _ in
            fileRecoveryState = .complete
        }
        
        nc.addObserver(forName: Notification.Name("iCloudFileRecoveryError"), object: nil, queue: .main) { [self] _ in
            fileRecoveryState = .error
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
        
        /// Track CloudKit sync progress
        @Published var currentCloudKitOperation: String = ""
        @Published var cloudKitProgress: Double = 0
        @Published var cloudKitIsActive: Bool = false
        
        /// The current sync status
        @Published var syncStatus: SyncStatus = .idle
        
        /// Initial sync progress
        @Published var initialSyncProgress: InitialSyncProgress? = nil
        
        /// Animation properties
        @Published var glowOpacity: Double = 0.7
        @Published var animatedProgressOffset: CGFloat = 0
        
        /// Flag to show/hide the view
        @Published var shouldShow: Bool = false
        
        /// Subscriptions for iCloud sync tracking
        private var syncSubscriptions = Set<AnyCancellable>()
        
        /// Cancellables for all subscriptions
        private var cancellables = Set<AnyCancellable>()
        
        /// State to hold the import queue items
        @Published var importQueueItems: [ImportQueueItem] = []
        
        /// Timer for hiding the view after a delay
        private var hideTimer: AnyCancellable?
        
        // MARK: - Initialization
        
        init(gameImporter: any GameImporting) {
            self.gameImporter = gameImporter
            
            // Set up queue subscription
            setupQueueSubscription()
            
            // Set up CloudKit subscriptions if iCloud sync is enabled
            if Defaults[.iCloudSync] {
                setupCloudKitSubscriptions()
            }
            
            // Start animations
            startAnimations()
        }
        
        // MARK: - Public Methods
        
        /// Start animation for progress bar
        func startAnimation() {
            // Animate the progress offset for indeterminate progress bars
            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                animatedProgressOffset = 360
            }
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
        
        /// Setup CloudKit subscriptions for sync status and progress
        private func setupCloudKitSubscriptions() {
            // Subscribe to sync status changes
            CloudSyncManager.shared.syncStatusPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] status in
                    self?.syncStatus = status
                    
                    // Update isSyncing flag based on status
                    self?.isSyncing = status != .idle && status != .disabled
                    
                    // Check if we should hide the view after status change
                    self?.checkHideTimer()
                }
                .store(in: &cancellables)
            
            // For now, set some placeholder values for pending uploads/downloads
            // In a real implementation, you would subscribe to actual publishers
            Timer.publish(every: 5, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    // Just for demonstration - in real app, use actual publishers
                    if self?.syncStatus == .uploading {
                        self?.pendingUploads = Int.random(in: 1...5)
                        self?.pendingDownloads = 0
                    } else if self?.syncStatus == .downloading {
                        self?.pendingUploads = 0
                        self?.pendingDownloads = Int.random(in: 1...5)
                    } else {
                        self?.pendingUploads = 0
                        self?.pendingDownloads = 0
                    }
                }
                .store(in: &cancellables)
            
            // Subscribe to notifications for initial sync progress
            NotificationCenter.default
                .publisher(for: Notification.Name("CloudKitInitialSyncProgress"))
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notification in
                    if let progress = notification.object as? InitialSyncProgress {
                        self?.initialSyncProgress = progress
                        // Make sure the view is visible during initial sync
                        self?.shouldShow = true
                    }
                }
                .store(in: &cancellables)
        }
        
        /// Start animations for the view
        func startAnimations() {
            // Create a repeating animation for the glow effect
            Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    withAnimation(.easeInOut(duration: 1.0)) {
                        if let opacity = self?.glowOpacity {
                            self?.glowOpacity = opacity == 0.7 ? 1.0 : 0.7
                        }
                    }
                }
                .store(in: &cancellables)
        }
        
        /// Clean up resources
        func cleanup() {
            // Cancel the timer when the view disappears
            hideTimer?.cancel()
            
            // Cancel sync subscriptions
            syncSubscriptions.forEach { $0.cancel() }
            syncSubscriptions.removeAll()
            
            // Cancel all cancellables
            cancellables.removeAll()
        }
        
        // MARK: - Private Methods
        
        /// Set up subscription to the import queue
        private func setupQueueSubscription() {
            // Use a timer to periodically check the import queue
            // In a real implementation, you would use a proper publisher
            Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    
                    Task {
                        let queue = await self.gameImporter.importQueue
                        
                        await MainActor.run {
                            // Update the queue items
                            self.importQueueItems = queue
                            
                            // Check if we should hide the view
                            self.checkHideTimer()
                        }
                    }
                }
                .store(in: &cancellables)
        }
        
        /// Check if we should hide the view based on queue state
        private func checkHideTimer() {
            // If there are no items or all are completed/failed, hide the view after a delay
            let noActiveImports = importQueueItems.isEmpty || importQueueItems.allSatisfy({ $0.status == .success || $0.status == .failure })
            let noCloudActivity = !isSyncing && pendingUploads == 0 && pendingDownloads == 0
            
            if noActiveImports && noCloudActivity {
                // Cancel any existing timer
                hideTimer?.cancel()
                
                // Set a new timer to hide the view after a delay
                hideTimer = Timer.publish(every: 3, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        self?.shouldShow = false
                        self?.hideTimer?.cancel()
                        self?.hideTimer = nil
                    }
            } else {
                // Cancel any existing timer if there are active items
                hideTimer?.cancel()
                hideTimer = nil
                shouldShow = true
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
            isSyncing = pendingDownloads > 0 || pendingUploads > 0 || newFilesCount > 0 || cloudKitIsActive
            
            // If sync status changed, update the view hiding logic
            checkHideTimer()
        }
    }
}
