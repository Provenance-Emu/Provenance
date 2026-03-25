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

    #if os(tvOS)
    @Environment(\.dismiss) private var dismiss
    #endif

    public init() {}

    public var body: some View {
        ZStack {
            #if os(tvOS)
            Color(red: 0.04, green: 0.04, blue: 0.12)
                .edgesIgnoringSafeArea(.all)
            RetroGrid(lineSpacing: 30, lineColor: Color.retroPink.opacity(0.04))
                .edgesIgnoringSafeArea(.all)
                .opacity(0.4)
            #else
            Color.retroDarkBlue.edgesIgnoringSafeArea(.all)
            #endif

            VStack(spacing: 0) {
                statusHeader
                tabSelector

                TabView(selection: $selectedTab) {
                    cloudKitTab.tag(0)
                    #if !os(tvOS)
                    iCloudDriveTab.tag(1)
                    #endif
                    settingsTab.tag(2)
                    moreSettingsTab.tag(3)
                    recordsManagementTab.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                #if os(tvOS)
                .background(Color.white.opacity(0.02))
                #else
                .background(Color.retroBlack.opacity(0.3))
                #endif
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .onAppear {
            viewModel.loadSyncInfo()
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationStack {
                CloudKitDiagnosticView()
                    #if !os(tvOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showDiagnostics = false
                            }
                        }
                    }
            }
        }
        #if os(tvOS)
        .focusSection() // Contain focus to prevent escape to parent tab bar
        .onExitCommand {
            // Handle Menu button to go back properly
            dismiss()
        }
        #endif
    }

    // MARK: - Status Header
    /// The status header displays the overall sync status, including availability and sync progress.
    /// It appears at the top of the view and provides immediate feedback about the sync state.

    private var statusHeader: some View {
        VStack(spacing: 12) {
            #if os(tvOS)
            Text("CLOUD SYNC")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .leading, endPoint: .trailing)
                )
                .padding(.top)
            #else
            Text("Cloud Sync")
                .font(.title)
                .foregroundColor(.retroPink)
                .padding(.top)
            #endif

            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.iCloudAvailable ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                    #if os(tvOS)
                    .shadow(color: viewModel.iCloudAvailable ? Color.green.opacity(0.6) : Color.red.opacity(0.6), radius: 6)
                    #endif

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.syncStatus)
                        .font(.subheadline)
                        .foregroundColor(.white)

                    if iCloudSyncEnabled && viewModel.iCloudAvailable {
                        Text("Mode: \(currentiCloudSyncMode.description)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

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
            #if !os(tvOS)
            tabButton(title: "iCloud Drive", systemImage: "folder.fill.badge.person.crop", tag: 1)
            #endif
            tabButton(title: "Settings", systemImage: "gear", tag: 2)
            tabButton(title: "Advanced", systemImage: "slider.horizontal.3", tag: 3)
            tabButton(title: "Records", systemImage: "doc.on.doc.fill", tag: 4)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func tabButton(title: String, systemImage: String, tag: Int) -> some View {
        #if os(tvOS)
        CloudSyncFocusableTabButton(title: title, systemImage: systemImage, isSelected: selectedTab == tag) {
            withAnimation { selectedTab = tag }
        }
        #else
        Button(action: {
            withAnimation { selectedTab = tag }
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
        #endif
    }

    // MARK: - CloudKit Tab
    /// The CloudKit tab displays CloudKit-specific information including analytics, record counts,
    /// sync progress, and sync actions. This tab focuses on the CloudKit backend sync functionality.

    private var cloudKitTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Account status warning if needed
                if !viewModel.iCloudAvailable {
                    accountStatusWarning
                        .padding(.horizontal)
                }

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

    /// Account status warning banner
    private var accountStatusWarning: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("iCloud Account Issue")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Text("CloudKit sync requires a valid iCloud account. Please check your iCloud settings in System Settings.")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.orange.opacity(0.2))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
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
                        .cloudSyncSectionTitle()

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
                .cloudSyncSectionTitle()

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
                    .cloudSyncSectionTitle()
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
                #if os(tvOS)
                .buttonStyle(TVMediaPlainButtonStyle())
                .tvOSDisableFocusEffect()
                #else
                .buttonStyle(PlainButtonStyle())
                #endif
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
                        .cloudSyncCard()
                        .cloudSyncCard()
                    }
                    #if os(tvOS)
                    .buttonStyle(TVMediaPlainButtonStyle())
                    .tvOSDisableFocusEffect()
                    #else
                    .buttonStyle(PlainButtonStyle())
                    #endif
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
                .cloudSyncSectionTitle()

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
                .cloudSyncSectionTitle()

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
                .cloudSyncSectionTitle()

            VStack(alignment: .leading, spacing: 16) {
                if let currentFile = viewModel.currentSyncFile {
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
                        let clampedProgress = max(0, min(CGFloat(viewModel.syncProgress), 1))
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
                                .frame(maxWidth: .infinity)
                                .frame(height: 12)
                                .scaleEffect(x: clampedProgress, y: 1, anchor: .leading)
                                .cornerRadius(6)
                                .overlay(alignment: .trailing) {
                                    // Glow effect tracks the leading-scaled fill.
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
                                        .opacity(clampedProgress > 0.02 ? 1 : 0)
                                }
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true),
                                    value: viewModel.syncProgress
                                )
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
                .cloudSyncSectionTitle()

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
                .cloudSyncSectionTitle()

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
                .cloudSyncSectionTitle()

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
                #if os(tvOS)
                .buttonStyle(TVMediaPlainButtonStyle())
                .tvOSDisableFocusEffect()
                #else
                .buttonStyle(PlainButtonStyle())
                #endif
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
                #if os(tvOS)
                .buttonStyle(TVMediaPlainButtonStyle())
                .tvOSDisableFocusEffect()
                #else
                .buttonStyle(PlainButtonStyle())
                #endif
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
                    #if os(tvOS)
                    .buttonStyle(TVMediaPlainButtonStyle())
                    .tvOSDisableFocusEffect()
                    #else
                    .buttonStyle(PlainButtonStyle())
                    #endif
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
                .cloudSyncSectionTitle()

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
            #if os(tvOS)
            let sectionSpacing: CGFloat = 32
            #else
            let sectionSpacing: CGFloat = 16
            #endif
            LazyVStack(alignment: .leading, spacing: sectionSpacing) {
                networkSettingsSection
                    .padding(.horizontal)

                syncFrequencySection
                    .padding(.horizontal)

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
        VStack(alignment: .leading, spacing: 16) {
            Text("Network Settings")
                .cloudSyncSectionTitle()

            #if os(tvOS)
            Text("Sync Network Mode")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)

            VStack(spacing: 4) {
                ForEach(CloudKitSyncNetworkMode.allCases, id: \.self) { mode in
                    CloudSyncSelectionRow(
                        title: mode.description,
                        subtitle: mode.subtitle,
                        isSelected: currentCloudKitSyncNetworkMode == mode
                    ) {
                        withAnimation { currentCloudKitSyncNetworkMode = mode }
                    }
                }
            }

            CloudSyncStepperRow(
                title: "Max Cellular File Size",
                value: "\(Int(cloudKitMaxCellularFileSizeBytes / (1024 * 1024))) MB",
                onDecrement: {
                    let currentMB = Int(cloudKitMaxCellularFileSizeBytes / (1024 * 1024))
                    cloudKitMaxCellularFileSizeBytes = max(1, currentMB - 5) * 1024 * 1024
                },
                onIncrement: {
                    let currentMB = Int(cloudKitMaxCellularFileSizeBytes / (1024 * 1024))
                    cloudKitMaxCellularFileSizeBytes = min(500, currentMB + 5) * 1024 * 1024
                },
                decrementDisabled: cloudKitMaxCellularFileSizeBytes <= 1024 * 1024,
                incrementDisabled: cloudKitMaxCellularFileSizeBytes >= 500 * 1024 * 1024
            )
            #else
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
                .pickerStyle(.menu)
                .cloudSyncCard()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Max Cellular File Size")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    HStack {
                        Text("\(Int(cloudKitMaxCellularFileSizeBytes / (1024 * 1024))) MB")
                            .foregroundColor(.retroBlue)
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { Double(cloudKitMaxCellularFileSizeBytes) / 1024.0 / 1024.0 },
                                set: { cloudKitMaxCellularFileSizeBytes = Int($0 * 1024 * 1024) }
                            ),
                            in: 1...500,
                            step: 5
                        )
                        .accentColor(.retroBlue)
                    }
                }
                .cloudSyncCard()
            }
            #endif
        }
    }

    @Default(.cloudKitMaxCellularFileSize) private var cloudKitMaxCellularFileSizeBytes: Int

    /// Sync frequency and timing settings
    private var syncFrequencySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync Frequency")
                .cloudSyncSectionTitle()

            #if os(tvOS)
            Text("Check for Changes")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)

            VStack(spacing: 4) {
                ForEach(CloudKitSyncFrequency.allCases, id: \.self) { frequency in
                    CloudSyncSelectionRow(
                        title: frequency.description,
                        subtitle: frequency.subtitle,
                        isSelected: currentCloudKitSyncFrequency == frequency
                    ) {
                        withAnimation { currentCloudKitSyncFrequency = frequency }
                    }
                }
            }
            #else
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
                .pickerStyle(.menu)
                .cloudSyncCard()
            }
            #endif
        }
    }

    /// Content type selection settings
    private var contentTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content Types")
                .cloudSyncSectionTitle()

            #if os(tvOS)
            Text("What to Sync")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)

            VStack(spacing: 4) {
                ForEach(CloudKitSyncContentType.allCases, id: \.self) { contentType in
                    CloudSyncSelectionRow(
                        title: contentType.description,
                        subtitle: contentType.subtitle,
                        isSelected: currentiCloudSyncContentType == contentType
                    ) {
                        withAnimation { currentiCloudSyncContentType = contentType }
                    }
                }
            }
            #else
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
                .pickerStyle(.menu)
                .cloudSyncCard()
            }
            #endif
        }
    }

    /// Power management and battery settings
    private var powerManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Power Management")
                .cloudSyncSectionTitle()

            VStack(spacing: 8) {
                CloudSyncToggleRow(
                    title: "Respect Low Power Mode",
                    subtitle: "Pause sync when iOS low power mode is enabled",
                    isOn: Binding(
                        get: { Defaults[.cloudKitRespectLowPowerMode] },
                        set: { Defaults[.cloudKitRespectLowPowerMode] = $0 }
                    )
                )

                CloudSyncToggleRow(
                    title: "Sync Only When Charging",
                    subtitle: "Only sync when device is plugged in",
                    isOn: Binding(
                        get: { Defaults[.cloudKitSyncOnlyWhenCharging] },
                        set: { Defaults[.cloudKitSyncOnlyWhenCharging] = $0 }
                    )
                )
            }
        }
    }

    /// Performance and optimization settings
    private var performanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance")
                .cloudSyncSectionTitle()

            VStack(spacing: 8) {
                CloudSyncToggleRow(
                    title: "Background Sync",
                    subtitle: "Continue syncing when app is in background",
                    isOn: Binding(
                        get: { Defaults[.cloudKitBackgroundSync] },
                        set: { Defaults[.cloudKitBackgroundSync] = $0 }
                    )
                )

                CloudSyncToggleRow(
                    title: "Compress Files",
                    subtitle: "Reduce bandwidth usage by compressing files",
                    isOn: Binding(
                        get: { Defaults[.cloudKitCompressFiles] },
                        set: { Defaults[.cloudKitCompressFiles] = $0 }
                    )
                )

                CloudSyncStepperRow(
                    title: "Max Concurrent Uploads",
                    value: "\(Defaults[.cloudKitMaxConcurrentUploads])",
                    onDecrement: {
                        Defaults[.cloudKitMaxConcurrentUploads] = max(1, Defaults[.cloudKitMaxConcurrentUploads] - 1)
                    },
                    onIncrement: {
                        Defaults[.cloudKitMaxConcurrentUploads] = min(10, Defaults[.cloudKitMaxConcurrentUploads] + 1)
                    },
                    decrementDisabled: Defaults[.cloudKitMaxConcurrentUploads] <= 1,
                    incrementDisabled: Defaults[.cloudKitMaxConcurrentUploads] >= 10
                )
            }
        }
    }

    /// Advanced settings for power users
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced")
                .cloudSyncSectionTitle()

            VStack(spacing: 8) {
                CloudSyncToggleRow(
                    title: "Auto Resolve Conflicts",
                    subtitle: "Automatically choose most recent version",
                    isOn: Binding(
                        get: { Defaults[.cloudKitAutoResolveConflicts] },
                        set: { Defaults[.cloudKitAutoResolveConflicts] = $0 }
                    )
                )

                CloudSyncToggleRow(
                    title: "Show Sync Notifications",
                    subtitle: "Display notifications for sync status",
                    isOn: Binding(
                        get: { Defaults[.cloudKitShowSyncNotifications] },
                        set: { Defaults[.cloudKitShowSyncNotifications] = $0 }
                    )
                )

                CloudSyncToggleRow(
                    title: "Retry Failed Uploads",
                    subtitle: "Automatically retry uploads that fail",
                    isOn: Binding(
                        get: { Defaults[.cloudKitRetryFailedUploads] },
                        set: { Defaults[.cloudKitRetryFailedUploads] = $0 }
                    )
                )

                if Defaults[.cloudKitRetryFailedUploads] {
                    CloudSyncStepperRow(
                        title: "Max Retry Attempts",
                        value: "\(Defaults[.cloudKitMaxRetryAttempts])",
                        onDecrement: {
                            Defaults[.cloudKitMaxRetryAttempts] = max(1, Defaults[.cloudKitMaxRetryAttempts] - 1)
                        },
                        onIncrement: {
                            Defaults[.cloudKitMaxRetryAttempts] = min(10, Defaults[.cloudKitMaxRetryAttempts] + 1)
                        },
                        decrementDisabled: Defaults[.cloudKitMaxRetryAttempts] <= 1,
                        incrementDisabled: Defaults[.cloudKitMaxRetryAttempts] >= 10
                    )
                }

                CloudSyncToggleRow(
                    title: "Delete Local After Upload",
                    subtitle: "⚠️ Remove local files after successful upload",
                    subtitleColor: .orange,
                    isOn: Binding(
                        get: { Defaults[.cloudKitDeleteLocalAfterUpload] },
                        set: { Defaults[.cloudKitDeleteLocalAfterUpload] = $0 }
                    )
                )
            }
        }
    }

    /// Displays detailed diagnostic information for troubleshooting cloud sync issues.
    /// Shows iCloud container info, entitlements, Info.plist configuration, and container info.
    private var diagnosticsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagnostics")
                .cloudSyncSectionTitle()

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

// MARK: - Styling Helpers

/// Section title modifier: gradient text on tvOS, retroSectionHeader on iOS
extension View {
    func cloudSyncSectionTitle() -> some View {
        #if os(tvOS)
        self
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .leading, endPoint: .trailing)
            )
        #else
        self.retroSectionHeader()
        #endif
    }

    /// Card modifier: translucent panel with gradient border on tvOS, retroCard on iOS
    func cloudSyncCard() -> some View {
        #if os(tvOS)
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.retroPink.opacity(0.2), Color.retroBlue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .cornerRadius(12)
        #else
        self.retroCard()
        #endif
    }

    /// Stepper button styling for +/- controls on tvOS
    func cloudSyncStepperStyle() -> some View {
        #if os(tvOS)
        self
            .buttonStyle(TVMediaPlainButtonStyle())
            .tvOSDisableFocusEffect()
        #else
        self
        #endif
    }
}

#if os(tvOS)
/// Focusable tab button with retrowave focus effects for tvOS
private struct CloudSyncFocusableTabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(isSelected || isFocused ? .white : .gray)
        }
        .focused($isFocused)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isSelected
                        ? LinearGradient(colors: [Color.retroPink.opacity(0.5), Color.retroPurple.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        : isFocused
                            ? LinearGradient(colors: [Color.retroPink.opacity(0.15), Color.retroBlue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isFocused
                        ? LinearGradient(colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : isSelected
                            ? LinearGradient(colors: [Color.retroPink.opacity(0.3), Color.retroPurple.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .top, endPoint: .bottom),
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .shadow(color: isFocused ? Color.retroPink.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
        .scaleEffect(isFocused ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

/// Focusable selection row for picker replacements on tvOS
struct CloudSyncSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            LinearGradient(colors: [.retroPink, .retroBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.retroPink.opacity(0.12)
                            : isFocused
                                ? Color.white.opacity(0.06)
                                : Color.white.opacity(0.03)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isFocused
                            ? LinearGradient(colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : isSelected
                                ? LinearGradient(colors: [Color.retroPink.opacity(0.3), Color.retroBlue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .shadow(color: isFocused ? Color.retroPink.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
            .scaleEffect(isFocused ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .focused($isFocused)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
    }
}
#endif

/// Stepper row with -, value, + layout and platform-appropriate styling
struct CloudSyncStepperRow: View {
    let title: String
    let value: String
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    var decrementDisabled: Bool = false
    var incrementDisabled: Bool = false

    #if os(tvOS)
    @FocusState private var minusFocused: Bool
    @FocusState private var plusFocused: Bool
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                #if os(tvOS)
                .font(.system(size: 18, weight: .medium))
                #else
                .font(.subheadline)
                #endif
                .foregroundColor(.white)

            HStack(spacing: 16) {
                Button(action: onDecrement) {
                    Image(systemName: "minus.circle.fill")
                        #if os(tvOS)
                        .font(.system(size: 32))
                        .foregroundColor(decrementDisabled ? .gray.opacity(0.4) : (minusFocused ? .retroPink : .retroBlue))
                        .scaleEffect(minusFocused ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: minusFocused)
                        #else
                        .font(.system(size: 22))
                        .foregroundColor(decrementDisabled ? .gray.opacity(0.4) : .retroBlue)
                        #endif
                }
                #if os(tvOS)
                .focused($minusFocused)
                .buttonStyle(TVMediaPlainButtonStyle())
                .tvOSDisableFocusEffect()
                #else
                .buttonStyle(PlainButtonStyle())
                #endif
                .disabled(decrementDisabled)

                Text(value)
                    #if os(tvOS)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    #else
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    #endif
                    .foregroundColor(.retroBlue)
                    .frame(minWidth: 40)

                Button(action: onIncrement) {
                    Image(systemName: "plus.circle.fill")
                        #if os(tvOS)
                        .font(.system(size: 32))
                        .foregroundColor(incrementDisabled ? .gray.opacity(0.4) : (plusFocused ? .retroPink : .retroBlue))
                        .scaleEffect(plusFocused ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: plusFocused)
                        #else
                        .font(.system(size: 22))
                        .foregroundColor(incrementDisabled ? .gray.opacity(0.4) : .retroBlue)
                        #endif
                }
                #if os(tvOS)
                .focused($plusFocused)
                .buttonStyle(TVMediaPlainButtonStyle())
                .tvOSDisableFocusEffect()
                #else
                .buttonStyle(PlainButtonStyle())
                #endif
                .disabled(incrementDisabled)

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.retroPink.opacity(0.2), Color.retroBlue.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .cornerRadius(12)
    }
}

/// Toggle row with title, subtitle, and themed toggle with platform-appropriate styling
struct CloudSyncToggleRow: View {
    let title: String
    let subtitle: String
    var subtitleColor: Color = .gray
    @Binding var isOn: Bool
    #if os(tvOS)
    @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        #if os(tvOS)
        Button(action: { isOn.toggle() }) {
            rowContent
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isFocused ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isFocused
                                ? LinearGradient(colors: [Color.retroPink.opacity(0.7), Color.retroBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.retroPink.opacity(0.2), Color.retroBlue.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isFocused ? 2 : 1
                        )
                )
                .shadow(color: isFocused ? Color.retroPink.opacity(0.3) : .clear, radius: 8, x: 0, y: 2)
                .scaleEffect(isFocused ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
        .focused($isFocused)
        .buttonStyle(TVMediaPlainButtonStyle())
        .tvOSDisableFocusEffect()
        #else
        rowContent
            .cloudSyncCard()
        #endif
    }

    private var rowContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    #if os(tvOS)
                    .font(.system(size: 20, weight: .medium))
                    #endif
                    .foregroundColor(.white)
                Text(subtitle)
                    #if os(tvOS)
                    .font(.system(size: 14))
                    #else
                    .font(.caption)
                    #endif
                    .foregroundColor(subtitleColor)
            }

            Spacer()

            ThemedToggle(isOn: $isOn) { EmptyView() }
                #if os(tvOS)
                .allowsHitTesting(false)
                #endif
        }
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
