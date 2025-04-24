//
//  FileRecoveryTestView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLibrary
import PVThemes
import Combine
import PVPrimitives

/// A view that provides buttons to test the file recovery status message system
public struct FileRecoveryTestView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var messageManager = StatusMessageManager.shared
    
    @State private var glowOpacity: Double = 0.7
    @State private var selectedTab: TestCategory = .fileSystem
    
    public init() {}
    
    public var body: some View {
        mainContentView
        #if !os(tvOS)
            .navigationViewStyle(.stack)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .navigationBarTitle("File Recovery Test Utilities")
    }
    
    // Break down the body into smaller components to help the compiler
    private var mainContentView: some View {
        VStack(spacing: 16) {
            titleView
            
            categoryTabsView
            
            contentBasedOnTab
            
            clearButton
        }
        .padding()
        .background(
            ZStack {
                RetroTheme.retroBackground
                RetroGrid()
                    .opacity(0.3)
            }
        )
        .onAppear {
            // Start retrowave animations
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 1.0
            }
        }
    }
    
    // Title view
    private var titleView: some View {
        Text("Notification System Test Utilities")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(RetroTheme.retroPink)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 5, x: 0, y: 0)
    }
            
    // Category tabs view
    private var categoryTabsView: some View {
        HStack(spacing: 0) {
            ForEach(TestCategory.allCases, id: \.self) { category in
                categoryButton(for: category)
                
                if category != TestCategory.allCases.last {
                    Divider()
                        .frame(height: 20)
                        .background(Color.gray.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.2))
        )
    }
    
    // Individual category button
    private func categoryButton(for category: TestCategory) -> some View {
        Button(action: {
            selectedTab = category
        }) {
            Text(category.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(selectedTab == category ? RetroTheme.retroBlue : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedTab == category ? 
                              Color.black.opacity(0.6) : 
                              Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
            
    // Content based on selected tab
    private var contentBasedOnTab: some View {
        ScrollView {
            VStack(spacing: 12) {
                switch selectedTab {
                case .fileSystem:
                    fileSystemTestButtons
                case .network:
                    networkTestButtons
                case .controller:
                    controllerTestButtons
                case .romScanning:
                    romScanningTestButtons
                case .cloudKit:
                    cloudKitTestButtons
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.2))
        )
    }
            
    // Clear button
    private var clearButton: some View {
        Button(action: {
            messageManager.clearAllMessages()
            messageManager.clearFileRecoveryProgress()
        }) {
            Text("Clear All Messages")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1.5)
                )
        }
    }
    
    // MARK: - File System Test Buttons
    
    private var fileSystemTestButtons: some View {
        VStack(spacing: 12) {
            testButton(title: "Trigger Real File Recovery", color: RetroTheme.retroBlue) {
                Task {
                    await iCloudSync.manuallyTriggerFileRecovery()
                }
            }
            
            testButton(title: "Simulate File Recovery", color: RetroTheme.retroPurple) {
                simulateFileRecovery()
            }
            
            testButton(title: "Disk Space Warning", color: RetroTheme.retroPink) {
                NotificationCenter.default.post(
                    name: .diskSpaceWarning,
                    object: nil,
                    userInfo: ["availableMB": 500.0]
                )
            }
            
            testButton(title: "Temporary File Cleanup", color: RetroTheme.retroBlue) {
                simulateTemporaryFileCleanup()
            }
            
            testButton(title: "Cache Management", color: RetroTheme.retroPurple) {
                simulateCacheManagement()
            }
        }
    }
    
    // MARK: - Network Test Buttons
    
    private var networkTestButtons: some View {
        VStack(spacing: 12) {
            testButton(title: "Network Connected", color: RetroTheme.retroBlue) {
                NotificationCenter.default.post(
                    name: .networkConnectivityChanged,
                    object: nil,
                    userInfo: ["isConnected": true]
                )
            }
            
            testButton(title: "Network Disconnected", color: RetroTheme.retroPink) {
                NotificationCenter.default.post(
                    name: .networkConnectivityChanged,
                    object: nil,
                    userInfo: ["isConnected": false]
                )
            }
            
            testButton(title: "Download Queue", color: RetroTheme.retroPurple) {
                NotificationCenter.default.post(
                    name: .downloadQueueChanged,
                    object: nil,
                    userInfo: ["queueCount": 5]
                )
            }
            
            testButton(title: "Download Progress", color: RetroTheme.retroBlue) {
                simulateDownloadProgress()
            }
            
            testButton(title: "Web Server Started", color: RetroTheme.retroPurple) {
                NotificationCenter.default.post(
                    name: .webServerStatusChanged,
                    object: nil,
                    userInfo: ["isRunning": true, "port": 8080]
                )
            }
            
            testButton(title: "Web Server Stopped", color: RetroTheme.retroPink) {
                NotificationCenter.default.post(
                    name: .webServerStatusChanged,
                    object: nil,
                    userInfo: ["isRunning": false, "port": 0]
                )
            }
        }
    }
    
    // MARK: - Controller Test Buttons
    
    private var controllerTestButtons: some View {
        VStack(spacing: 12) {
            testButton(title: "Controller Connected", color: RetroTheme.retroBlue) {
                NotificationCenter.default.post(
                    name: .controllerConnected,
                    object: nil,
                    userInfo: ["controllerName": "Xbox Controller"]
                )
            }
            
            testButton(title: "Controller Disconnected", color: RetroTheme.retroPink) {
                NotificationCenter.default.post(
                    name: .controllerDisconnected,
                    object: nil,
                    userInfo: ["controllerName": "Xbox Controller"]
                )
            }
            
            testButton(title: "Controller Mapping Started", color: RetroTheme.retroPurple) {
                NotificationCenter.default.post(
                    name: .controllerMappingStarted,
                    object: nil,
                    userInfo: ["controllerName": "PlayStation Controller"]
                )
            }
            
            testButton(title: "Controller Mapping Success", color: RetroTheme.retroBlue) {
                NotificationCenter.default.post(
                    name: .controllerMappingCompleted,
                    object: nil,
                    userInfo: ["controllerName": "PlayStation Controller", "success": true]
                )
            }
            
            testButton(title: "Controller Mapping Failed", color: RetroTheme.retroPink) {
                NotificationCenter.default.post(
                    name: .controllerMappingCompleted,
                    object: nil,
                    userInfo: ["controllerName": "PlayStation Controller", "success": false]
                )
            }
            
            testButton(title: "MFi Config Changed", color: RetroTheme.retroPurple) {
                NotificationCenter.default.post(
                    name: .mfiControllerConfigChanged,
                    object: nil
                )
            }
        }
    }
    
    // MARK: - ROM Scanning Test Buttons
    
    private var romScanningTestButtons: some View {
        VStack(spacing: 12) {
            testButton(title: "ROM Scanning Started", color: RetroTheme.retroBlue) {
                NotificationCenter.default.post(
                    name: .romScanningStarted,
                    object: nil
                )
            }
            
            testButton(title: "ROM Scanning Progress", color: RetroTheme.retroPurple) {
                simulateROMScanningProgress()
            }
            
            testButton(title: "ROM Scanning Completed", color: RetroTheme.retroPink) {
                NotificationCenter.default.post(
                    name: .romScanningCompleted,
                    object: nil,
                    userInfo: ["totalScanned": 150, "newROMs": 25]
                )
            }
        }
    }
    
    // MARK: - CloudKit Test Buttons
    
    private var cloudKitTestButtons: some View {
        VStack(spacing: 12) {
            testButton(title: "Initial Sync Started", color: RetroTheme.retroBlue) {
                NotificationCenter.default.post(
                    name: .cloudKitInitialSyncStarted,
                    object: nil
                )
            }
            
            testButton(title: "Initial Sync Progress", color: RetroTheme.retroPurple) {
                simulateCloudKitInitialSyncProgress()
            }
            
            testButton(title: "Initial Sync Completed", color: RetroTheme.retroPink) {
                NotificationCenter.default.post(
                    name: .cloudKitInitialSyncCompleted,
                    object: nil,
                    userInfo: ["totalSynced": 120]
                )
            }
            
            testButton(title: "Zone Changes Started", color: RetroTheme.retroBlue) {
                NotificationCenter.default.post(
                    name: .cloudKitZoneChangesStarted,
                    object: nil
                )
            }
            
            testButton(title: "Zone Changes Completed", color: RetroTheme.retroPurple) {
                NotificationCenter.default.post(
                    name: .cloudKitZoneChangesCompleted,
                    object: nil
                )
            }
            
            testButton(title: "Record Upload", color: RetroTheme.retroPink) {
                simulateCloudKitRecordTransfer(isUpload: true)
            }
            
            testButton(title: "Record Download", color: RetroTheme.retroBlue) {
                simulateCloudKitRecordTransfer(isUpload: false)
            }
            
            testButton(title: "Conflicts Detected", color: RetroTheme.retroPurple) {
                NotificationCenter.default.post(
                    name: .cloudKitConflictsDetected,
                    object: nil,
                    userInfo: ["count": 5, "recordType": "SaveState"]
                )
            }
            
            testButton(title: "Conflicts Resolved", color: RetroTheme.retroPink) {
                NotificationCenter.default.post(
                    name: .cloudKitConflictsResolved,
                    object: nil,
                    userInfo: ["count": 5, "recordType": "SaveState"]
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func testButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(LinearGradient(
                            gradient: Gradient(colors: [color, color.opacity(0.6)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ), lineWidth: 1.5)
                )
                .shadow(color: color.opacity(glowOpacity * 0.5), radius: 3, x: 0, y: 0)
        }
    }
    
    // MARK: - Simulation Methods
    
    private func simulateFileRecovery() {
        let total = 50
        
        // Post start notification
        NotificationCenter.default.post(name: iCloudSync.iCloudFileRecoveryStarted, object: nil)
        
        // Simulate progress updates
        Task {
            for i in 1...total {
                // Post progress notification
                NotificationCenter.default.post(
                    name: iCloudSync.iCloudFileRecoveryProgress,
                    object: nil,
                    userInfo: ["current": i, "total": total]
                )
                
                // Delay between updates
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
            
            // Post completion notification
            NotificationCenter.default.post(name: iCloudSync.iCloudFileRecoveryCompleted, object: nil)
        }
    }
    
    private func simulateTemporaryFileCleanup() {
        let total = 30
        var bytesFreed: Int64 = 0
        
        // Post start notification
        NotificationCenter.default.post(name: .temporaryFileCleanupStarted, object: nil)
        
        // Simulate progress updates
        Task {
            for i in 1...total {
                // Simulate bytes freed (random amount between 1-10MB per file)
                let currentBytesFreed = Int64.random(in: 1_048_576...10_485_760)
                bytesFreed += currentBytesFreed
                
                // Post progress notification
                NotificationCenter.default.post(
                    name: .temporaryFileCleanupProgress,
                    object: nil,
                    userInfo: ["current": i, "total": total, "bytesFreed": bytesFreed]
                )
                
                // Delay between updates
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
            
            // Post completion notification
            NotificationCenter.default.post(
                name: .temporaryFileCleanupCompleted,
                object: nil,
                userInfo: ["bytesFreed": bytesFreed, "fileCount": total]
            )
        }
    }
    
    private func simulateCacheManagement() {
        let total = 20
        var bytesFreed: Int64 = 0
        
        // Post start notification
        NotificationCenter.default.post(name: .cacheManagementStarted, object: nil)
        
        // Simulate progress updates
        Task {
            for i in 1...total {
                // Simulate bytes freed (random amount between 1-5MB per item)
                let currentBytesFreed = Int64.random(in: 1_048_576...5_242_880)
                bytesFreed += currentBytesFreed
                
                // Post progress notification
                NotificationCenter.default.post(
                    name: .cacheManagementProgress,
                    object: nil,
                    userInfo: ["current": i, "total": total]
                )
                
                // Delay between updates
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            }
            
            // Post completion notification
            NotificationCenter.default.post(
                name: .cacheManagementCompleted,
                object: nil,
                userInfo: ["bytesFreed": bytesFreed]
            )
        }
    }
    
    private func simulateDownloadProgress() {
        let total = 10_000_000 // 10MB
        let fileName = "Super Mario World.sfc"
        
        // Simulate progress updates
        Task {
            for i in stride(from: 0, to: total, by: total/10) {
                // Post progress notification
                NotificationCenter.default.post(
                    name: .downloadProgress,
                    object: nil,
                    userInfo: ["current": i, "total": total, "fileName": fileName]
                )
                
                // Delay between updates
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            }
            
            // Final update
            NotificationCenter.default.post(
                name: .downloadProgress,
                object: nil,
                userInfo: ["current": total, "total": total, "fileName": fileName]
            )
        }
    }
    
    private func simulateROMScanningProgress() {
        let total = 40
        let romNames = ["Super Mario World.sfc", "Sonic the Hedgehog.md", "Crash Bandicoot.bin", 
                       "Final Fantasy VII.bin", "Donkey Kong Country.sfc", "Metal Gear Solid.bin"]
        
        // Simulate progress updates
        Task {
            for i in 1...total {
                // Get a random ROM name
                let currentROM = romNames[Int.random(in: 0..<romNames.count)]
                
                // Post progress notification
                NotificationCenter.default.post(
                    name: .romScanningProgress,
                    object: nil,
                    userInfo: ["current": i, "total": total, "currentROM": currentROM]
                )
                
                // Delay between updates
                try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 seconds
            }
        }
    }
    
    private func simulateCloudKitInitialSyncProgress() {
        let total = 25
        let dataTypes = ["Games", "SaveStates", "Artwork", "Settings"]
        
        // Simulate progress updates
        Task {
            for i in 1...total {
                // Get a data type based on progress
                let dataTypeIndex = min(i / (total / dataTypes.count), dataTypes.count - 1)
                let dataType = dataTypes[dataTypeIndex]
                
                // Post progress notification
                NotificationCenter.default.post(
                    name: .cloudKitInitialSyncProgress,
                    object: nil,
                    userInfo: ["current": i, "total": total, "dataType": dataType]
                )
                
                // Delay between updates
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            }
        }
    }
    
    private func simulateCloudKitRecordTransfer(isUpload: Bool) {
        let total = 15
        let recordType = "SaveState"
        
        // Post start notification
        NotificationCenter.default.post(
            name: .cloudKitRecordTransferStarted,
            object: nil,
            userInfo: ["isUpload": isUpload, "recordType": recordType]
        )
        
        // Simulate progress updates
        Task {
            for i in 1...total {
                // Post progress notification
                NotificationCenter.default.post(
                    name: .cloudKitRecordTransferProgress,
                    object: nil,
                    userInfo: ["current": i, "total": total, "isUpload": isUpload, "recordType": recordType]
                )
                
                // Delay between updates
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            }
            
            // Post completion notification
            NotificationCenter.default.post(
                name: .cloudKitRecordTransferCompleted,
                object: nil,
                userInfo: ["count": total, "isUpload": isUpload, "recordType": recordType]
            )
        }
    }
}

/// Categories for test buttons
public enum TestCategory: String, CaseIterable {
    case fileSystem = "fileSystem"
    case network = "network"
    case controller = "controller"
    case romScanning = "romScanning"
    case cloudKit = "cloudKit"
    
    var title: String {
        switch self {
        case .fileSystem: return "File System"
        case .network: return "Network"
        case .controller: return "Controller"
        case .romScanning: return "ROM Scanning"
        case .cloudKit: return "CloudKit"
        }
    }
}

#if DEBUG
#Preview {
    FileRecoveryTestView()
}
#endif
