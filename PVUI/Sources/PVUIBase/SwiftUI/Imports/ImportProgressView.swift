import SwiftUI
import Combine
import PVLibrary
import PVSettings
import Perception
import PVThemes

/// A view that displays the progress of imports and CloudKit syncing
public struct ImportProgressView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel: ViewModel
    
    private let gameImporter: any GameImporting
    private let updatesController: PVGameLibraryUpdatesController
    
    @Default(.iCloudSync) private var iCloudSyncEnabled
    
    /// Callback when the view is tapped
    public var onTap: (() -> Void)?
    
    // MARK: - Initialization
    
    /// Initialize with gameImporter, updatesController, and optional onTap callback
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
    
    /// Convenience initializer without onTap callback
    public init(
        gameImporter: any GameImporting,
        updatesController: PVGameLibraryUpdatesController
    ) {
        self.gameImporter = gameImporter
        self.updatesController = updatesController
        self.onTap = nil
        self._viewModel = StateObject(wrappedValue: ViewModel(gameImporter: gameImporter))
    }
    
    // MARK: - Body
    
    public var body: some View {
        // Fixed height approach to prevent flickering
        VStack {
            WithPerceptionTracking {
                if !viewModel.importQueueItems.isEmpty || (iCloudSyncEnabled && viewModel.isSyncing) {
                    Button(action: {
                        if let onTapAction = onTap {
                            // Use MainActor to ensure UI updates happen on the main thread
                            Task { @MainActor in
                                onTapAction()
                            }
                        }
                    }) {
                        contentView
                            .contentShape(Rectangle()) // Make entire view tappable
                    }
                    .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to avoid button styling
                    .fixedSize(horizontal: false, vertical: true) // Fix the height to prevent layout shifts
                } else {
                    EmptyView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: !viewModel.importQueueItems.isEmpty || viewModel.isSyncing)
        .task {
            await viewModel.refreshQueueItems()
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 8) {
            // CloudKit Sync Status
            if iCloudSyncEnabled && viewModel.isSyncing {
                cloudKitSyncView
            }
            
            // Import Queue Status
            if !viewModel.importQueueItems.isEmpty {
                importQueueView
            }
        }
        .padding(10)
        .background(
            ZStack {
                // Dark background
                Color.retroBlack.opacity(0.85)
                
                // Grid overlay for retrowave effect
                RetroTheme.RetroGridView()
                    .opacity(0.15)
            }
        )
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [.retroPurple, .retroPink]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.retroPink.opacity(0.3), radius: 4, x: 0, y: 0)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    // CloudKit Sync View
    private var cloudKitSyncView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title with glow effect
            Text("iCloud Sync")
                .font(.headline)
                .foregroundColor(.retroPink)
                .shadow(color: .retroPink.opacity(0.7), radius: 2, x: 0, y: 0)
            
            // Progress info
            HStack {
                if let currentFile = viewModel.currentSyncFile {
                    Text("Syncing: \(currentFile)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("Syncing files...")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if let progress = viewModel.syncProgress, progress > 0 {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    // Progress fill
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroBlue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(geometry.size.width * CGFloat(viewModel.syncProgress ?? 0), 0), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            // Additional sync info
            if let totalFiles = viewModel.totalSyncFiles, totalFiles > 0 {
                Text("Processing \(viewModel.completedSyncFiles) of \(totalFiles) files")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    // Import Queue View
    private var importQueueView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title with glow effect
            Text("Game Imports")
                .font(.headline)
                .foregroundColor(.retroBlue)
                .shadow(color: .retroBlue.opacity(0.7), radius: 2, x: 0, y: 0)
            
            // Current import info
            if let currentImport = viewModel.importQueueItems.first {
                HStack {
                    Text("Importing: \(currentImport.url.lastPathComponent)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    // Progress is not directly available on ImportQueueItem
                    // We'll show a simple indicator instead
                    if currentImport.status == .processing {
                        Text("Processing...")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.black.opacity(0.3))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    // Progress fill
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [.retroBlue, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(width: max(geometry.size.width * CGFloat(viewModel.currentImportProgress), 0), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            // Queue status
            HStack(spacing: 8) {
                statusItem(count: viewModel.queuedCount, label: "Queued", color: .gray)
                statusItem(count: viewModel.processingCount, label: "Processing", color: .retroBlue)
                statusItem(count: viewModel.completedCount, label: "Completed", color: .retroGreen)
                statusItem(count: viewModel.failedCount, label: "Failed", color: .retroPink)
            }
            .padding(.top, 4)
        }
    }
    
    private func statusItem(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(color)
                .shadow(color: color.opacity(0.7), radius: 2, x: 0, y: 0)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(
                                    color.opacity(0.7),
                                    lineWidth: 1
                                )
                        )
                )
            
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(Color.gray.opacity(0.8))
        }
    }
}

// MARK: - ViewModel

extension ImportProgressView {
    final class ViewModel: ObservableObject {
        // MARK: - Properties
        
        @Published var importQueueItems: [ImportQueueItem] = []
        @Published var isSyncing: Bool = false
        @Published var currentSyncFile: String? = nil
        @Published var syncProgress: Float? = nil
        @Published var totalSyncFiles: Int? = nil
        @Published var completedSyncFiles: Int = 0
        
        private var cancellables = Set<AnyCancellable>()
        private let gameImporter: any GameImporting
        
        // MARK: - Computed Properties
        
        var currentImportProgress: Float {
            // Since progress isn't directly available on ImportQueueItem,
            // we'll use a simple calculation based on completed items
            if importQueueItems.isEmpty {
                return 0
            }
            
            let totalItems = importQueueItems.count
            let completedItems = importQueueItems.filter { $0.status == .success }.count
            
            return Float(completedItems) / Float(totalItems)
        }
        
        var queuedCount: Int {
            importQueueItems.filter { $0.status == .queued }.count
        }
        
        var processingCount: Int {
            importQueueItems.filter { $0.status == .processing }.count
        }
        
        var completedCount: Int {
            importQueueItems.filter { $0.status == .success }.count
        }
        
        var failedCount: Int {
            importQueueItems.filter { $0.status == .failure }.count
        }
        
        // MARK: - Initialization
        
        init(gameImporter: any GameImporting) {
            self.gameImporter = gameImporter
            
            setupObservers()
        }
        
        // MARK: - Setup
        
        private func setupObservers() {
            // Observe import queue changes
            gameImporter.importQueuePublisher
                .receive(on: RunLoop.main)
                .sink { [weak self] items in
                    self?.importQueueItems = items
                }
                .store(in: &cancellables)
            
            // Observe CloudKit sync status
            NotificationCenter.default.publisher(for: Notification.Name("CloudKitSyncStarted"))
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.isSyncing = true
                }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: Notification.Name("iCloudSyncCompleted"))
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.isSyncing = false
                    self?.currentSyncFile = nil
                    self?.syncProgress = nil
                    self?.totalSyncFiles = nil
                    self?.completedSyncFiles = 0
                }
                .store(in: &cancellables)
            
            NotificationCenter.default.publisher(for: Notification.Name("CloudKitSyncProgress"))
                .receive(on: RunLoop.main)
                .sink { [weak self] notification in
                    guard let userInfo = notification.userInfo else { return }
                    
                    if let currentFile = userInfo["currentFile"] as? String {
                        self?.currentSyncFile = currentFile
                    }
                    
                    if let progress = userInfo["progress"] as? Float {
                        self?.syncProgress = progress
                    }
                    
                    if let totalFiles = userInfo["totalFiles"] as? Int {
                        self?.totalSyncFiles = totalFiles
                    }
                    
                    if let completedFiles = userInfo["completedFiles"] as? Int {
                        self?.completedSyncFiles = completedFiles
                    }
                }
                .store(in: &cancellables)
        }
        
        // MARK: - Methods
        
        @MainActor
        func refreshQueueItems() async {
            // Use GameImporter.shared directly
            let gameImporter = GameImporter.shared
            importQueueItems = await gameImporter.importQueue
        }
    }
}
