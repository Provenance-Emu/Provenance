//
//  CloudSyncStatusView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLibrary
import PVLogging
import Combine
import CloudKit
import Defaults
import PVSettings
import PVFileSystem

/// A view that displays the status of cloud sync
/// Works on both iOS and tvOS, showing the appropriate sync status
public struct CloudSyncStatusView: View {
    @State private var syncStatus: String = "Checking sync status..."
    @State private var isEnabled: Bool = Defaults[.iCloudSync]
    @State private var isAvailable: Bool = false
    @Default(.iCloudSyncMode) private var currentiCloudSyncMode
    @State private var infoPlistInfo: String = ""
    @State private var containerInfo: String = ""
    @State private var syncProgress: Double = 0.0
    @State private var syncingFiles: Int = 0
    @State private var totalFiles: Int = 0
    
    // Detailed sync information by file type
    @State private var romSyncCount: Int = 0
    @State private var saveStateSyncCount: Int = 0
    @State private var biosSyncCount: Int = 0
    @State private var batteryStateSyncCount: Int = 0
    @State private var screenshotSyncCount: Int = 0
    @State private var deltaSkinSyncCount: Int = 0
    
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("Cloud Sync Status")
                .font(.title)
                .foregroundColor(.retroPink)
                .padding(.bottom, 8)
            
            // Status card
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: isAvailable ? "cloud.fill" : "cloud.slash.fill")
                            .foregroundColor(isAvailable ? .retroBlue : .retroPink)
                        
                        Text(isAvailable ? "Cloud Sync Available" : "Cloud Sync Unavailable")
                            .font(.headline)
                            .foregroundColor(isAvailable ? .retroBlue : .retroPink)
                        
                        Spacer()
                        
                        Toggle("", isOn: $isEnabled)
                            .labelsHidden()
                            .disabled(!isAvailable)
                            .onChange(of: isEnabled) { newValue in
                                toggleCloudSync(enabled: newValue)
                            }
                    }
                    
                    // Only show sync mode picker if sync is enabled
                    if isEnabled && isAvailable {
                        HStack {
                            Text("Sync Mode:")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            
                            Spacer()
                            
                            Picker("Sync Mode", selection: $currentiCloudSyncMode) {
                                ForEach(iCloudSyncMode.allCases, id: \.self) { mode in
                                    Text(mode.description)
                                        .tag(mode)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: currentiCloudSyncMode) { newMode in
                                handleSyncModeChange(newMode)
                            }
                            .frame(width: 120)
                        }
                    }
                }
                
                Divider()
                    .background(Color.retroPurple)
                
                // Sync status
                Text(syncStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
                
                // Detailed sync information
                if syncingFiles > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        if romSyncCount > 0 {
                            Text("ROMs: \(romSyncCount)")
                                .font(.caption)
                                .foregroundColor(.retroBlue)
                        }
                        if saveStateSyncCount > 0 {
                            Text("Save States: \(saveStateSyncCount)")
                                .font(.caption)
                                .foregroundColor(.retroPurple)
                        }
                        if biosSyncCount > 0 {
                            Text("BIOS: \(biosSyncCount)")
                                .font(.caption)
                                .foregroundColor(.retroPink)
                        }
                        if batteryStateSyncCount > 0 {
                            Text("Battery States: \(batteryStateSyncCount)")
                                .font(.caption)
                                .foregroundColor(.retroBlue)
                        }
                        if screenshotSyncCount > 0 {
                            Text("Screenshots: \(screenshotSyncCount)")
                                .font(.caption)
                                .foregroundColor(.retroPurple)
                        }
                        if deltaSkinSyncCount > 0 {
                            Text("Delta Skins: \(deltaSkinSyncCount)")
                                .font(.caption)
                                .foregroundColor(.retroPink)
                        }
                    }
                    .padding(.bottom, 4)
                }
                
                if syncProgress > 0 && syncProgress < 1.0 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Syncing \(syncingFiles) of \(totalFiles) files")
                            .font(.caption)
                            .foregroundColor(.retroBlue)
                        
                        ProgressView(value: syncProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color.retroPink))
                    }
                }
            }
            .padding()
            .background(Color.retroDarkBlue)
            .cornerRadius(12)
            
            // CloudKit Sync Analytics
            CloudKitSyncAnalyticsView()
                .padding(.top, 16)
            
#if DEBUG
            // Debug information (only in debug builds)
            VStack(alignment: .leading, spacing: 8) {
                Text("Debug Information")
                    .font(.headline)
                    .foregroundColor(.retroPurple)
                
                Text(infoPlistInfo)
                    .font(.caption)
                    .foregroundColor(.white)
                
                Text(containerInfo)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.retroBlack)
            .cornerRadius(12)
#endif
        }
        .padding()
        .onAppear {
            checkCloudAvailability()
        }
        .onReceive(timer) { _ in
            updateSyncStatus()
        }
    }
    
    /// Check if cloud sync is available
    private func checkCloudAvailability() {
#if os(tvOS)
        // Check CloudKit availability on tvOS
        checkCloudKitAvailability()
#else
        // Check iCloud Documents availability on iOS/macOS
        checkICloudAvailability()
#endif
        
        // Check Info.plist for both platforms
        checkInfoPlistForICloudKeys()
    }
    
#if os(tvOS)
    /// Check CloudKit availability on tvOS
    private func checkCloudKitAvailability() {
        let container = CKContainer(identifier: iCloudConstants.containerIdentifier)
        
        Task {
            do {
                let accountStatus = try await container.accountStatus()
                
                await MainActor.run {
                    switch accountStatus {
                    case .available:
                        isAvailable = true
                        syncStatus = "CloudKit is available"
                    case .noAccount:
                        isAvailable = false
                        syncStatus = "No iCloud account"
                    case .restricted:
                        isAvailable = false
                        syncStatus = "iCloud access restricted"
                    case .couldNotDetermine:
                        isAvailable = false
                        syncStatus = "Could not determine iCloud status"
                    @unknown default:
                        isAvailable = false
                        syncStatus = "Unknown iCloud status"
                    }
                }
            } catch {
                await MainActor.run {
                    isAvailable = false
                    syncStatus = "Error checking CloudKit: \(error.localizedDescription)"
                    ELOG("Error checking CloudKit: \(error.localizedDescription)")
                }
            }
        }
    }
#else
    /// Check iCloud Documents availability on iOS/macOS
    private func checkICloudAvailability() {
        Task {
            let iCloudURL = URL.iCloudContainerDirectory
            
            await MainActor.run {
                if let iCloudURL = iCloudURL {
                    isAvailable = true
                    syncStatus = "iCloud Documents is available"
                    containerInfo = "iCloud Container: \(iCloudURL.path)"
                } else {
                    isAvailable = false
                    syncStatus = "iCloud Documents is not available"
                    containerInfo = "iCloud Container: Not available"
                }
            }
        }
    }
#endif
    
    /// Check Info.plist for iCloud keys
    private func checkInfoPlistForICloudKeys() {
        let bundle = Bundle.main
        
        // Check for iCloud keys in Info.plist
        let ubiquityContainerIdentifiers = bundle.object(forInfoDictionaryKey: "NSUbiquitousContainers") as? [String: Any]
        let ubiquityKVStoreIdentifier = bundle.object(forInfoDictionaryKey: "NSUbiquitousKeyValueStoreCompletionHandler") as? String
        
        // Build Info.plist info string for UI display
        infoPlistInfo = """
        Info.plist iCloud Keys:
        -------------------------------------
        NSUbiquitousContainers: \(ubiquityContainerIdentifiers != nil ? "Present" : "Not found")
        NSUbiquitousKeyValueStore: \(ubiquityKVStoreIdentifier != nil ? "Present" : "Not found")
        -------------------------------------
        """
        
        DLOG("[CloudSyncStatusView] \(infoPlistInfo)")
    }
    
    /// Update the sync status
    private func updateSyncStatus() {
        if !isEnabled || !isAvailable {
            syncProgress = 0.0
            syncingFiles = 0
            totalFiles = 0
            return
        }
        
#if os(tvOS)
        // Get CloudKit sync status on tvOS
        updateCloudKitSyncStatus()
#else
        // Get iCloud Documents sync status on iOS/macOS
        updateICloudSyncStatus()
#endif
    }
    
#if os(tvOS)
    /// Update CloudKit sync status on tvOS
    private func updateCloudKitSyncStatus() {
        // Get active syncers from CloudKitSyncerStore
        let activeSyncers = CloudKitSyncerStore.shared.activeSyncers
        
        var pendingFiles = 0
        var newFiles = 0
        
        for syncer in activeSyncers {
            pendingFiles += syncer.pendingFilesToDownload.count
            newFiles += syncer.newFiles.count
        }
        
        let totalPending = pendingFiles + newFiles
        
        if totalPending > 0 {
            syncingFiles = totalPending - pendingFiles
            totalFiles = totalPending
            syncProgress = Double(syncingFiles) / Double(totalFiles)
            syncStatus = "Syncing \(syncingFiles) of \(totalFiles) files"
        } else {
            syncProgress = 1.0
            syncStatus = "All files synced"
        }
    }
#else
    /// Update iCloud Documents sync status on iOS/macOS
    private func updateICloudSyncStatus() {
        // Get active syncers from iCloudSyncerStore
        let activeSyncers = iCloudSyncerStore.shared.activeSyncers
        
        var pendingFiles = 0
        var newFiles = 0
        
        // Reset counts for each file type
        romSyncCount = 0
        saveStateSyncCount = 0
        biosSyncCount = 0
        batteryStateSyncCount = 0
        screenshotSyncCount = 0
        deltaSkinSyncCount = 0
        
        for syncer in activeSyncers {
            pendingFiles += syncer.pendingFilesToDownload.count
            newFiles += syncer.newFiles.count
            
            // Update counts by file type
            if let directories = (syncer as? CloudKitSyncer)?.directories {
                let count = syncer.pendingFilesToDownload.count + syncer.newFiles.count
                if count > 0 {
                    if directories.contains("ROMs") {
                        romSyncCount += count
                    } else if directories.contains("Saves") || directories.contains("Save States") {
                        saveStateSyncCount += count
                    } else if directories.contains("BIOS") {
                        biosSyncCount += count
                    } else if directories.contains("Battery States") {
                        batteryStateSyncCount += count
                    } else if directories.contains("Screenshots") {
                        screenshotSyncCount += count
                    } else if directories.contains("DeltaSkins") {
                        deltaSkinSyncCount += count
                    }
                }
            }
        }
        
        let totalPending = pendingFiles + newFiles
        
        if totalPending > 0 {
            syncingFiles = totalPending - pendingFiles
            totalFiles = totalPending
            syncProgress = Double(syncingFiles) / Double(totalFiles)
            syncStatus = "Syncing \(syncingFiles) of \(totalFiles) files"
        } else {
            syncProgress = 1.0
            syncStatus = "All files synced"
        }
    }
#endif
    
    /// Toggle cloud sync on or off
    private func toggleCloudSync(enabled: Bool) {
        Defaults[.iCloudSync] = enabled
        
        // Update UI immediately
        isEnabled = enabled
        
        // Update sync status
        if enabled {
            syncStatus = "Initializing cloud sync..."
            checkCloudAvailability()
        } else {
            syncStatus = "Cloud sync is disabled"
            syncingFiles = 0
            totalFiles = 0
            syncProgress = 0.0
        }
    }
    
    /// Handle changes to the sync mode
    private func handleSyncModeChange(_ newMode: iCloudSyncMode) {
        DLOG("iCloud sync mode changed to: \(newMode.description)")
        
        // Update sync status
        syncStatus = "Switching to \(newMode.description) mode..."
        
        // Reset counters and refresh
        syncingFiles = 0
        totalFiles = 0
        syncProgress = 0.0
        
        // Refresh cloud status after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkCloudAvailability()
        }
    }
}
#if DEBUG
struct CloudSyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        CloudSyncStatusView()
            .preferredColorScheme(.dark)
    }
}
#endif
