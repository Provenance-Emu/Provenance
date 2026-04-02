//
//  CloudSyncSettingsView+RecordsTab.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 12/7/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVUIBase
import PVLogging
import PVLibrary
import CloudKit

/// Extension for the CloudKit Records Management tab of CloudSyncSettingsView
extension CloudSyncSettingsView {

    /// The records management tab for browsing, viewing stats, and deleting CloudKit records
    var recordsManagementTab: some View {
        CloudKitRecordsManagementView()
    }
}

/// Main view for CloudKit Records Management
struct CloudKitRecordsManagementView: View {
    @StateObject private var viewModel = CloudKitRecordsViewModel()
    @State private var showingDeleteAllConfirmation = false
    @State private var recordTypeToDelete: String? = nil
    @State private var showingRecordDetail: CloudKitRecordItem? = nil
    @State private var showingDeleteSingleConfirmation = false
    @State private var recordToDelete: CloudKitRecordItem? = nil

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Statistics Overview
                statisticsOverview
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                // Record Type Cards
                recordTypeCardsSection
                    .padding(.horizontal)
                    .transitionWithReducedMotion(.opacity)

                // Records Browser (when a type is selected)
                if viewModel.selectedRecordType != nil {
                    recordsBrowserSection
                        .padding(.horizontal)
                        .transitionWithReducedMotion(.opacity)
                }

                // Error/Success Messages
                messagesSection
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .onAppear {
            Task {
                // Use quick count on appear for faster initial load
                // Full stats with sizes can be fetched via the "Full" button
                await viewModel.quickRefreshCounts()
            }
#if !os(tvOS)
            HapticFeedbackService.shared.playSelection(style: .light)
#endif
        }
        .alert("Delete All Records", isPresented: $showingDeleteAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                if let recordType = recordTypeToDelete {
                    Task {
                        _ = await viewModel.deleteAllRecords(ofType: recordType)
                    }
                }
            }
        } message: {
            if let recordType = recordTypeToDelete {
                Text("Are you sure you want to delete ALL \(recordType) records from CloudKit? This action cannot be undone.")
            }
        }
        .alert("Delete Record", isPresented: $showingDeleteSingleConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let record = recordToDelete {
                    Task {
                        _ = await viewModel.deleteRecord(record)
                    }
                }
            }
        } message: {
            if let record = recordToDelete {
                Text("Are you sure you want to delete \"\(record.displayName)\"? This action cannot be undone.")
            }
        }
        .sheet(item: $showingRecordDetail) { record in
            recordDetailSheet(record: record)
                #if os(tvOS)
                .settingsSheetDetachedFromSubpageDepth()
                #endif
        }
    }

    // MARK: - Statistics Overview

    private var statisticsOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CloudKit Overview")
                    .cloudSyncSectionTitle()

                Spacer()

                // Quick count button (faster)
                Button(action: {
                    Task {
                        await viewModel.quickRefreshCounts()
                    }
#if !os(tvOS)
                    HapticFeedbackService.shared.playSelection()
#endif
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Quick")
                            .font(.caption)
                    }
                    .foregroundColor(.retroPurple)
                }
                .disabled(viewModel.isLoading)

                // Full refresh button
                Button(action: {
                    Task {
                        await viewModel.refreshStats()
                    }
#if !os(tvOS)
                    HapticFeedbackService.shared.playSelection()
#endif
                }) {
                    HStack(spacing: 4) {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Full")
                            .font(.caption)
                    }
                    .foregroundColor(.retroBlue)
                }
                .disabled(viewModel.isLoading)
            }

            // Loading progress indicator
            if let progress = viewModel.loadingProgress {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(progress)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            HStack(spacing: 20) {
                // Total Records
                VStack {
                    Text("\(viewModel.totalRecordCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.retroPink)
                    Text("Total Records")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(8)

                // Total Storage
                VStack {
                    Text(viewModel.formattedTotalSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.retroBlue)
                    Text("Total Size")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(8)

                // Record Types
                VStack {
                    Text("\(viewModel.recordTypeStats.filter { $0.count > 0 }.count)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.retroPurple)
                    Text("Active Types")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.retroBlack.opacity(0.3))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - Record Type Cards

    private var recordTypeCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Record Types")
                .cloudSyncSectionTitle()

            ForEach(viewModel.recordTypeStats) { stats in
                recordTypeCard(stats: stats)
            }
        }
    }

    private func recordTypeCard(stats: CloudKitRecordTypeStats) -> some View {
        VStack(spacing: 0) {
            // Main Card Content
            Button(action: {
                Task {
                    await viewModel.loadRecords(forType: stats.recordType)
                }
#if !os(tvOS)
                HapticFeedbackService.shared.playSelection()
#endif
            }) {
                HStack {
                    // Icon
                    Image(systemName: stats.icon)
                        .font(.title2)
                        .foregroundColor(stats.color)
                        .frame(width: 44, height: 44)
                        .background(stats.color.opacity(0.2))
                        .cornerRadius(10)

                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stats.displayName)
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack(spacing: 12) {
                            Text("\(stats.count) records")
                                .font(.caption)
                                .foregroundColor(.gray)

                            if stats.totalSize > 0 {
                                Text(stats.formattedSize)
                                    .font(.caption)
                                    .foregroundColor(stats.color)
                            }
                        }
                    }

                    Spacer()

                    // Selection Indicator
                    if viewModel.selectedRecordType == stats.recordType {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(stats.color)
                    }

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(viewModel.selectedRecordType == stats.recordType ?
                              stats.color.opacity(0.15) : Color.retroBlack.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(viewModel.selectedRecordType == stats.recordType ?
                                        stats.color.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())

            // Delete Buttons
            if stats.count > 0 {
                HStack(spacing: 8) {
                    // Regular delete (waits for completion)
                    Button(action: {
                        recordTypeToDelete = stats.recordType
                        showingDeleteAllConfirmation = true
#if !os(tvOS)
                        HapticFeedbackService.shared.playWarning()
#endif
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete All")
                                .font(.caption)
                        }
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isDeletingRecords)

                    // Nuke option (fire and forget, faster)
                    Button(action: {
                        viewModel.nukeAllRecords(ofType: stats.recordType)
#if !os(tvOS)
                        HapticFeedbackService.shared.playError()
#endif
                    }) {
                        HStack {
                            Image(systemName: "flame.fill")
                            Text("Nuke")
                                .font(.caption)
                        }
                        .foregroundColor(.orange)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(viewModel.isDeletingRecords)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .background(Color.retroBlack.opacity(0.2))
        .cornerRadius(12)
    }

    // MARK: - Records Browser

    private var recordsBrowserSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with search
            HStack {
                if let selectedType = viewModel.selectedRecordType,
                   let stats = viewModel.recordTypeStats.first(where: { $0.recordType == selectedType }) {
                    Text("\(stats.displayName) Records")
                        .cloudSyncSectionTitle()
                }

                Spacer()

                // Selection mode toggle
                if !viewModel.records.isEmpty {
                    Button(action: {
                        viewModel.isSelectionMode.toggle()
                        if !viewModel.isSelectionMode {
                            viewModel.deselectAll()
                        }
#if !os(tvOS)
                        HapticFeedbackService.shared.playSelection()
#endif
                    }) {
                        Text(viewModel.isSelectionMode ? "Done" : "Select")
                            .font(.caption)
                            .foregroundColor(.retroBlue)
                    }
                }
            }

            // Search bar
            #if !os(tvOS)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search records...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color.retroBlack.opacity(0.5))
            .cornerRadius(8)
            #endif

            // Selection actions
            if viewModel.isSelectionMode && !viewModel.selectedRecordIDs.isEmpty {
                HStack {
                    Text("\(viewModel.selectedRecordIDs.count) selected")
                        .font(.caption)
                        .foregroundColor(.gray)

                    Spacer()

                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    .font(.caption)
                    .foregroundColor(.retroBlue)

                    Button("Delete Selected") {
                        Task {
                            _ = await viewModel.deleteSelectedRecords()
                        }
#if !os(tvOS)
                        HapticFeedbackService.shared.playWarning()
#endif
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .disabled(viewModel.isDeletingRecords)
                }
                .padding(.horizontal)
            }

            // Loading indicator
            if viewModel.isLoadingRecords {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    Text("Loading records...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding()
            }

            // Records list
            if viewModel.filteredRecords.isEmpty && !viewModel.isLoadingRecords {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No records found")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.paginatedRecords) { record in
                    recordRow(record: record)
                }

                // Pagination controls
                if viewModel.totalPages > 1 {
                    paginationControls
                }

                // Load more button
                if viewModel.hasMoreRecords {
                    Button(action: {
                        Task {
                            await viewModel.loadMoreRecords()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                            Text("Load More")
                        }
                        .foregroundColor(.retroBlue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.retroBlue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(viewModel.isLoadingRecords)
                }
            }
        }
        .padding()
        .background(Color.retroBlack.opacity(0.3))
        .cornerRadius(12)
    }

    private func recordRow(record: CloudKitRecordItem) -> some View {
        HStack {
            // Selection checkbox
            if viewModel.isSelectionMode {
                Button(action: {
                    viewModel.toggleSelection(record.id)
#if !os(tvOS)
                    HapticFeedbackService.shared.playSelection(style: .light)
#endif
                }) {
                    Image(systemName: viewModel.selectedRecordIDs.contains(record.id) ?
                          "checkmark.circle.fill" : "circle")
                        .foregroundColor(viewModel.selectedRecordIDs.contains(record.id) ?
                                         .retroPink : .gray)
                }
            }

            // Record info
            Button(action: {
                showingRecordDetail = record
            }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(record.subtitle)
                            .font(.caption)
                            .foregroundColor(.gray)

                        if let size = record.formattedSize {
                            Text(size)
                                .font(.caption)
                                .foregroundColor(.retroBlue)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .buttonStyle(PlainButtonStyle())

            // Quick delete button
            if !viewModel.isSelectionMode {
                Button(action: {
                    recordToDelete = record
                    showingDeleteSingleConfirmation = true
#if !os(tvOS)
                    HapticFeedbackService.shared.playWarning()
#endif
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.7))
                }
                .disabled(viewModel.isDeletingRecords)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.retroBlack.opacity(0.2))
        .cornerRadius(8)
    }

    private var paginationControls: some View {
        HStack {
            Button(action: {
                viewModel.previousPage()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(viewModel.currentPage > 0 ? .white : .gray)
            }
            .disabled(viewModel.currentPage <= 0)

            Spacer()

            Text("Page \(viewModel.currentPage + 1) of \(viewModel.totalPages)")
                .font(.caption)
                .foregroundColor(.gray)

            Spacer()

            Button(action: {
                viewModel.nextPage()
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(viewModel.currentPage < viewModel.totalPages - 1 ? .white : .gray)
            }
            .disabled(viewModel.currentPage >= viewModel.totalPages - 1)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Record Detail Sheet

    private func recordDetailSheet(record: CloudKitRecordItem) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(record.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(record.recordType)
                            .font(.subheadline)
                            .foregroundColor(.retroPink)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.retroDarkBlue.opacity(0.5))
                    .cornerRadius(12)

                    // Record ID
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Record ID")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(record.id)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.retroBlack.opacity(0.3))
                    .cornerRadius(8)

                    // Size and Dates
                    HStack(spacing: 12) {
                        if let size = record.formattedSize {
                            VStack {
                                Text(size)
                                    .font(.headline)
                                    .foregroundColor(.retroBlue)
                                Text("Size")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.retroBlack.opacity(0.3))
                            .cornerRadius(8)
                        }

                        if let created = record.createdAt {
                            VStack {
                                Text(created, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.retroPurple)
                                Text("Created")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.retroBlack.opacity(0.3))
                            .cornerRadius(8)
                        }

                        if let modified = record.modifiedAt {
                            VStack {
                                Text(modified, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.retroPink)
                                Text("Modified")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.retroBlack.opacity(0.3))
                            .cornerRadius(8)
                        }
                    }

                    // Fields
                    if !record.fields.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fields")
                                .font(.headline)
                                .foregroundColor(.retroPink)

                            ForEach(record.fields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(key)
                                        .font(.caption)
                                        .foregroundColor(.retroBlue)
                                    Text(value)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.retroBlack.opacity(0.3))
                        .cornerRadius(8)
                    }

                    // Delete Button
                    Button(action: {
                        recordToDelete = record
                        showingRecordDetail = nil
                        showingDeleteSingleConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Record")
                        }
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            .background(Color.retroDarkBlue.edgesIgnoringSafeArea(.all))
            .navigationTitle("Record Details")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showingRecordDetail = nil
                    }
                }
            }
        }
    }

    // MARK: - Messages Section

    private var messagesSection: some View {
        VStack(spacing: 8) {
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }

            if let success = viewModel.successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(success)
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.8))
                .cornerRadius(8)
            }

            if viewModel.isDeletingRecords {
                VStack(spacing: 4) {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text(viewModel.loadingProgress ?? "Deleting records...")
                            .font(.caption)
                    }
                    Text("Records are deleted in batches as they're found")
                        .font(.caption2)
                        .opacity(0.7)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.8))
                .cornerRadius(8)
            }
        }
    }
}

#if DEBUG
struct CloudKitRecordsManagementView_Previews: PreviewProvider {
    static var previews: some View {
        CloudKitRecordsManagementView()
            .preferredColorScheme(.dark)
            .background(Color.retroDarkBlue)
    }
}
#endif
