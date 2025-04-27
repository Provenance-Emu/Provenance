//
//  RetroStatusControlView.swift
//  PVUIBase
//
//  Created by Joseph Mattiello on 4/18/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import Combine
import PVLogging
import PVLibrary
import PVWebServer
import PVSupport
import PVUIBase
import PVPrimitives

public struct RetroStatusControlView: View {

    // MARK: - Environment & ViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = RetroStatusControlViewModel()

    // MARK: - UI State (View-Specific)
    @State private var isExpanded: Bool = true // Start expanded by default

    // MARK: - Computed Properties (Derived from ViewModel)
    private var shouldShowProgress: Bool {
        viewModel.fileImportProgress != nil ||
        viewModel.archiveExtractionProgress > 0 || // Check if progress > 0
        viewModel.fileRecoveryState == .inProgress ||
        viewModel.webServerUploadProgress != nil ||
        viewModel.romScanningProgress != nil ||
        viewModel.temporaryFileCleanupProgress != nil ||
        viewModel.cacheManagementProgress != nil ||
        viewModel.downloadProgress != nil ||
        viewModel.cloudKitSyncProgress != nil
    }

    public init() { }

    // MARK: - Body
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                mainContent
                    .transition(.opacity.combined(with: .slide)) // Optional animation
            }
        }
        .background(RetroTheme.retroDarkBlue.opacity(0.8).cornerRadius(8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(RetroTheme.retroGradient, lineWidth: 2)
        )
        .alert(item: $viewModel.currentAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    viewModel.dismissAlert() // Let ViewModel handle dismissal logic if needed
                }
            )
        }
        // No .onAppear/.onDisappear needed here, ViewModel handles lifecycle
        // No .onChange needed here, ViewModel uses Combine/Notifications internally
    }

    // MARK: - Subviews

    /// The header row with title and expand/collapse button
    private var header: some View {
        HStack {
            Text("System Status")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(RetroTheme.retroPink)
                .shadow(color: RetroTheme.retroPink.opacity(0.8), radius: 3, x: 0, y: 0)

            Spacer()

            controlButtonsSection // Include header buttons here
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(RetroTheme.retroBlack.opacity(0.5)) // Header background
        .onTapGesture {
            withAnimation { // Use default animation if custom one is missing
                isExpanded.toggle()
            }
            ButtonSoundGenerator.shared.playSound(.switch) // Was .expand / .collapse
        }
    }

    /// Buttons shown in the header
    private var controlButtonsSection: some View {
        HStack(spacing: 15) {
            // Example: Clear Messages Button (if desired in header)
            //             Button {
            //                 viewModel.clearMessages()
            //             } label: {
            //                 Image(systemName: "trash")
            //             }
            //             .buttonStyle(RetroTheme.RetroButtonStyle())
            //             .frame(width: 24, height: 24)
            //             .padding(.horizontal, 4)

            // Expand/Collapse Button
            //            Button {
            //                withAnimation { // Use default animation if custom one is missing
            //                    isExpanded.toggle()
            //                }
            //                ButtonSoundGenerator.shared.playSound(.switch) // Was .expand / .collapse
            //            } label: {
            //                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
            //                    .resizable()
            //                    .aspectRatio(contentMode: .fit)
            //                    .frame(width: 24, height: 24)
            //                    .foregroundColor(RetroTheme.retroBlue)
            //                    .shadow(color: RetroTheme.retroBlue.opacity(0.8), radius: 3, x: 0, y: 0)
            //                    .foregroundColor(RetroTheme.retroBlue)
            //            }
            //            .buttonStyle(.plain) // Remove default button styling
        }
    }

    /// The main collapsible content area
    private var mainContent: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {

                // MARK: Temporary Status Message (New)
                // Ensure viewModel.temporaryStatusMessage exists and is @Published
                if let tempMessage = viewModel.temporaryStatusMessage {
                    Text(tempMessage)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(RetroTheme.retroBlue)
                        .shadow(color: RetroTheme.retroBlue.opacity(0.6), radius: 2, x: 0, y: 0)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(RetroTheme.retroBlack.opacity(0.4))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // MARK: iCloud Sync Disabled Warning (New)
                if !viewModel.isICloudSyncEnabled {
                    HStack {
                        Image(systemName: "exclamationmark.icloud.fill")
                        Text("iCloud Sync is Disabled")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .shadow(color: RetroTheme.retroPink.opacity(0.7), radius: 2, x: 0, y: 0)
                    }
                    .foregroundColor(RetroTheme.retroPink) // Warning color
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RetroTheme.retroPink.opacity(0.1))
                    .transition(.opacity)
                }

                // MARK: Alerts
                // Alert is now handled by the .alert modifier on the main body

                // MARK: Progress Indicators
                if shouldShowProgress {
                    Divider()
                        .frame(height: 2)
                        .overlay(RetroTheme.retroGradient)
                        .shadow(color: RetroTheme.retroPurple.opacity(0.5), radius: 2, x: 0, y: 0)

                    // --- File Recovery Progress ---
                    if viewModel.fileRecoveryState == .inProgress, let progressInfo = viewModel.fileRecoveryProgressInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            RetroProgressView(
                                title: "iCloud File Recovery",
                                current: progressInfo.current,
                                total: progressInfo.total,
                                color: .orange,
                                customText: "\(Int(progressInfo.current))/\(Int(progressInfo.total)) files"
                            )
                            // Display the message associated with the progress
                            if let detail = progressInfo.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 5)
                    }

                    // --- Archive Extraction Progress ---
                    if viewModel.archiveExtractionInProgress || viewModel.archiveExtractionProgress > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            RetroProgressView(
                                title: "Extracting Archive",
                                current: Int(viewModel.archiveExtractionProgress * 100), // Convert Double to Int percentage
                                total: 100,
                                color: RetroTheme.retroPurple,
                                customText: viewModel.archiveExtractionFilename // Pass filename as custom text
                            )
                            if let errorInfo = viewModel.archiveExtractionError {
                                Text("Error: \(errorInfo.error)")
                                    .font(.caption)
                                    .foregroundColor(RetroTheme.retroPink)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // --- Web Server Upload Progress ---
                    if let uploadInfo = viewModel.webServerUploadProgress {
                        VStack(alignment: .leading, spacing: 4) {
                            RetroProgressView(title: "Web Upload",
                                              current: uploadInfo.transferredBytes,
                                              total: uploadInfo.totalBytes,
                                              color: RetroTheme.retroBlue,
                                              customText: "\(uploadInfo.currentFile) (\(uploadInfo.queueLength) left)")
                            Text(ByteCountFormatter.string(fromByteCount: Int64(uploadInfo.bytesTransferred), countStyle: .file) + " / " + ByteCountFormatter.string(fromByteCount: Int64(uploadInfo.totalBytes), countStyle: .file))
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(2) // Limit message lines if needed
                        }
                    }

                    // --- Other Progress Types ---
                    createProgressSection(for: viewModel.fileImportProgress, title: "Importing Files") // Add File Import
                    createProgressSection(for: viewModel.romScanningProgress, title: "Scanning ROMs")
                    createProgressSection(for: viewModel.temporaryFileCleanupProgress, title: "Cleaning Temp Files")
                    createProgressSection(for: viewModel.cacheManagementProgress, title: "Managing Cache")
                    createProgressSection(for: viewModel.downloadProgress, title: "Downloading")
                    createProgressSection(for: viewModel.cloudKitSyncProgress, title: "CloudKit Sync", color: .cyan) // Add missing color


                    // --- Manual Recovery Button ---
                    if viewModel.fileRecoveryState == .error || (viewModel.fileRecoveryState == .idle && !viewModel.pendingRecoveryFiles.isEmpty) {

                        // --- Pending iCloud Files (New) ---
                        if let pendingCount = viewModel.pendingRecoveryFileCount, pendingCount > 0 { // Check count > 0
                            Text("Files Pending iCloud Recovery: \(pendingCount)")
                                .font(.caption)
                                .foregroundColor(.orange) // Using orange like your snippet
                                .padding(.horizontal)
                                .padding(.bottom, 2) // Add slight bottom padding
                        }

                        Button {
                            viewModel.recoverFiles()
                        } label: {
                            Label("Recover Files Manually (\(viewModel.pendingRecoveryFiles.count) Pending)", systemImage: "arrow.clockwise.icloud")
                                .foregroundColor(RetroTheme.retroBlue)
                                .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 2, x: 0, y: 0)
                        }
                        .buttonStyle(RetroTheme.RetroButtonStyle())
                        .padding(.vertical, 6)
                        .padding(.horizontal)
                        .padding(.top, 5)
                    }

                    Divider()
                        .frame(height: 2)
                        .overlay(RetroTheme.retroGradient)
                        .shadow(color: RetroTheme.retroPurple.opacity(0.5), radius: 2, x: 0, y: 0)
                }

                // --- Archive Extraction Progress ---
                if viewModel.archiveExtractionInProgress || viewModel.archiveExtractionProgress > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        RetroProgressView(
                            title: "Extracting Archive",
                            current: Int(viewModel.archiveExtractionProgress * 100), // Convert Double to Int percentage
                            total: 100,
                            color: RetroTheme.retroPurple,
                            customText: viewModel.archiveExtractionFilename // Pass filename as custom text
                        )
                        if let errorInfo = viewModel.archiveExtractionError {
                            Text("Error: \(errorInfo.error)")
                                .font(.caption)
                                .foregroundColor(RetroTheme.retroPink)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal)
                }

                // --- Web Server Upload Progress ---
                if let uploadInfo = viewModel.webServerUploadProgress {
                    VStack(alignment: .leading, spacing: 4) {
                        RetroProgressView(title: "Web Upload",
                                          current: uploadInfo.transferredBytes,
                                          total: uploadInfo.totalBytes,
                                          color: RetroTheme.retroBlue,
                                          customText: "\(uploadInfo.currentFile) (\(uploadInfo.queueLength) left)")
                        Text(ByteCountFormatter.string(fromByteCount: Int64(uploadInfo.bytesTransferred), countStyle: .file) + " / " + ByteCountFormatter.string(fromByteCount: Int64(uploadInfo.totalBytes), countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                }

                // MARK: Web Server & System Stats Section
                VStack(alignment: .leading, spacing: 12) {
                    // Create a PVWebServerStatus object from our view model properties
                    let serverAddress = viewModel.webServerIPAddress.flatMap { ip in
                        viewModel.webServerPort.map { port in
                            "http://\(ip):\(port)"
                        }
                    }

                    // Pass the status object and toggle function
                    RetroWebServerStatusView(
                        status: PVWebServerStatus(isRunning: viewModel.isWebServerRunning, serverAddress: serverAddress),
                        startServer: viewModel.toggleWebServer
                    )

                    // Display error if present
                    if let error = viewModel.webServerError {
                        Text("Error: \(error)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(RetroTheme.retroPink)
                            .padding(.horizontal)
                    }

                    // iCloud Sync Status Indicator - Always visible section
                    HStack(spacing: 10) {
                        // Status indicator with glow effect
                        Circle()
                            .fill(viewModel.isICloudSyncEnabled ? RetroTheme.retroBlue : RetroTheme.retroPink)
                            .frame(width: 10, height: 10)
                            .shadow(color: (viewModel.isICloudSyncEnabled ? RetroTheme.retroBlue : RetroTheme.retroPink).opacity(0.7), radius: 3, x: 0, y: 0)

                        // Status text with retrowave styling
                        VStack(alignment: .leading, spacing: 4) {
                            Text("iCLOUD SYNC: \(viewModel.isICloudSyncEnabled ? "ENABLED" : "DISABLED")")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(viewModel.isICloudSyncEnabled ? RetroTheme.retroBlue : RetroTheme.retroPink)
                                .shadow(color: (viewModel.isICloudSyncEnabled ? RetroTheme.retroBlue : RetroTheme.retroPink).opacity(0.7), radius: 1, x: 0, y: 0)

                            if !viewModel.isICloudSyncEnabled {
                                // Disabled state
                                Text("Enable in Settings to sync your files")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(height: 14) // Fixed height
                            } else if let progress = viewModel.cloudKitSyncProgress {
                                // Active sync with progress
                                Text("\(progress.current)/\(progress.total) \(progress.detail ?? "")")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(height: 14) // Fixed height
                            } else {
                                // Idle state with pending files info if available
                                HStack(spacing: 4) {
                                    Text("Idle")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(.gray)

                                    if let pendingCount = viewModel.pendingRecoveryFileCount, pendingCount > 0 {
                                        Text("(\(pendingCount) files pending)")
                                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                                            .foregroundColor(RetroTheme.retroPink.opacity(0.8))
                                    }
                                }
                                .frame(height: 14) // Fixed height
                            }
                        }
                        .frame(height: 36) // Fixed height container to prevent layout shifts

                        Spacer()

                        // Manual sync button - always visible when enabled
                        if viewModel.isICloudSyncEnabled {
                            Button(action: {
                                DLOG("Manual sync triggered")
                                viewModel.triggerManualSync()
                            }) {
                                Image(systemName: "arrow.clockwise.icloud")
                                    .foregroundColor(RetroTheme.retroBlue)
                                    .shadow(color: RetroTheme.retroBlue.opacity(0.7), radius: 2, x: 0, y: 0)
                            }
                            .buttonStyle(RetroTheme.RetroButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                    )

                    RetroSystemStatsView() // Assumes this view manages its own state or uses env objects/notifications
                }
                .padding(.horizontal)


                // MARK: File Access Errors
                if !viewModel.fileAccessErrors.isEmpty {
                    Divider()
                        .frame(height: 2)
                        .overlay(RetroTheme.retroGradient)
                        .shadow(color: RetroTheme.retroPurple.opacity(0.5), radius: 2, x: 0, y: 0)
                    SwiftUI.Section {
                        DisclosureGroup("File Access Errors (\(viewModel.fileAccessErrors.count))") {
                            ScrollView(.vertical) { // Make it scrollable if list gets long
                                VStack(alignment: .leading) {
                                    ForEach(viewModel.fileAccessErrors.prefix(5)) { errorInfo in // Show latest 5
                                        VStack(alignment: .leading) {
                                            Text("\(errorInfo.filename): \(errorInfo.error)")
                                                .font(.caption)
                                                .foregroundColor(RetroTheme.retroPink)
                                            Text("(\(errorInfo.timestamp, style: .time))")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.bottom, 2)
                                    }
                                }
                            }
                            .frame(maxHeight: 100) // Limit height
                        }
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(RetroTheme.retroBlue)
                    }
                    .padding(.horizontal)
                }

                // MARK: Messages
                Divider()
                    .frame(height: 2)
                    .overlay(RetroTheme.retroGradient)
                    .shadow(color: RetroTheme.retroPurple.opacity(0.5), radius: 2, x: 0, y: 0)

                RetroMessagesView(
                    messages: viewModel.messages,
                    formatTimeInterval: { date in
                        let formatter = RelativeDateTimeFormatter()
                        formatter.unitsStyle = .abbreviated
                        return formatter.localizedString(for: date, relativeTo: Date())
                    },
                    messageTypeColor: { messageType in
                        switch messageType {
                        case .error: return RetroTheme.retroPink
                        case .warning: return .orange
                        case .info: return RetroTheme.retroBlue
                        case .success: return .green
                        case .progress: return RetroTheme.retroPurple
                        @unknown default: return .gray
                        }
                    }
                )
                .padding(.horizontal)


                // MARK: Footer Buttons (e.g., Clear Messages)
                HStack {
                    Spacer()
                    Button {
                        viewModel.clearMessages()
                    } label: {
                        Label("Clear Messages", systemImage: "trash")
                    }
                    .buttonStyle(RetroTheme.RetroButtonStyle())
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical) // Add padding to the main content area
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Helper to create progress views for optional progress tuples
    @ViewBuilder
    private func createProgressSection(for progress: ProgressInfo?, title: String, color: Color = RetroTheme.retroPurple) -> some View {
//        if let progressInfo = progress {
            VStack(alignment: .leading, spacing: 4) {
                RetroProgressView(
                    title: title,
                    current: progress?.current ?? 0,
                    total: progress?.total ?? 0,
                    color: color, // Use the provided color
                    customText: progress?.detail ?? "No operations in progress"
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 2) // Add small spacing between multiple progress bars
//        } else {
//            EmptyView()
//        }
    }
}


// MARK: - Helper Types (Kept in View for now, as ViewModel references them via RetroStatusControlView.Type)
extension RetroStatusControlView {

    /// Represents an alert message to be displayed
    struct AlertMessage: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let type: AlertType

        /// Defines the type of alert for styling and sound effects
        enum AlertType: String, CaseIterable, Equatable {
            case info
            case warning
            case error
            case success

            var iconName: String {
                switch self {
                case .info: return "info.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .error: return "xmark.octagon.fill"
                case .success: return "checkmark.circle.fill"
                }
            }

            var color: Color {
                switch self {
                case .info: return RetroTheme.retroBlue
                case .warning: return .orange
                case .error: return RetroTheme.retroPink
                case .success: return .green
                }
            }
        }

        // Equatable conformance
        static func == (lhs: AlertMessage, rhs: AlertMessage) -> Bool {
            lhs.id == rhs.id
        }
    }

    // Using FileRecoveryState from ViewModel
}

// MARK: - Preview (Needs Update for ViewModel)
#if DEBUG
struct RetroStatusControlView_Previews: PreviewProvider {
    static var previews: some View {
        // Previewing with ViewModel is slightly more complex
        // Easiest way is often to just instantiate the view
        // and let it create its default ViewModel instance.
        // For specific states, you might need a mock ViewModel setup.

        return ZStack {
            RetroTheme.retroBackground.ignoresSafeArea()
            ScrollView { // Add ScrollView for potentially long content
                RetroStatusControlView()
                    .padding()
            }
        }
        // Example of simulating state in preview (apply directly to ViewModel properties if needed)
        // .onAppear {
        //     let vm = RetroStatusControlViewModel() // Need access to the VM instance
        //     vm.isWebServerRunning = true
        //     vm.webServerIPAddress = "192.168.1.100"
        //     vm.webServerPort = 8080
        //     vm.fileRecoveryState = .recovering
        //     vm.fileRecoveryProgress = (current: 50, total: 100)
        // }
    }
}
#endif
