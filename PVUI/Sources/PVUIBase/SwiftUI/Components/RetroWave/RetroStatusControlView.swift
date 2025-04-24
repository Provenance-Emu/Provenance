//
//  RetroStatusControlView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVThemes
import PVLibrary
import PVPrimitives
import PVWebServer

/// An enhanced status view with interactive controls styled with retrowave aesthetics
public struct RetroStatusControlView: View {
    // Managers and view models
    @ObservedObject private var messageManager = StatusMessageManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // State for expandable view
    @State private var isExpanded = false
    @State private var isVisible = true
    @State private var glowOpacity: Double = 0.7
    @State private var showSystemStats = false
    
    // Web server status
    @State private var webServerStatus: (isRunning: Bool, type: WebServerType, url: URL?)? = nil
    
    // File recovery tracking
    @State private var fileRecoverySessionId: String? = nil
    @State private var fileRecoveryStartTime: Date? = nil
    @State private var fileRecoveryBytesProcessed: UInt64 = 0
    @State private var fileRecoveryErrors: [(error: String, path: String, timestamp: Date)] = []
    @State private var retryQueueCount: Int = 0
    @State private var retryAttempt: Int = 0
    
    // Archive extraction tracking
    @State private var archiveExtractionInProgress = false
    @State private var archiveExtractionProgress: Double = 0
    @State private var currentArchiveFilename: String = ""
    @State private var archiveExtractionStartTime: Date? = nil
    @State private var extractedFilesCount: Int = 0
    
    // File access error tracking
    @State private var fileAccessErrors: [(error: String, path: String, errorType: String, timestamp: Date)] = []
    @State private var lastFileAccessErrorTime: Date? = nil
    @State private var fileAccessErrorCount: Int = 0
    
    // Files pending recovery tracking
    @State private var pendingRecoveryFiles: [(filename: String, path: String, timestamp: Date)] = []
    @State private var pendingRecoveryCount: Int = 0
    
    // Memory for system stats
    @State private var memoryUsage: Double = 0
    @State private var diskSpace: (used: Double, total: Double) = (0, 0)
    
    // Timer for updating stats
    @State private var statsTimer: Timer? = nil
    
    public init() {
        setupNotificationObservers()
    }
    
    public var body: some View {
        VStack(spacing: 4) {
            // Header with expand/collapse button
            headerView
            
            // Progress views for various operations
            if !isExpanded {
                compactStatusView
                    .fixedSize(horizontal: true, vertical: false) // Fix the width to prevent layout shifts
            } else {
                expandedView
                    .fixedSize(horizontal: true, vertical: false) // Fix the width to prevent layout shifts
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroPink, RetroTheme.retroBlue]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 5, x: 0, y: 0)
        )
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .onAppear {
            onAppear()
        }
        .onDisappear {
            onDisappear()
        }
    }
    
    // MARK: - Lifecycle Methods
    
    private func onAppear() {
        // Start the stats timer when the view appears
        startStatsTimer()
        
        // Initial update of web server status
        updateWebServerStatus()
        
        // Start retrowave animations
        withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowOpacity = 1.0
        }
    }
    
    private func onDisappear() {
        // Stop the stats timer when the view disappears
        statsTimer?.invalidate()
        statsTimer = nil
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Observe file recovery notifications
        NotificationCenter.default.addObserver(
            forName: iCloudSync.iCloudFileRecoveryStarted,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleFileRecoveryStarted(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: iCloudSync.iCloudFileRecoveryCompleted,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleFileRecoveryCompleted(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: iCloudSync.iCloudFileRecoveryProgress,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleFileRecoveryProgress(notification)
        }
        
        // Observe file recovery error notifications
        NotificationCenter.default.addObserver(
            forName: iCloudSync.iCloudFileRecoveryError,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleFileRecoveryError(notification)
        }
        
        // Observe web server notifications
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PVWebServerStatusChangedNotification"),
            object: nil,
            queue: .main
        ) { [self] _ in
            updateWebServerStatus()
        }
        
        // Observe archive extraction notifications
        NotificationCenter.default.addObserver(
            forName: .archiveExtractionStarted,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleArchiveExtractionStarted(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .archiveExtractionProgress,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleArchiveExtractionProgress(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .archiveExtractionCompleted,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleArchiveExtractionCompleted(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .archiveExtractionFailed,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleArchiveExtractionFailed(notification)
        }
        
        // Observe file access error notifications
        NotificationCenter.default.addObserver(
            forName: .fileAccessError,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleFileAccessError(notification)
        }
        
        // Observe file pending recovery notifications
        NotificationCenter.default.addObserver(
            forName: .iCloudFilePendingRecovery,
            object: nil,
            queue: .main
        ) { [self] notification in
            handleFilePendingRecovery(notification)
        }
    }
    
    private func handleFileRecoveryStarted(_ notification: Notification) {
        // Extract additional information from notification
        if let userInfo = notification.userInfo {
            fileRecoverySessionId = userInfo["sessionId"] as? String
            fileRecoveryStartTime = userInfo["timestamp"] as? Date ?? Date()
        } else {
            fileRecoveryStartTime = Date()
        }
        
        // Reset bytes processed
        fileRecoveryBytesProcessed = 0
    }
    
    private func handleFileRecoveryCompleted(_ notification: Notification) {
        // Extract additional information from notification
        if let userInfo = notification.userInfo {
            fileRecoveryBytesProcessed = userInfo["bytesProcessed"] as? UInt64 ?? 0
            retryQueueCount = userInfo["failedFiles"] as? Int ?? 0
            retryAttempt = userInfo["retryAttempts"] as? Int ?? 0
        }
        
        // Keep the start time for a while to show completion duration
        // We'll reset it after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [self] in
            fileRecoveryStartTime = nil
            fileRecoverySessionId = nil
            // Clear errors after a delay
            fileRecoveryErrors = []
        }
    }
    
    private func handleFileRecoveryError(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let errorMessage = userInfo["error"] as? String ?? "Unknown error"
        let path = userInfo["path"] as? String ?? ""
        let timestamp = userInfo["timestamp"] as? Date ?? Date()
        let filename = userInfo["filename"] as? String ?? path.split(separator: "/").last.map(String.init) ?? ""
        
        // Add to errors list, limiting to most recent 10
        let error = (error: "\(errorMessage) - \(filename)", path: path, timestamp: timestamp)
        fileRecoveryErrors.append(error)
        
        // Keep only the 10 most recent errors
        if fileRecoveryErrors.count > 10 {
            fileRecoveryErrors.removeFirst(fileRecoveryErrors.count - 10)
        }
        
        // Show the view when an error occurs
        withAnimation {
            isVisible = true
            isExpanded = true  // Also expand the view to show error details
        }
    }
    
    private func handleFileRecoveryProgress(_ notification: Notification) {
        // Extract additional information from notification
        if let userInfo = notification.userInfo {
            if let bytesProcessed = userInfo["bytesProcessed"] as? UInt64 {
                fileRecoveryBytesProcessed = bytesProcessed
            }
            
            // Check for retry queue information
            if let message = userInfo["message"] as? String, message.contains("retry") {
                // Update retry information
                if let retryCount = message.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .filter({ !$0.isEmpty })
                    .first, let count = Int(retryCount) {
                    retryQueueCount = count
                }
                
                if message.contains("attempt") {
                    if let attemptString = message.components(separatedBy: "attempt")
                        .last?
                        .components(separatedBy: CharacterSet.decimalDigits.inverted)
                        .filter({ !$0.isEmpty })
                        .first, let attempt = Int(attemptString) {
                        retryAttempt = attempt
                    }
                }
            }
        }
    }
    
    // MARK: - Archive Extraction Handlers
    
    private func handleArchiveExtractionStarted(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        archiveExtractionInProgress = true
        archiveExtractionProgress = 0.0
        archiveExtractionStartTime = userInfo["timestamp"] as? Date ?? Date()
        currentArchiveFilename = userInfo["filename"] as? String ?? "archive"
        extractedFilesCount = 0
        
        // Show the view when extraction starts
        withAnimation {
            isVisible = true
        }
    }
    
    private func handleArchiveExtractionProgress(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let progress = userInfo["progress"] as? Double {
            archiveExtractionProgress = progress
        }
        
        // Keep the view visible during extraction
        if !isVisible {
            withAnimation {
                isVisible = true
            }
        }
    }
    
    private func handleArchiveExtractionCompleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        archiveExtractionInProgress = false
        archiveExtractionProgress = 1.0
        extractedFilesCount = userInfo["count"] as? Int ?? 0
        
        // Keep the extraction info visible for a short time after completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [self] in
            if !isExpanded {
                archiveExtractionStartTime = nil
                currentArchiveFilename = ""
            }
        }
    }
    
    private func handleArchiveExtractionFailed(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        archiveExtractionInProgress = false
        
        let errorMessage = userInfo["error"] as? String ?? "Unknown error"
        let filename = userInfo["filename"] as? String ?? ""
        
        // Add to errors list
        let error = (error: "Archive extraction failed: \(filename) - \(errorMessage)", 
                     path: userInfo["path"] as? String ?? "", 
                     timestamp: userInfo["timestamp"] as? Date ?? Date())
        fileRecoveryErrors.append(error)
        
        // Keep only the 10 most recent errors
        if fileRecoveryErrors.count > 10 {
            fileRecoveryErrors.removeFirst(fileRecoveryErrors.count - 10)
        }
        
        // Show and expand the view when an error occurs
        withAnimation {
            isVisible = true
            isExpanded = true  // Expand to show error details
        }
    }
    
    // MARK: - File Access Error Handling
    
    private func handleFileAccessError(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let errorMessage = userInfo["error"] as? String ?? "Unknown error"
        let path = userInfo["path"] as? String ?? ""
        let filename = userInfo["filename"] as? String ?? ""
        let errorType = userInfo["errorType"] as? String ?? "unknown"
        let timestamp = userInfo["timestamp"] as? Date ?? Date()
        
        // Update error count
        fileAccessErrorCount += 1
        lastFileAccessErrorTime = timestamp
        
        // Only add distinct errors to avoid flooding
        // Check if we already have a similar error for the same file
        let existingErrorIndex = fileAccessErrors.firstIndex { 
            $0.path == path && $0.errorType == errorType 
        }
        
        if let index = existingErrorIndex {
            // Update existing error with new timestamp
            fileAccessErrors[index] = (error: "\(getErrorTypeDescription(errorType)): \(filename)",
                                       path: path,
                                       errorType: errorType,
                                       timestamp: timestamp)
        } else {
            // Add new error
            fileAccessErrors.append((error: "\(getErrorTypeDescription(errorType)): \(filename)",
                                    path: path,
                                    errorType: errorType,
                                    timestamp: timestamp))
            
            // Keep only the 10 most recent errors
            if fileAccessErrors.count > 10 {
                fileAccessErrors.removeFirst(fileAccessErrors.count - 10)
            }
        }
        
        // Only show the view for serious errors or if errors are accumulating
        if errorType == "timeout" || errorType == "access_denied" || fileAccessErrorCount > 5 {
            withAnimation {
                isVisible = true
                // Only expand for serious errors
                if errorType == "access_denied" || errorType == "icloud_access" {
                    isExpanded = true
                }
            }
        }
    }
    
    private func getErrorTypeDescription(_ errorType: String) -> String {
        switch errorType {
        case "timeout":
            return "Timeout accessing file"
        case "access_denied":
            return "File access denied"
        case "icloud_access":
            return "iCloud access issue"
        case "file_recovering":
            return "File is being recovered"
        case "file_provider_error":
            return "iCloud provider error"
        default:
            return "File error"
        }
    }
    
    // MARK: - File Pending Recovery Handling
    
    private func handleFilePendingRecovery(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        let path = userInfo["path"] as? String ?? ""
        let filename = userInfo["filename"] as? String ?? ""
        let timestamp = userInfo["timestamp"] as? Date ?? Date()
        
        // Update pending recovery count
        pendingRecoveryCount += 1
        
        // Check if we already have this file in the list
        let existingIndex = pendingRecoveryFiles.firstIndex { $0.path == path }
        
        if let index = existingIndex {
            // Update timestamp
            pendingRecoveryFiles[index] = (filename: filename, path: path, timestamp: timestamp)
        } else {
            // Add to list
            pendingRecoveryFiles.append((filename: filename, path: path, timestamp: timestamp))
            
            // Keep only the most recent 20 files
            if pendingRecoveryFiles.count > 20 {
                pendingRecoveryFiles.removeFirst(pendingRecoveryFiles.count - 20)
            }
        }
        
        // Show the view when files are being recovered
        if pendingRecoveryCount > 5 && !isVisible {
            withAnimation {
                isVisible = true
            }
        }
    }
    
    // MARK: - Subviews
    
    /// Header view with title and expand/collapse button
    private var headerView: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(RetroTheme.retroPink)
                .frame(width: 10, height: 10)
                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
            
            Text("SYSTEM STATUS")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(RetroTheme.retroPink)
                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
            
            Spacer()
            
            // Expand/collapse button
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                    
                    // Update stats immediately when expanding
                    if isExpanded {
                        updateSystemStats()
                        updateWebServerStatus()
                    }
                }
            }) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(RetroTheme.retroBlue)
                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
    
    /// Compact view showing only active progress indicators
    private var compactStatusView: some View {
        VStack(spacing: 4) {
            // File recovery progress
            if let progress = messageManager.fileRecoveryProgress {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("File Recovery")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(RetroTheme.retroBlue)
                            .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                        
                        Spacer()
                        
                        if let startTime = fileRecoveryStartTime {
                            Text("Started: \(formatTimeInterval(since: startTime))")
                                .font(.system(size: 10))
                                .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
                        }
                    }
                    
                    progressView(title: "", current: progress.current, total: progress.total, color: RetroTheme.retroBlue)
                    
                    HStack {
                        if fileRecoveryBytesProcessed > 0 {
                            Text("\(formatBytes(fileRecoveryBytesProcessed)) processed")
                                .font(.system(size: 10))
                                .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        // Show retry information if any
                        if retryQueueCount > 0 {
                            Text("Retry queue: \(retryQueueCount) files (attempt \(retryAttempt))")
                                .font(.system(size: 10))
                                .foregroundColor(RetroTheme.retroPink.opacity(0.9))
                                .shadow(color: RetroTheme.retroPink.opacity(0.5), radius: 1, x: 0, y: 0)
                        }
                    }
                    .padding(.top, 2)
                    
                    // Show recent errors if any
                    if (!fileRecoveryErrors.isEmpty || !fileAccessErrors.isEmpty) && isExpanded {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recent Errors:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(RetroTheme.retroPink)
                                .padding(.top, 4)
                            
                            // File recovery errors
                            ForEach(fileRecoveryErrors.suffix(3).indices, id: \.self) { index in
                                let error = fileRecoveryErrors[index]
                                Text(error.error)
                                    .font(.system(size: 9))
                                    .foregroundColor(RetroTheme.retroPink.opacity(0.8))
                                    .lineLimit(1)
                            }
                            
                            // File access errors
                            ForEach(fileAccessErrors.suffix(3).indices, id: \.self) { index in
                                let error = fileAccessErrors[index]
                                Text(error.error)
                                    .font(.system(size: 9))
                                    .foregroundColor(RetroTheme.retroPink.opacity(0.8))
                                    .lineLimit(1)
                            }
                            
                            // Show error count if there are more errors
                            if fileAccessErrorCount > 3 {
                                Text("+ \(fileAccessErrorCount - min(3, fileAccessErrors.count)) more file access errors")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(RetroTheme.retroPink.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            
            // ROM scanning progress
            if let progress = messageManager.romScanningProgress {
                progressView(title: "ROM Scanning", current: progress.current, total: progress.total, color: RetroTheme.retroPurple)
            }
            
            // Archive extraction progress
            if archiveExtractionInProgress || archiveExtractionProgress > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Extracting Archive")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(RetroTheme.retroPurple)
                            .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity), radius: 2, x: 0, y: 0)
                        
                        Spacer()
                        
                        if let startTime = archiveExtractionStartTime {
                            Text("Started: \(formatTimeInterval(since: startTime))")
                                .font(.system(size: 10))
                                .foregroundColor(RetroTheme.retroPurple.opacity(0.8))
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(RetroTheme.retroPurple.opacity(0.2))
                                .cornerRadius(2)
                            
                            Rectangle()
                                .fill(RetroTheme.retroPurple)
                                .cornerRadius(2)
                                .frame(width: geometry.size.width * CGFloat(archiveExtractionProgress))
                        }
                    }
                    .frame(height: 4)
                    
                    // File info
                    HStack {
                        Text(currentArchiveFilename)
                            .font(.system(size: 10))
                            .foregroundColor(RetroTheme.retroPurple.opacity(0.8))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(Int(archiveExtractionProgress * 100))%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(RetroTheme.retroPurple)
                    }
                    
                    // Show extracted files count if completed
                    if extractedFilesCount > 0 && !archiveExtractionInProgress {
                        Text("\(extractedFilesCount) files extracted")
                            .font(.system(size: 10))
                            .foregroundColor(RetroTheme.retroPurple.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.top, 2)
                    }
                }
            }
            
            // Web server upload progress
            if let progress = messageManager.viewModel.webServerUploadProgress {
                let progressPercent = progress.progress * 100
                let current = Int(progress.bytesTransferred / 1024)
                let total = Int(progress.totalBytes / 1024)
                
                progressView(
                    title: "Upload: \(progress.currentFile.split(separator: "/").last ?? "")",
                    current: current,
                    total: total,
                    color: RetroTheme.retroPink,
                    customText: "\(Int(progressPercent))% (\(progress.queueLength) in queue)"
                )
            }
            
            // Web server status
            if let status = messageManager.viewModel.webServerStatus {
                webServerStatusView(status: status)
            }
            
            // Most recent message
            if let message = messageManager.messages.first {
                statusMessageView(message)
            }
        }
    }
    
    /// Expanded view with all status information and controls
    private var expandedView: some View {
        VStack(spacing: 8) {
            // File access error summary if there are recent errors
            if fileAccessErrorCount > 0, let lastErrorTime = lastFileAccessErrorTime, Date().timeIntervalSince(lastErrorTime) < 60 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(RetroTheme.retroPink)
                        .font(.system(size: 12))
                    
                    Text("\(fileAccessErrorCount) file access \(fileAccessErrorCount == 1 ? "error" : "errors") in the last minute")
                        .font(.system(size: 12))
                        .foregroundColor(RetroTheme.retroPink)
                    
                    Spacer()
                    
                    Button(action: {
                        // Clear file access errors
                        fileAccessErrors = []
                        fileAccessErrorCount = 0
                    }) {
                        Text("Clear")
                            .font(.system(size: 10))
                            .foregroundColor(RetroTheme.retroPink.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RetroTheme.retroPink.opacity(0.1))
                .cornerRadius(4)
            }
            
            // Pending recovery files summary
            if pendingRecoveryCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundColor(RetroTheme.retroBlue)
                        .font(.system(size: 12))
                    
                    Text("\(pendingRecoveryCount) \(pendingRecoveryCount == 1 ? "file" : "files") being recovered from iCloud")
                        .font(.system(size: 12))
                        .foregroundColor(RetroTheme.retroBlue)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RetroTheme.retroBlue.opacity(0.1))
                .cornerRadius(4)
                
                // Show list of pending files if expanded
                if isExpanded && !pendingRecoveryFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Files being recovered:")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(RetroTheme.retroBlue)
                            .padding(.top, 2)
                            .padding(.horizontal, 8)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(pendingRecoveryFiles.suffix(10), id: \.path) { file in
                                    HStack {
                                        Text(file.filename)
                                            .font(.system(size: 9))
                                            .foregroundColor(RetroTheme.retroBlue.opacity(0.8))
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text(formatTimeInterval(since: file.timestamp))
                                            .font(.system(size: 9))
                                            .foregroundColor(RetroTheme.retroBlue.opacity(0.6))
                                    }
                                    .padding(.horizontal, 8)
                                }
                            }
                        }
                        .frame(maxHeight: 100)
                    }
                }
            }
            // Progress indicators
            Group {
                // File recovery progress
                if let progress = messageManager.fileRecoveryProgress {
                    progressView(title: "File Recovery", current: progress.current, total: progress.total, color: RetroTheme.retroBlue)
                }
                
                // ROM scanning progress
                if let progress = messageManager.romScanningProgress {
                    progressView(title: "ROM Scanning", current: progress.current, total: progress.total, color: RetroTheme.retroPurple)
                }
                
                // Temporary file cleanup progress
                if let progress = messageManager.temporaryFileCleanupProgress {
                    progressView(title: "File Cleanup", current: progress.current, total: progress.total, color: RetroTheme.retroPink)
                }
                
                // Cache management progress
                if let progress = messageManager.cacheManagementProgress {
                    progressView(title: "Cache Optimization", current: progress.current, total: progress.total, color: RetroTheme.retroBlue)
                }
                
                // Download progress
                if let progress = messageManager.downloadProgress {
                    progressView(title: "Download", current: progress.current, total: progress.total, color: RetroTheme.retroPurple)
                }
                
                // CloudKit sync progress
                if let progress = messageManager.cloudKitSyncProgress {
                    progressView(title: "iCloud Sync", current: progress.current, total: progress.total, color: RetroTheme.retroBlue)
                }
                
                // Web server upload progress
                if let progress = messageManager.viewModel.webServerUploadProgress {
                    let progressPercent = progress.progress * 100
                    let current = Int(progress.bytesTransferred / 1024)
                    let total = Int(progress.totalBytes / 1024)
                    
                    progressView(
                        title: "Upload: \(progress.currentFile.split(separator: "/").last ?? "")",
                        current: current,
                        total: total,
                        color: RetroTheme.retroPink,
                        customText: "\(Int(progressPercent))% (\(progress.queueLength) in queue)"
                    )
                }
            }
            
            // Control buttons
            controlButtonsView
            
            // System stats
            if showSystemStats {
                systemStatsView
            }
            
            // Status messages
            messagesView
        }
        .padding(.bottom, 8)
    }
    
    /// Control buttons for various actions
    private var controlButtonsView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Web server controls
                webServerControlButton
                
                // Import controls
                importControlButton
                
                // System stats toggle
                Button(action: {
                    withAnimation {
                        showSystemStats.toggle()
                        if showSystemStats {
                            updateSystemStats()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "gauge")
                        Text(showSystemStats ? "Hide Stats" : "Show Stats")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RetroTheme.retroBlue)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(RetroTheme.retroBlue, lineWidth: 1)
                            )
                    )
                    .shadow(color: RetroTheme.retroBlue.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Second row of buttons
            HStack(spacing: 12) {
                // Trigger file recovery
                Button(action: {
                    Task {
                        await iCloudSync.manuallyTriggerFileRecovery()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Recover Files")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RetroTheme.retroPurple)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(RetroTheme.retroPurple, lineWidth: 1)
                            )
                    )
                    .shadow(color: RetroTheme.retroPurple.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Clear messages
                Button(action: {
                    messageManager.clearAllMessages()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Clear Messages")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RetroTheme.retroPink)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(RetroTheme.retroPink, lineWidth: 1)
                            )
                    )
                    .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
        )
        .padding(.horizontal, 12)
    }
    
    /// Web server control button
    @ViewBuilder
    private var webServerControlButton: some View {
        let isRunning = messageManager.viewModel.webServerStatus?.isRunning ?? false
        
        Button(action: {
            toggleWebServer(isRunning: isRunning)
        }) {
            HStack {
                Image(systemName: isRunning ? "stop.circle" : "play.circle")
                Text(isRunning ? "Stop Server" : "Start Server")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isRunning ? RetroTheme.retroPink : RetroTheme.retroBlue)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isRunning ? RetroTheme.retroPink : RetroTheme.retroBlue, lineWidth: 1)
                    )
            )
            .shadow(color: (isRunning ? RetroTheme.retroPink : RetroTheme.retroBlue).opacity(glowOpacity), radius: 3, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// Import control button
    @ViewBuilder
    private var importControlButton: some View {
        let isActive = messageManager.isImportActive
        
        Button(action: {
            toggleImporter(isActive: isActive)
        }) {
            HStack {
                Image(systemName: isActive ? "pause.circle" : "play.circle")
                Text(isActive ? "Pause Import" : "Resume Import")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isActive ? RetroTheme.retroPurple : RetroTheme.retroBlue)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isActive ? RetroTheme.retroPurple : RetroTheme.retroBlue, lineWidth: 1)
                    )
            )
            .shadow(color: (isActive ? RetroTheme.retroPurple : RetroTheme.retroBlue).opacity(glowOpacity), radius: 3, x: 0, y: 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// System statistics view
    private var systemStatsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SYSTEM STATISTICS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(RetroTheme.retroPink)
                .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                .padding(.bottom, 2)
            
            // Memory usage
            HStack {
                Text("Memory Usage:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RetroTheme.retroBlue)
                
                Spacer()
                
                Text("\(Int(memoryUsage)) MB")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(RetroTheme.retroPurple)
            }
            
            // Disk space
            HStack {
                Text("Disk Space:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RetroTheme.retroBlue)
                
                Spacer()
                
                Text("\(Int(diskSpace.used)) GB / \(Int(diskSpace.total)) GB")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(RetroTheme.retroPurple)
            }
            
            // Disk usage progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 6)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [RetroTheme.retroBlue, RetroTheme.retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(CGFloat(diskSpace.used / diskSpace.total) * geometry.size.width, geometry.size.width)), height: 6)
                }
            }
            .frame(height: 6)
            
            // Web server info
            if let status = messageManager.viewModel.webServerStatus, status.isRunning {
                HStack {
                    Text("Server URL:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(RetroTheme.retroBlue)
                    
                    Spacer()
                    
                    Text(status.url?.absoluteString ?? "Unknown")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(RetroTheme.retroPink)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
        )
        .padding(.horizontal, 12)
    }
    
    /// Status messages list
    private var messagesView: some View {
        VStack(spacing: 4) {
            ForEach(messageManager.messages) { message in
                statusMessageView(message)
            }
        }
    }
    
    /// Web server status view
    @ViewBuilder
    private func webServerStatusView(status: (isRunning: Bool, type: WebServerType, url: URL?)) -> some View {
        HStack {
            // Status indicator
            Circle()
                .fill(status.isRunning ? RetroTheme.retroBlue : RetroTheme.retroPink)
                .frame(width: 10, height: 10)
                .shadow(color: (status.isRunning ? RetroTheme.retroBlue : RetroTheme.retroPink).opacity(glowOpacity), radius: 3, x: 0, y: 0)
            
            // Status text
            Text("\(status.type == .webUploader ? "Web Upload" : "WebDAV") Server: \(status.isRunning ? "Running" : "Stopped")")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            // URL if available
            if status.isRunning, let url = status.url {
                Text(url.absoluteString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(RetroTheme.retroBlue)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [status.isRunning ? RetroTheme.retroBlue : RetroTheme.retroPink, RetroTheme.retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: (status.isRunning ? RetroTheme.retroBlue : RetroTheme.retroPink).opacity(0.5), radius: 3, x: 0, y: 0)
        .padding(.horizontal, 12)
    }
    
    /// Creates a view for a status message
    @ViewBuilder
    private func statusMessageView(_ message: StatusMessage) -> some View {
        HStack {
            Circle()
                .fill(messageTypeColor(message.type))
                .frame(width: 10, height: 10)
                .shadow(color: messageTypeColor(message.type).opacity(glowOpacity), radius: 3, x: 0, y: 0)
            
            Text(message.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                messageManager.removeMessage(withID: message.id)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(RetroTheme.retroPurple.opacity(0.8))
                    .font(.system(size: 14))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [messageTypeColor(message.type), RetroTheme.retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: messageTypeColor(message.type).opacity(0.5), radius: 3, x: 0, y: 0)
        .padding(.horizontal, 12)
    }
    
    /// Creates a generic progress view for any operation
    @ViewBuilder
    private func progressView(title: String, current: Int, total: Int, color: Color, customText: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                
                Spacer()
                
                if let customText = customText {
                    Text(customText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                } else {
                    Text("\(current)/\(total) (\(Int(Double(current) / Double(max(1, total)) * 100))%)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(RetroTheme.retroPink)
                        .shadow(color: RetroTheme.retroPink.opacity(glowOpacity), radius: 3, x: 0, y: 0)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.5))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color, RetroTheme.retroPurple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, min(CGFloat(current) / CGFloat(max(1, total)) * geometry.size.width, geometry.size.width)), height: 8)
                        .animation(.easeInOut(duration: 0.3), value: current)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            LinearGradient(
                                gradient: Gradient(colors: [color, RetroTheme.retroPurple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: color.opacity(0.5), radius: 3, x: 0, y: 0)
        .padding(.horizontal, 12)
    }
    
    // MARK: - Helper Methods
    
    /// Format a time interval since the given date
    private func formatTimeInterval(since date: Date) -> String {
        let interval = Int(Date().timeIntervalSince(date))
        
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        let hours = interval / 3600
        
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %02ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    /// Format bytes to human-readable format
    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024.0
        let mb = kb / 1024.0
        let gb = mb / 1024.0
        
        if gb >= 1.0 {
            return String(format: "%.2f GB", gb)
        } else if mb >= 1.0 {
            return String(format: "%.2f MB", mb)
        } else {
            return String(format: "%.0f KB", kb)
        }
    }
    
    /// Get the color for a message type
    private func messageTypeColor(_ type: StatusMessage.MessageType) -> Color {
        switch type {
        case .info:
            return RetroTheme.retroBlue
        case .success:
            return Color.green
        case .warning:
            return Color.orange
        case .error:
            return RetroTheme.retroPink
        case .progress:
            return RetroTheme.retroPurple
        }
    }
    
    /// Start the timer for updating system stats
    private func startStatsTimer() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            if isExpanded && showSystemStats {
                updateSystemStats()
            }
            
            // Always update web server status
            updateWebServerStatus()
        }
    }
    
    /// Update system statistics
    private func updateSystemStats() {
        // Memory usage (simulated for now)
        memoryUsage = Double.random(in: 100...500) // MB
        
        // Disk space (simulated for now)
        diskSpace = (Double.random(in: 10...50), 64) // GB
        
        // In a real implementation, you would use Process.Info or other APIs to get actual stats
    }
    
    /// Update web server status
    private func updateWebServerStatus() {
        // Get status from view model
        webServerStatus = messageManager.viewModel.webServerStatus
    }
    
    /// Toggle web server
    private func toggleWebServer(isRunning: Bool) {
        if isRunning {
            // Stop web server
            Task {
                PVWebServer.shared.stopServers()
            }
        } else {
            // Start web server
            Task {
                _ = PVWebServer.shared.startServers()
            }
        }
    }
    
    /// Toggle importer
    private func toggleImporter(isActive: Bool) {
        if isActive {
            // Pause import
            messageManager.viewModel.setImportActive(false)
        } else {
            // Resume import
            messageManager.viewModel.setImportActive(true)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct RetroStatusControlView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            RetroTheme.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                RetroStatusControlView()
                    .padding(.bottom, 20)
            }
        }
    }
}
#endif
