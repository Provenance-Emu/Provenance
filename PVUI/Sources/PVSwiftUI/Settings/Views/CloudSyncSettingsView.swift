//
//  CloudSyncSettingsView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLibrary
import PVLogging
import Combine
import Defaults
import PVSettings

/// A view that displays cloud sync settings
public struct CloudSyncSettingsView: View {
    @Default(.iCloudSync) private var iCloudSyncEnabled
    @Default(.autoSyncNewContent) private var autoSyncNewContent
    
    @State private var showingResetConfirmation = false
    @State private var isResetting = false
    
    @StateObject private var viewModel = CloudSyncSettingsViewModel()
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Cloud Sync Status")) {
                CloudSyncStatusView()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            Section(header: Text("Sync Options")) {
                Toggle("Enable Cloud Sync", isOn: $iCloudSyncEnabled)
                    .onChange(of: iCloudSyncEnabled) { newValue in
                        if newValue {
                            NotificationCenter.default.post(name: .iCloudSyncEnabled, object: nil)
                        } else {
                            NotificationCenter.default.post(name: .iCloudSyncDisabled, object: nil)
                        }
                    }
                
                Toggle("Auto-Sync New Content", isOn: $autoSyncNewContent)
                    .disabled(!iCloudSyncEnabled)
            }
            
            Section(header: Text("Sync Actions")) {
                Button(action: {
                    viewModel.startFullSync()
                }) {
                    HStack {
                        Text("Sync All Content")
                        Spacer()
                        if viewModel.isSyncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(!iCloudSyncEnabled || viewModel.isSyncing)
                
                #if DEBUG
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    Text("Reset Cloud Sync")
                        .foregroundColor(.retroPink)
                }
                .disabled(!iCloudSyncEnabled || viewModel.isSyncing)
                .alert(isPresented: $showingResetConfirmation) {
                    Alert(
                        title: Text("Reset Cloud Sync"),
                        message: Text("This will delete all cloud sync data and restart the sync process. Are you sure you want to continue?"),
                        primaryButton: .destructive(Text("Reset")) {
                            viewModel.resetCloudSync()
                        },
                        secondaryButton: .cancel()
                    )
                }
                #endif
            }
            
            Section(header: Text("Sync Information"), footer: Text("Cloud sync allows you to keep your games and save states in sync across your devices.")) {
                #if os(tvOS)
                Text("Using CloudKit for tvOS")
                    .font(.subheadline)
                #else
                Text("Using iCloud Documents")
                    .font(.subheadline)
                #endif
                
                if let lastSyncDate = viewModel.lastSyncDate {
                    Text("Last sync: \(lastSyncDate, formatter: dateFormatter)")
                        .font(.subheadline)
                }
                
                if let syncStats = viewModel.syncStats {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Games: \(syncStats.games)")
                        Text("Save States: \(syncStats.saveStates)")
                        Text("Total Size: \(fileSizeFormatter.string(fromByteCount: syncStats.totalSize))")
                    }
                    .font(.subheadline)
                    .focusableIfAvailable()
                }
            }
        }
        .onAppear {
            viewModel.loadSyncInfo()
        }
    }
    
    // Date formatter for last sync date
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    // File size formatter
    private var fileSizeFormatter: ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }
}

/// View model for cloud sync settings
class CloudSyncSettingsViewModel: ObservableObject {
    /// Whether a sync is in progress
    @Published var isSyncing = false
    
    /// Last sync date
    @Published var lastSyncDate: Date?
    
    /// Sync statistics
    @Published var syncStats: SyncStats?
    
    /// Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    /// Initialize the view model
    init() {
        // Subscribe to sync status changes
        CloudSyncManager.shared.syncStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .syncing, .uploading, .downloading:
                    self?.isSyncing = true
                case .idle, .disabled, .error:
                    self?.isSyncing = false
                    
                    // If sync completed successfully, update last sync date
                    if status == .idle {
                        self?.lastSyncDate = Date()
                        self?.loadSyncInfo()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Start a full sync
    func startFullSync() {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        // Start sync
        _ = CloudSyncManager.shared.startSync()
            .subscribe(
                onCompleted: { [weak self] in
                    DispatchQueue.main.async {
                        self?.isSyncing = false
                        self?.lastSyncDate = Date()
                        self?.loadSyncInfo()
                    }
                },
                onError: { [weak self] error in
                    DispatchQueue.main.async {
                        self?.isSyncing = false
                        ELOG("Sync error: \(error.localizedDescription)")
                    }
                }
            )
    }
    
    /// Reset cloud sync
    func resetCloudSync() {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        // Disable cloud sync
        Defaults[.iCloudSync] = false
        NotificationCenter.default.post(name: .iCloudSyncDisabled, object: nil)
        
        // Wait a bit for cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // Re-enable cloud sync
            Defaults[.iCloudSync] = true
            NotificationCenter.default.post(name: .iCloudSyncEnabled, object: nil)
            
            // Start sync
            _ = CloudSyncManager.shared.startSync()
                .subscribe(
                    onCompleted: { [weak self] in
                        DispatchQueue.main.async {
                            self?.isSyncing = false
                            self?.lastSyncDate = Date()
                            self?.loadSyncInfo()
                        }
                    },
                    onError: { [weak self] error in
                        DispatchQueue.main.async {
                            self?.isSyncing = false
                            ELOG("Sync reset error: \(error.localizedDescription)")
                        }
                    }
                )
        }
    }
    
    /// Load sync information
    func loadSyncInfo() {
        Task {
            do {
                // Get sync statistics
                let stats = try await getSyncStats()
                
                // Update UI on main thread
                await MainActor.run {
                    self.syncStats = stats
                }
            } catch {
                ELOG("Error loading sync info: \(error.localizedDescription)")
            }
        }
    }
    
    /// Get sync statistics
    private func getSyncStats() async throws -> SyncStats {
        // Get games and save states from database
        let games = PVGame.all.toArray()
        let saveStates = PVSaveState.all.toArray()
        
        // Calculate total size
        var totalSize: Int64 = 0
        
        for game in games {
            if let file = game.file, let url = file.url {
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                if let size = attributes?[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        
        for saveState in saveStates {
            if let file = saveState.file, let url = file.url {
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                if let size = attributes?[.size] as? Int64 {
                    totalSize += size
                }
            }
        }
        
        return SyncStats(
            games: games.count,
            saveStates: saveStates.count,
            totalSize: totalSize
        )
    }
}

/// Sync statistics
struct SyncStats {
    /// Number of games
    let games: Int
    
    /// Number of save states
    let saveStates: Int
    
    /// Total size in bytes
    let totalSize: Int64
}

#if DEBUG
struct CloudSyncSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CloudSyncSettingsView()
            .preferredColorScheme(.dark)
    }
}
#endif
