//
//  CloudSyncSettingsView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/22/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

/// CloudSyncSettingsView provides a unified interface for managing both CloudKit and iCloud Drive sync
/// settings and monitoring sync status. The view is organized into three main tabs:
///
/// 1. CloudKit Tab: Displays CloudKit sync analytics, record counts, and sync progress
/// 2. iCloud Drive Tab: Shows file comparison between local and iCloud storage
/// 3. Settings Tab: Contains sync options, on-demand downloads, and diagnostics
///
/// This view consolidates functionality that was previously split between separate views
/// to provide a more cohesive user experience while maintaining clear separation between
/// different sync technologies.

import SwiftUI
import PVLibrary
import PVLogging
import Combine
import Defaults
import PVSettings
import CloudKit
import PVUIBase
import PVFileSystem
import Foundation
import Perception

/// A view that displays unified cloud sync settings with tabs for CloudKit and iCloud Drive.
/// This view combines functionality from both CloudKit and iCloud Drive sync views into a single
/// tabbed interface for better user experience and code organization.
public struct CloudSyncSettingsView: View {
    @Default(.iCloudSync) internal var iCloudSyncEnabled
    @Default(.autoSyncNewContent) private var autoSyncNewContent
    @Default(.iCloudSyncMode) internal var currentiCloudSyncMode
    @Default(.cloudKitSyncContentType) internal var currentiCloudSyncContentType
    @Default(.cloudKitSyncNetworkMode) internal var currentCloudKitSyncNetworkMode
    @Default(.cloudKitSyncFrequency) internal var currentCloudKitSyncFrequency

    @State internal var showingResetConfirmation = false
    @State private var isResetting = false
    @State private var selectedTab = 0
    @State internal var showDiagnostics = false

    @StateObject internal var viewModel = UnifiedCloudSyncViewModel()

    public init() {}

    public var body: some View {
        ZStack {
            // Background
            Color.retroDarkBlue.edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                // Header with status
                statusHeader

                // Tab selector
                tabSelector

                // Tab content
                TabView(selection: $selectedTab) {
                    cloudKitTab.tag(0)
                    iCloudDriveTab.tag(1)
                    settingsTab.tag(2)
                    moreSettingsTab.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .onAppear {
            viewModel.loadSyncInfo()
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationView {
                CloudKitDiagnosticView()
                    #if !os(tvOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showDiagnostics = false
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Status Header
    /// The status header displays the overall sync status, including availability and sync progress.
    /// It appears at the top of the view and provides immediate feedback about the sync state.

    private var statusHeader: some View {
        VStack(spacing: 8) {
            Text("Cloud Sync")
                .font(.title)
                .foregroundColor(.retroPink)
                .padding(.top)

            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(viewModel.iCloudAvailable ? Color.green : Color.red)
                    .frame(width: 12, height: 12)

                // Status text
                Text(viewModel.syncStatus)
                    .font(.subheadline)
                    .foregroundColor(.white)

                Spacer()

                // Sync indicator
                if viewModel.isSyncing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))

                        Text("Syncing...")
                            .font(.caption)
                            .foregroundColor(.retroPink)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.horizontal)
    }

    // MARK: - Tab Selector
    /// The tab selector allows users to switch between CloudKit, iCloud Drive, and Settings tabs.
    /// It uses custom buttons with RetroWave styling for a consistent look and feel.

    private var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "CloudKit", systemImage: "icloud.fill", tag: 0)
            tabButton(title: "iCloud Drive", systemImage: "folder.fill.badge.person.crop", tag: 1)
            tabButton(title: "Settings", systemImage: "gear", tag: 2)
            tabButton(title: "Sync Settings", systemImage: "person.icloud", tag: 3)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func tabButton(title: String, systemImage: String, tag: Int) -> some View {
        Button(action: {
            withAnimation {
                selectedTab = tag
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                selectedTab == tag ?
                AnyView(LinearGradient(
                    gradient: Gradient(colors: [Color.retroPink, Color.retroPurple]),
                    startPoint: .leading,
                    endPoint: .trailing
                )) : AnyView(Color.clear)
            )
            .cornerRadius(8)
            .foregroundColor(selectedTab == tag ? .white : .gray)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - CloudKit Tab
    /// The CloudKit tab displays CloudKit-specific information including analytics, record counts,
    /// sync progress, and sync actions. This tab focuses on the CloudKit backend sync functionality.

    private var cloudKitTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // CloudKit Analytics
                CloudKitSyncAnalyticsView()
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                // Record counts with chart visualization
                recordCountsWithChartView
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                // Sync progress if syncing
                if viewModel.isSyncing {
                    enhancedSyncProgressView
                        .padding(.horizontal)
                        .transitionWithReducedMotion(
                            .scale.combined(with: .opacity),
                            fallbackTransition: .opacity
                        )
                }

                // Sync activity chart
                syncActivityChartView
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                // Sync log viewer (expandable)
                syncLogSection
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                // Sync actions
                syncActionsView
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)
            }
            .padding(.vertical)
            .animateWithReducedMotion(.easeInOut(duration: 0.3), value: viewModel.isSyncing)
        }
        .onAppear {
#if !os(tvOS)
            HapticFeedbackService.shared.playSelection(style: .light)
#endif
        }
    }

    /// Sync log section with expandable detailed log viewer
    private var syncLogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation {
                    viewModel.showSyncLog.toggle()
                }
#if !os(tvOS)
                HapticFeedbackService.shared.playSelection()
#endif
            }) {
                HStack {
                    Text("Sync Logs")
                        .retroSectionHeader()

                    Spacer()

                    Image(systemName: viewModel.showSyncLog ? "chevron.down" : "chevron.right")
                        .foregroundColor(.retroPink)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if viewModel.showSyncLog {
                SyncLogViewer()
                    .frame(height: 400)
                    .transitionWithReducedMotion(
                        .move(edge: .top).combined(with: .opacity),
                        fallbackTransition: .opacity
                    )
            }
        }
        .padding()
        .background(Color.retroBlack.opacity(0.3))
        .cornerRadius(10)
    }

    // MARK: - Chart Data Helpers

    /// Filters and sorts the chart data for the last 7 days with activity.
    private var last7DaysChartData: [(Date, [CloudSyncLogEntry.SyncProviderType : DailyProviderSyncStats])] {
        viewModel.syncChartData
            .sorted { $0.key > $1.key } // Sort descending by date
            .prefix(7) // Take the latest 7 days
            .sorted { $0.key < $1.key } // Sort ascending for chart order
    }

    /// Formats the dates for the X-axis labels.
    private var dailyUploadXLabels: [String] {
        last7DaysChartData.map { (date, _) in
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d" // e.g., "Apr 28"
            return formatter.string(from: date)
        }
    }

    /// Calculates the total daily uploads across all providers.
    private var dailyUploadDataPoints: [Double] {
        last7DaysChartData.map { (_, providerStats) in
            // Sum uploads across all providers for the day
            let totalUploads = providerStats.values.reduce(0) { $0 + $1.uploads }
            return Double(totalUploads)
        }
    }

    // MARK: - Sync Activity Chart

    /// Shows sync activity over time with a line chart
    private var syncActivityChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Activity (Uploads - Last 7 Days)")
                .font(.headline)
                .foregroundColor(.retroPink)

            // Line chart visualization
            // This uses mock data - in a real implementation, this would use historical sync data
            if dailyUploadDataPoints.isEmpty {
                Text("No recent sync activity found.")
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                RetroCharts.LineChart(
                    dataPoints: dailyUploadDataPoints,
                    xLabels: dailyUploadXLabels,
                    title: nil
                )
                .frame(height: 150) // Give the chart a reasonable height
            }
        }
    }

    // MARK: - iCloud Drive Tab
    /// The iCloud Drive tab shows file comparison between local storage and iCloud Drive.
    /// It displays file counts by directory and highlights sync differences between local and cloud files.

    /// A view showing the sync status between local and iCloud storage
    private var syncStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sync Status")
                    .font(.headline)
                    .foregroundColor(Color.retroPink)
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.compareFiles()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.retroPurple.opacity(0.5))
                    .cornerRadius(8)
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Local Files")
                        .font(.subheadline)
                    Text("\(viewModel.localFileCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.retroBlue)
                }

                VStack(alignment: .leading) {
                    Text("iCloud Files")
                        .font(.subheadline)
                    Text("\(viewModel.iCloudFileCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.retroPink)
                }

                Spacer()

                VStack(alignment: .leading) {
                    Text("Differences")
                        .font(.subheadline)
                    Text("\(viewModel.syncDifferences.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.retroPurple)
                }
            }
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
        }
    }

    private var iCloudDriveTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // File comparison section
                syncStatusView
                    .padding(.horizontal)

                // Sync differences with pagination if any
                if !viewModel.syncDifferences.isEmpty {
                    PaginatedSyncDifferencesView(viewModel: viewModel)
                        .padding(.horizontal)
                        .transitionWithReducedMotion(
                            .move(edge: .bottom).combined(with: .opacity),
                            fallbackTransition: .opacity
                        )
                }

                // Diagnostics button (lazy loaded)
                if !viewModel.showDiagnostics {
                    Button(action: {
                        withAnimation(.easeInOut) {
                            viewModel.showDiagnostics = true
                        }
#if !os(tvOS)
                        HapticFeedbackService.shared.playSelection()
#endif
                    }) {
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Load Diagnostics")
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .retroCard()
                        .retroGlowingBorder(color: .retroBlue)
                    }
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)
                } else {
                    // Diagnostics view (lazy loaded)
                    LazyDiagnosticsView(viewModel: viewModel)
                        .padding(.horizontal)
                        .transitionWithReducedMotion(.opacity)
                }
            }
            .padding(.vertical)
            .animateWithReducedMotion(.easeInOut(duration: 0.3), value: viewModel.syncDifferences.isEmpty)
            .animateWithReducedMotion(.easeInOut(duration: 0.3), value: viewModel.showDiagnostics)
        }
        .onAppear {
#if !os(tvOS)
            HapticFeedbackService.shared.playSelection(style: .light)
#endif
        }
        //        .padding(.horizontal)
        //        .padding(.vertical)
    }

    // MARK: - Component Views
    /// The following views are reusable components used across different tabs.
    /// They are organized by functionality and designed to be modular and maintainable.

    /// Displays record counts with a RetroWave bar chart visualization
    private var recordCountsWithChartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CloudKit Records")
                .font(.headline)
                .foregroundColor(.retroPink)

            if viewModel.isLoadingCloudKitRecords {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .retroBlue))
                    Spacer()
                }
                .padding()
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(10)
            } else {
                // Bar chart visualization
                RetroCharts.BarChart(
                    values: [
                        Double(viewModel.cloudKitRecords.roms),
                        Double(viewModel.cloudKitRecords.saveStates),
                        Double(viewModel.cloudKitRecords.bios),
                        Double(viewModel.cloudKitRecords.batteryStates),
                        Double(viewModel.cloudKitRecords.screenshots),
                        Double(viewModel.cloudKitRecords.deltaSkins)
                    ],
                    labels: ["ROMs", "Saves", "BIOS", "Battery", "Screenshots", "Skins"],
                    title: nil
                )

                // Text summary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Total Records:")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(viewModel.cloudKitRecords.total)")
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(10)
            }
        }
    }

    /// Shows a pie chart of storage distribution by file type
    private var storageDistributionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Distribution")
                .font(.headline)
                .foregroundColor(.retroPink)

            // Pie chart visualization
            RetroCharts.PieChart(
                values: [
                    Double(viewModel.cloudKitRecords.roms * 10), // Multiplied for visualization
                    Double(viewModel.cloudKitRecords.saveStates * 2),
                    Double(viewModel.cloudKitRecords.bios * 5),
                    Double(viewModel.cloudKitRecords.batteryStates),
                    Double(viewModel.cloudKitRecords.screenshots * 8),
                    Double(viewModel.cloudKitRecords.deltaSkins * 3)
                ],
                labels: ["ROMs", "Saves", "BIOS", "Battery", "Screenshots", "Skins"]
            )
        }
    }

    /// Shows enhanced sync progress with visual feedback
    private var enhancedSyncProgressView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Progress")
                .font(.headline)
                .foregroundColor(.retroPink)

            VStack(alignment: .leading, spacing: 16) {
                if let currentFile = viewModel.currentSyncFile {
                    // Current file being synced
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current File:")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Text(currentFile)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color.retroBlack.opacity(0.5))
                            .cornerRadius(4)
                    }

                    // Animated progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        // Progress percentage
                        HStack {
                            Text("Progress:")
                                .font(.caption)
                                .foregroundColor(.gray)

                            Spacer()

                            Text("\(Int(viewModel.syncProgress * 100))%")
                                .font(.subheadline)
                                .foregroundColor(.retroBlue)
                                .fontWeight(.bold)
                        }

                        // Custom animated progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                Rectangle()
                                    .fill(Color.retroBlack.opacity(0.5))
                                    .frame(height: 12)
                                    .cornerRadius(6)

                                // Progress fill
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.retroBlue, .retroPurple, .retroPink]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, CGFloat(viewModel.syncProgress) * geometry.size.width), height: 12)
                                    .cornerRadius(6)

                                // Glow effect
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.clear, .retroPink.opacity(0.5), .clear]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 20, height: 12)
                                    .cornerRadius(6)
                                    .offset(x: max(0, CGFloat(viewModel.syncProgress) * geometry.size.width - 20))
                                    .opacity(viewModel.syncProgress > 0.02 ? 1 : 0)
                                    .animation(
                                        Animation.easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: true),
                                        value: viewModel.syncProgress
                                    )
                            }
                        }
                        .frame(height: 12)
                    }

                    // File counts
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(viewModel.syncingFiles)")
                                .font(.title3)
                                .foregroundColor(.retroBlue)
                                .fontWeight(.bold)

                            Text("Completed")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.retroBlack.opacity(0.3))
                        .cornerRadius(8)

                        VStack {
                            Text("\(viewModel.totalFiles ?? 0)")
                                .font(.title3)
                                .foregroundColor(.retroPink)
                                .fontWeight(.bold)

                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.retroBlack.opacity(0.3))
                        .cornerRadius(8)

                        // Estimated time
                        VStack {
                            if let total = viewModel.totalFiles, total > 0 {
                                let remainingFiles = total - viewModel.syncingFiles
                                let estimatedSeconds = remainingFiles * 3 // Rough estimate

                                Text(formatTimeRemaining(seconds: estimatedSeconds))
                                    .font(.title3)
                                    .foregroundColor(.retroPurple)
                                    .fontWeight(.bold)

                                Text("Remaining")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("--")
                                    .font(.title3)
                                    .foregroundColor(.retroPurple)
                                    .fontWeight(.bold)

                                Text("Remaining")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.retroBlack.opacity(0.3))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
        }
    }

    /// Format time remaining in a human-readable format
    private func formatTimeRemaining(seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)m \(remainingSeconds)s"
        } else {
            let hours = seconds / 3600
            let remainingMinutes = (seconds % 3600) / 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }

    /// Displays counts of different record types in CloudKit, organized by category.
    /// Shows ROMs, save states, BIOS files, battery states, screenshots, and Delta skins.
    private var recordCountsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CloudKit Records")
                .font(.headline)
                .foregroundColor(.retroPink)

            if viewModel.isLoadingCloudKitRecords {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .retroBlue))
                    Spacer()
                }
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ROMs:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(viewModel.cloudKitRecords.roms)")
                            .foregroundColor(.retroBlue)
                    }

                    HStack {
                        Text("Save States:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(viewModel.cloudKitRecords.saveStates)")
                            .foregroundColor(.retroPurple)
                    }

                    HStack {
                        Text("BIOS:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(viewModel.cloudKitRecords.bios)")
                            .foregroundColor(.retroPink)
                    }

                    Divider()
                        .background(Color.retroPurple.opacity(0.5))

                    HStack {
                        Text("Battery States:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(viewModel.cloudKitRecords.batteryStates)")
                            .foregroundColor(.retroBlue)
                    }

                    HStack {
                        Text("Screenshots:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(viewModel.cloudKitRecords.screenshots)")
                            .foregroundColor(.retroPurple)
                    }

                    HStack {
                        Text("Delta Skins:")
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(viewModel.cloudKitRecords.deltaSkins)")
                            .foregroundColor(.retroPink)
                    }

                    Divider()
                        .background(Color.retroPurple.opacity(0.5))

                    HStack {
                        Text("Total Records:")
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                        Spacer()
                        Text("\(viewModel.cloudKitRecords.total)")
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(10)
            }
        }
    }

    /// Shows detailed sync progress when a sync operation is in progress.
    /// Displays the current file being synced, overall progress, and file counts.
    private var syncProgressView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Progress")
                .font(.headline)
                .foregroundColor(.retroPink)

            VStack(alignment: .leading, spacing: 8) {
                if let currentFile = viewModel.currentSyncFile {
                    Text("Current File: \(currentFile)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }

                ProgressView(value: viewModel.syncProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .retroBlue))

                HStack {
                    Text("\(viewModel.syncingFiles) of \(viewModel.totalFiles ?? 0) files")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Text("\(Int(viewModel.syncProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.retroBlue)
                }
            }
            .padding()
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(10)
        }
    }

    /// Provides buttons for initiating sync actions like full sync and reset.
    /// The reset option is only available in DEBUG builds for safety.
    private var syncActionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Actions")
                .font(.headline)
                .foregroundColor(.retroPink)

            VStack(spacing: 10) {
                Button(action: {
                    viewModel.startFullSync()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync All Content")
                        Spacer()
                    }
                    .padding()
                    .background(LinearGradient(
                        gradient: Gradient(colors: [.retroBlue.opacity(0.7), .retroPurple.opacity(0.7)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
                .disabled(!viewModel.iCloudAvailable || viewModel.isSyncing)

#if DEBUG
                Button(action: {
                    showingResetConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Reset Cloud Sync")
                        Spacer()
                    }
                    .padding()
                    .background(LinearGradient(
                        gradient: Gradient(colors: [.retroPink.opacity(0.7), .red.opacity(0.7)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                }
                .disabled(!viewModel.iCloudAvailable || viewModel.isSyncing)
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
                HStack {
                    Button(action: {
                        withAnimation {
                            viewModel.previousPage()
                        }
                        #if !os(tvOS)
                        HapticFeedbackService.shared.playSelection()
#endif
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(viewModel.currentPage > 0 ? .white : .gray)
                    }
                    .disabled(viewModel.currentPage <= 0)

                    Spacer()

                    // Items per page selector
                    if #available(tvOS 17.0, *) {
                        Menu {
                            Button("10 per page") {
                                viewModel.itemsPerPage = 10
#if !os(tvOS)
                                HapticFeedbackService.shared.playSelection()
#endif
                            }
                            Button("20 per page") {
                                viewModel.itemsPerPage = 20
#if !os(tvOS)
                                HapticFeedbackService.shared.playSelection()
#endif
                            }
                            Button("50 per page") {
                                viewModel.itemsPerPage = 50
#if !os(tvOS)
                                HapticFeedbackService.shared.playSelection()
#endif
                            }
                        } label: {
                            HStack {
                                Text("\(viewModel.itemsPerPage) per page")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("Directory")
                                    .foregroundColor(.white)

                                Spacer()

                                Text("Local: 0")
                                    .foregroundColor(Color.retroBlue)

                                Text("iCloud: 0")
                                    .foregroundColor(.retroPink)
                            }

                            Divider()
                                .background(Color.retroPurple.opacity(0.3))
                        }
                    } else {
                        // Fallback on earlier versions
                    }

                    // Total counts
                    HStack {
                        Text("Total Files")
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Spacer()

                        let totalLocal = viewModel.localFiles.values.reduce(0) { $0 + $1.count }
                        let totalICloud = viewModel.iCloudFiles.values.reduce(0) { $0 + $1.count }

                        Text("Local: \(totalLocal)")
                            .fontWeight(.bold)
                            .foregroundColor(.retroBlue)

                        Text("iCloud: \(totalICloud)")
                            .fontWeight(.bold)
                            .foregroundColor(.retroPink)
                    }
                }
                .background(Color.retroPurple.opacity(0.5))
                .cornerRadius(8)
                .foregroundColor(.white)
            }
            .disabled(viewModel.isLoading || viewModel.isSyncing)
        }
    }

    /// Displays detailed information about files that differ between local storage and iCloud.
    /// Shows filename, directory, file sizes, and sync status with color-coded badges.
    private var syncDifferencesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Differences (\(viewModel.syncDifferences.count))")
                .font(.headline)
                .foregroundColor(Color.retroPink)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if viewModel.syncDifferences.isEmpty {
                        Text("No differences found")
                            .foregroundColor(Color.gray)
                            .padding()
                    } else {
                        ForEach(0..<viewModel.syncDifferences.count, id: \.self) { index in
                            let difference = viewModel.syncDifferences[index]
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(difference)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)

                                    Spacer()

                                    // Default status badge
                                    Text("Unknown")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.retroPurple)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }

                                Text("Directory: Unknown")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.retroBlack.opacity(0.3))
                            .cornerRadius(8)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }

    /// Creates a color-coded badge for different sync statuses.
    /// - Parameter status: The sync status to display (localOnly, iCloudOnly, different, synced)
    /// - Returns: A styled badge view with appropriate color and text
    private func statusBadge(for status: SyncDifference.SyncStatus) -> some View {
        Group {
            switch status {
            case .localOnly:
                Text("Local Only")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.retroBlue.opacity(0.7))
                    .cornerRadius(4)
                    .foregroundColor(.white)
            case .iCloudOnly:
                Text("iCloud Only")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.retroPink.opacity(0.7))
                    .cornerRadius(4)
                    .foregroundColor(.white)
            case .different:
                Text("Different")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.7))
                    .cornerRadius(4)
                    .foregroundColor(.white)
            case .synced:
                Text("Synced")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.7))
                    .cornerRadius(4)
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: - Settings Tab
    /// The Settings tab contains comprehensive CloudKit sync configuration options.
    /// Users can control network conditions, sync frequency, content types, power management, and more.

    private var moreSettingsTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Network Settings Section
                networkSettingsSection
                    .padding(.horizontal)

                // Sync Frequency Section
                syncFrequencySection
                    .padding(.horizontal)

                // Content Type Section
                contentTypeSection
                    .padding(.horizontal)

                // Power Management Section
                powerManagementSection
                    .padding(.horizontal)

                // Performance Settings Section
                performanceSettingsSection
                    .padding(.horizontal)

                // Advanced Settings Section
                advancedSettingsSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
#if !os(tvOS)
            HapticFeedbackService.shared.playSelection(style: .light)
#endif
        }
    }

    // MARK: - Settings Sections
    /// Network conditions settings for CloudKit sync
    private var networkSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Settings")
                .retroSectionHeader()

            VStack(alignment: .leading, spacing: 8) {
                Text("Sync Network Mode")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Picker("Network Mode", selection: $currentCloudKitSyncNetworkMode) {
                    ForEach(CloudKitSyncNetworkMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.description)
                                .foregroundColor(.white)
                            Text(mode.subtitle)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .tag(mode)
                    }
                }
                #if os(tvOS)
                .pickerStyle(.automatic)
                #else
                .pickerStyle(.menu)
                #endif
                .retroCard()

                // Max cellular file size
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Cellular File Size")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    HStack {
                        Text("\(Int(cloudKitMaxCellularFileSizeBytes / (1024 * 1024))) MB")
                            .foregroundColor(.retroBlue)

                        Spacer()

                        #if os(tvOS)
                        // tvOS alternative: Use button controls instead of slider
                        HStack {
                            Button("-") {
                                let currentMB = Int(cloudKitMaxCellularFileSizeBytes / (1024 * 1024))
                                let newValue = max(1, currentMB - 5)
                                cloudKitMaxCellularFileSizeBytes = newValue * 1024 * 1024
                            }
                            .disabled(cloudKitMaxCellularFileSizeBytes <= 1024 * 1024)
                            
                            Button("+") {
                                let currentMB = Int(cloudKitMaxCellularFileSizeBytes / (1024 * 1024))
                                let newValue = min(500, currentMB + 5)
                                cloudKitMaxCellularFileSizeBytes = newValue * 1024 * 1024
                            }
                            .disabled(cloudKitMaxCellularFileSizeBytes >= 500 * 1024 * 1024)
                        }
                        #else
                        Slider(
                            value: Binding(
                                get: { Double(cloudKitMaxCellularFileSizeBytes) / 1024.0 / 1024.0 },
                                set: { cloudKitMaxCellularFileSizeBytes = Int($0 * 1024 * 1024) }
                            ),
                            in: 1...500,
                            step: 5
                        )
                        .accentColor(.retroBlue)
                        #endif
                    }
                }
                .retroCard()
            }
        }
    }

    @Default(.cloudKitMaxCellularFileSize) private var cloudKitMaxCellularFileSizeBytes: Int

    /// Sync frequency and timing settings
    private var syncFrequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Frequency")
                .retroSectionHeader()

            VStack(alignment: .leading, spacing: 8) {
                Text("Check for Changes")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Picker("Sync Frequency", selection: $currentCloudKitSyncFrequency) {
                    ForEach(CloudKitSyncFrequency.allCases, id: \.self) { frequency in
                        VStack(alignment: .leading) {
                            Text(frequency.description)
                                .foregroundColor(.white)
                            Text(frequency.subtitle)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .tag(frequency)
                    }
                }
                #if os(tvOS)
                .pickerStyle(.automatic)
                #else
                .pickerStyle(.menu)
                #endif
                .retroCard()
            }
        }
    }

    /// Content type selection settings
    private var contentTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content Types")
                .retroSectionHeader()

            VStack(alignment: .leading, spacing: 8) {
                Text("What to Sync")
                    .font(.subheadline)
                    .foregroundColor(.white)

                Picker("Content Type", selection: $currentiCloudSyncContentType) {
                    ForEach(CloudKitSyncContentType.allCases, id: \.self) { contentType in
                        VStack(alignment: .leading) {
                            Text(contentType.description)
                                .foregroundColor(.white)
                            Text(contentType.subtitle)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .tag(contentType)
                    }
                }
                #if os(tvOS)
                .pickerStyle(.automatic)
                #else
                .pickerStyle(.menu)
                #endif
                .retroCard()
            }
        }
    }

    /// Power management and battery settings
    private var powerManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Power Management")
                .retroSectionHeader()

            VStack(spacing: 8) {
                // Respect low power mode
                HStack {
                    VStack(alignment: .leading) {
                        Text("Respect Low Power Mode")
                            .foregroundColor(.white)
                        Text("Pause sync when iOS low power mode is enabled")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { Defaults[.cloudKitRespectLowPowerMode] },
                        set: { Defaults[.cloudKitRespectLowPowerMode] = $0 }
                    ))
                    .toggleStyle(RetroTheme.RetroToggleStyle())
                }
                .retroCard()

                // Sync only when charging
                HStack {
                    VStack(alignment: .leading) {
                        Text("Sync Only When Charging")
                            .foregroundColor(.white)
                        Text("Only sync when device is plugged in")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { Defaults[.cloudKitSyncOnlyWhenCharging] },
                        set: { Defaults[.cloudKitSyncOnlyWhenCharging] = $0 }
                    ))
                    .toggleStyle(RetroTheme.RetroToggleStyle())
                }
                .retroCard()
            }
        }
    }

    /// Performance and optimization settings
    private var performanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .retroSectionHeader()

            VStack(spacing: 8) {
                // Background sync
                HStack {
                    VStack(alignment: .leading) {
                        Text("Background Sync")
                            .foregroundColor(.white)
                        Text("Continue syncing when app is in background")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { Defaults[.cloudKitBackgroundSync] },
                        set: { Defaults[.cloudKitBackgroundSync] = $0 }
                    ))
                    .toggleStyle(RetroTheme.RetroToggleStyle())
                }
                .retroCard()

                // Compress files
                HStack {
                    VStack(alignment: .leading) {
                        Text("Compress Files")
                            .foregroundColor(.white)
                        Text("Reduce bandwidth usage by compressing files")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { Defaults[.cloudKitCompressFiles] },
                        set: { Defaults[.cloudKitCompressFiles] = $0 }
                    ))
                    .toggleStyle(RetroTheme.RetroToggleStyle())
                }
                .retroCard()

                // Max concurrent uploads
                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Concurrent Uploads")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    HStack {
                        Text("\(Defaults[.cloudKitMaxConcurrentUploads])")
                            .foregroundColor(.retroBlue)

                        Spacer()

                        #if os(tvOS)
                        // tvOS alternative: Use button controls instead of slider
                        HStack {
                            Button("-") {
                                let newValue = max(1, Defaults[.cloudKitMaxConcurrentUploads] - 1)
                                Defaults[.cloudKitMaxConcurrentUploads] = newValue
                            }
                            .disabled(Defaults[.cloudKitMaxConcurrentUploads] <= 1)
                            
                            Button("+") {
                                let newValue = min(10, Defaults[.cloudKitMaxConcurrentUploads] + 1)
                                Defaults[.cloudKitMaxConcurrentUploads] = newValue
                            }
                            .disabled(Defaults[.cloudKitMaxConcurrentUploads] >= 10)
                        }
                        #else
                        Slider(
                            value: Binding(
                                get: { Double(Defaults[.cloudKitMaxConcurrentUploads]) },
                                set: { Defaults[.cloudKitMaxConcurrentUploads] = Int($0) }
                            ),
                            in: 1...10,
                            step: 1
                        )
                        .accentColor(.retroBlue)
                        #endif
                    }
                }
                .retroCard()
            }
        }
    }

    /// Advanced settings for power users
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Advanced")
                .retroSectionHeader()

            VStack(spacing: 8) {
                // Auto resolve conflicts
                HStack {
                    VStack(alignment: .leading) {
                        Text("Auto Resolve Conflicts")
                            .foregroundColor(.white)
                        Text("Automatically choose most recent version")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { Defaults[.cloudKitAutoResolveConflicts] },
                        set: { Defaults[.cloudKitAutoResolveConflicts] = $0 }
                    ))
                    .toggleStyle(RetroTheme.RetroToggleStyle())
                }
                .retroCard()

                // Show sync notifications
                HStack {
                    VStack(alignment: .leading) {
                        Text("Show Sync Notifications")
                            .foregroundColor(.white)
                        Text("Display notifications for sync status")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { Defaults[.cloudKitShowSyncNotifications] },
                        set: { Defaults[.cloudKitShowSyncNotifications] = $0 }
                    ))
                    .toggleStyle(RetroTheme.RetroToggleStyle())
                }
                .retroCard()

                // Retry failed uploads
                HStack {
                    VStack(alignment: .leading) {
                        Text("Retry Failed Uploads")
                            .foregroundColor(.white)
                        Text("Automatically retry uploads that fail")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { Defaults[.cloudKitRetryFailedUploads] },
                        set: { Defaults[.cloudKitRetryFailedUploads] = $0 }
                    ))
                    #if os(tvOS)
                    .toggleStyle(.automatic)
                    #else
                    .toggleStyle(SwitchToggleStyle(tint: .retroBlue))
                    #endif
                }
                .retroCard()

                // Max retry attempts
                if Defaults[.cloudKitRetryFailedUploads] {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max Retry Attempts")
                            .font(.subheadline)
                            .foregroundColor(.white)

                        HStack {
                            Text("\(Defaults[.cloudKitMaxRetryAttempts])")
                                .foregroundColor(.retroBlue)

                            Spacer()

                            #if os(tvOS)
                            // tvOS alternative: Use button controls instead of slider
                            HStack {
                                Button("-") {
                                    let newValue = max(1, Defaults[.cloudKitMaxRetryAttempts] - 1)
                                    Defaults[.cloudKitMaxRetryAttempts] = newValue
                                }
                                .disabled(Defaults[.cloudKitMaxRetryAttempts] <= 1)
                                
                                Button("+") {
                                    let newValue = min(10, Defaults[.cloudKitMaxRetryAttempts] + 1)
                                    Defaults[.cloudKitMaxRetryAttempts] = newValue
                                }
                                .disabled(Defaults[.cloudKitMaxRetryAttempts] >= 10)
                            }
                            #else
                            Slider(
                                value: Binding(
                                    get: { Double(Defaults[.cloudKitMaxRetryAttempts]) },
                                    set: { Defaults[.cloudKitMaxRetryAttempts] = Int($0) }
                                ),
                                in: 1...10,
                                step: 1
                            )
                            .accentColor(.retroBlue)
                            #endif
                        }
                    }
                    .retroCard()
                }

                // Delete local after upload (dangerous setting)
                HStack {
                    VStack(alignment: .leading) {
                        Text("Delete Local After Upload")
                            .foregroundColor(.white)
                        Text("⚠️ Remove local files after successful upload")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { Defaults[.cloudKitDeleteLocalAfterUpload] },
                        set: { Defaults[.cloudKitDeleteLocalAfterUpload] = $0 }
                    ))
                    #if os(tvOS)
                    .toggleStyle(.automatic)
                    #else
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    #endif
                }
                .retroCard()
            }
        }
    }

    /// Displays detailed diagnostic information for troubleshooting cloud sync issues.
    /// Shows iCloud container info, entitlements, Info.plist configuration, and container info.
    private var diagnosticsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics")
                .font(.headline)
                .foregroundColor(.retroPink)

            VStack(alignment: .leading, spacing: 16) {
                diagnosticSection(title: "iCloud Container", content: viewModel.iCloudDiagnostics)
                diagnosticSection(title: "Entitlements", content: viewModel.entitlementInfo)
                diagnosticSection(title: "Info.plist", content: viewModel.infoPlistInfo)
                diagnosticSection(title: "Container Info", content: viewModel.containerInfo)
            }
        }
    }

    /// Creates a collapsible section for displaying diagnostic information.
    /// - Parameters:
    ///   - title: The section title
    ///   - content: The diagnostic content to display
    /// - Returns: A styled view with scrollable content
    private func diagnosticSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.retroBlue)

            ScrollView {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(8)
            }
            .frame(maxHeight: 150)
            .background(Color.retroBlack.opacity(0.5))
            .cornerRadius(6)
        }
    }

    // MARK: - Helper Functions
    /// Utility functions used throughout the view for common operations
    /// such as formatting and data conversion.

    /// Formats a byte count into a human-readable string.
    /// - Parameters:
    ///   - byteCount: The number of bytes to format
    ///   - countStyle: The style to use for formatting (defaults to .file)
    /// - Returns: A formatted string representation of the byte count
    private func formatByteCount(_ byteCount: Int64, countStyle: ByteCountFormatter.CountStyle = .file) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = countStyle
        return formatter.string(fromByteCount: byteCount)
    }
}

#if DEBUG
struct CloudSyncSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        CloudSyncSettingsView()
            .preferredColorScheme(.dark)
    }
}
#endif
