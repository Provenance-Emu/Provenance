//
//  SyncLogViewer.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/27/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import Combine
import PVLogging
import PVUIBase
import Foundation
import PVLibrary

/// Date range options for filtering logs
public enum DateRange: String, CaseIterable, Identifiable {
    case all = "All Time"
    case today = "Today"
    case yesterday = "Yesterday"
    case lastWeek = "Last 7 Days"
    case lastMonth = "Last 30 Days"
    case custom = "Custom Range"

    public var id: String { rawValue }
}

/// A model representing a sync log entry
public struct SyncLogEntry: Identifiable, Equatable {
    /// The unique identifier for the log entry
    public let id = UUID()

    /// The timestamp of the log entry
    public let timestamp: Date

    /// The message of the log entry
    public let message: String

    /// The type of the log entry
    public let type: LogType

    /// The file associated with the log entry, if any
    public let file: String?

    /// The operation associated with the log entry
    public let operation: SyncOperation

    /// The log entry type
    public enum LogType: String, CaseIterable {
        case info
        case warning
        case error
        case debug
        case verbose

        /// The color associated with the log type — retrowave neon palette
        public var color: Color {
            switch self {
            case .info:
                return .retroBlue
            case .warning:
                return .retroYellow
            case .error:
                return .retroOrange
            case .debug:
                return .retroGreen
            case .verbose:
                return .retroPurple
            }
        }
    }

    /// The sync operation type
    public enum SyncOperation: String, CaseIterable {
        case upload
        case download
        case delete
        case conflict
        case metadata
        case other

        /// The icon associated with the operation
        public var icon: String {
            switch self {
            case .upload:
                return "arrow.up.circle"
            case .download:
                return "arrow.down.circle"
            case .delete:
                return "trash.circle"
            case .conflict:
                return "exclamationmark.triangle"
            case .metadata:
                return "info.circle"
            case .other:
                return "ellipsis.circle"
            }
        }
    }

    /// Initialize a new SyncLogEntry
    /// - Parameters:
    ///   - timestamp: The timestamp of the log entry
    ///   - message: The message of the log entry
    ///   - type: The type of the log entry
    ///   - file: The file associated with the log entry, if any
    ///   - operation: The operation associated with the log entry
    public init(
        timestamp: Date = Date(),
        message: String,
        type: LogType,
        file: String? = nil,
        operation: SyncOperation = .other
    ) {
        self.timestamp = timestamp
        self.message = message
        self.type = type
        self.file = file
        self.operation = operation
    }
}

/// A view model for the sync log viewer
public class SyncLogViewModel: ObservableObject {
    /// Subscribers for notifications
    private var subscribers = Set<AnyCancellable>()
    /// The log entries
    @Published private(set) var logEntries: [SyncLogEntry] = []

    /// The filtered log entries
    @Published private(set) var filteredEntries: [SyncLogEntry] = []

    /// The selected log types
    @Published var selectedLogTypes: Set<SyncLogEntry.LogType> = Set(SyncLogEntry.LogType.allCases)

    /// The selected operations
    @Published var selectedOperations: Set<SyncLogEntry.SyncOperation> = Set(SyncLogEntry.SyncOperation.allCases)

    /// Whether to show the filter panel
    @Published var showFilterPanel = false

    /// The date range for filtering
    @Published var dateRange: DateRange = .all

    /// The custom date range start
    @Published var customStartDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

    /// The custom date range end
    @Published var customEndDate = Date()

    /// The search text
    @Published var searchText = ""

    /// Whether logs are currently being loaded
    @Published var isLoading = false

    /// Initialize a new SyncLogViewModel
    public init() {
        // Subscribe to real-time log events
        subscribeToLogEvents()

        // Set up filter bindings
        setupBindings()

        // Initial load of logs
        loadSyncLogs()
    }

    /// Subscribe to real-time log events from CloudSyncLogManager
    private func subscribeToLogEvents() {
        CloudSyncLogManager.shared.syncEventPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] entry in
                guard let self = self else { return }

                // Convert to view model's SyncLogEntry type
                let viewEntry = self.convertToViewEntry(from: entry)

                // Add to log entries
                self.logEntries.insert(viewEntry, at: 0)

                // Apply filters
                self.applyFilters()
            }
            .store(in: &subscribers)
    }

    /// Set up the bindings
    private func setupBindings() {
        // Observe filter changes and apply filters automatically
        Publishers.CombineLatest4(
            $selectedLogTypes,
            $selectedOperations,
            $searchText.debounce(for: .milliseconds(300), scheduler: RunLoop.main),
            Publishers.CombineLatest3($dateRange, $customStartDate, $customEndDate)
        )
        .sink { [weak self] logTypes, operations, searchText, dateRangeInfo in
            guard let self = self else { return }
            let (dateRange, customStart, customEnd) = dateRangeInfo

            // Update custom dates if needed
            if dateRange == .custom {
                self.customStartDate = customStart
                self.customEndDate = customEnd
            }

            self.applyFilters(
                logTypes: Array(logTypes),
                operations: Array(operations),
                searchText: searchText,
                dateRange: self.getDateRangeForFilter()
            )
        }
        .store(in: &subscribers)
    }

    /// Apply the filters
    /// - Parameters:
    ///   - logTypes: The log types to include (empty means all)
    ///   - operations: The operations to include (empty means all)
    ///   - searchText: The search text
    ///   - dateRange: The date range
    private func applyFilters(
        logTypes: [SyncLogEntry.LogType] = [],
        operations: [SyncLogEntry.SyncOperation] = [],
        searchText: String = "",
        dateRange: ClosedRange<Date>? = nil
    ) {
        // Use selected filters if arrays are empty (for manual calls)
        let typesToFilter = logTypes.isEmpty ? Array(selectedLogTypes) : logTypes
        let opsToFilter = operations.isEmpty ? Array(selectedOperations) : operations

        filteredEntries = logEntries.filter { entry in
            // Filter by log type
            guard typesToFilter.contains(entry.type) else { return false }

            // Filter by operation
            guard opsToFilter.contains(entry.operation) else { return false }

            // Filter by search text
            let searchMatch = searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                (entry.file?.localizedCaseInsensitiveContains(searchText) ?? false)
            guard searchMatch else { return false }

            // Filter by date range
            if let dateRange = dateRange {
                guard dateRange.contains(entry.timestamp) else { return false }
            }

            return true
        }

        // Sort by timestamp (newest first)
        filteredEntries.sort { $0.timestamp > $1.timestamp }
    }

    /// Add a log entry
    /// - Parameter entry: The entry to add
    public func addLogEntry(_ entry: SyncLogEntry) {
        logEntries.append(entry)
        applyFilters(
            logTypes: Array(selectedLogTypes),
            operations: Array(selectedOperations),
            searchText: searchText,
            dateRange: getDateRangeForFilter()
        )
    }

    /// Clear all log entries
    public func clearLogs() {
        logEntries.removeAll()
        filteredEntries.removeAll()

        // Also clear logs in the manager
        Task {
            do {
                try CloudSyncLogManager.shared.clearSyncLogs()
            } catch {
                ELOG("Error clearing sync logs: \(error.localizedDescription)")
            }
        }
    }

    /// Helper method to convert DateRange enum to actual date range
    private func getDateRangeForFilter() -> ClosedRange<Date>? {
        let calendar = Calendar.current
        let now = Date()

        switch dateRange {
        case .all:
            return nil
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return startOfDay...now
        case .yesterday:
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
            let endOfYesterday = calendar.date(byAdding: .day, value: 1, to: startOfYesterday)!.addingTimeInterval(-1)
            return startOfYesterday...endOfYesterday
        case .lastWeek:
            let startOfWeek = calendar.date(byAdding: .day, value: -7, to: now)!
            return startOfWeek...now
        case .lastMonth:
            let startOfMonth = calendar.date(byAdding: .day, value: -30, to: now)!
            return startOfMonth...now
        case .custom:
            return customStartDate...customEndDate
        }
    }

    /// Load sync logs from CloudSyncLogManager
    private func loadSyncLogs() {
        isLoading = true

        Task { @MainActor in
            do {
                // Fetch logs from CloudSyncLogManager
                let syncLogs = try await CloudSyncLogManager.shared.getSyncLogs(maxEntries: 200)

                // Convert log entries to our view model format
                let entries = syncLogs.map { self.convertToViewEntry(from: $0) }

                self.logEntries = entries

                // Apply filters
                self.applyFilters()

                // If no entries were found, show a placeholder entry
                if entries.isEmpty {
                    let placeholderEntry = SyncLogEntry(
                        timestamp: Date(),
                        message: "No sync logs found. Sync operations will be logged here when they occur.",
                        type: .info,
                        operation: .metadata
                    )
                    self.logEntries = [placeholderEntry]
                    self.filteredEntries = [placeholderEntry]
                }
            } catch {
                // Handle error by showing an error entry
                ELOG("Failed to load sync logs: \(error)")
                let errorEntry = SyncLogEntry(
                    timestamp: Date(),
                    message: "Failed to load sync logs: \(error.localizedDescription)",
                    type: .error,
                    operation: .metadata
                )
                self.logEntries = [errorEntry]
                self.filteredEntries = [errorEntry]
            }

            isLoading = false
        }
    }

    /// Convert CloudSyncLogEntry to view model's SyncLogEntry
    private func convertToViewEntry(from entry: CloudSyncLogEntry) -> SyncLogEntry {
        // Convert log level to view model's log type
        let type: SyncLogEntry.LogType
        switch entry.level {
        case .debug:
            type = .debug
        case .info:
            type = .info
        case .warning:
            type = .warning
        case .error:
            type = .error
        case .verbose:
            type = .verbose
        }

        // Convert operation type
        let operation: SyncLogEntry.SyncOperation
        switch entry.operation {
        case .upload:
            operation = .upload
        case .download:
            operation = .download
        case .delete:
            operation = .delete
        case .conflict:
            operation = .conflict
        case .metadata, .initialization, .completion, .unknown:
            operation = .metadata
        case .error:
            operation = .metadata // Map error to metadata in the view model
        }

        // Extract filename from filePath if available
        let file: String? = entry.filePath.flatMap { path in
            // Handle both full paths and just filenames
            if path.contains("/") {
                return URL(fileURLWithPath: path).lastPathComponent
            } else {
                return path
            }
        }

        // Enhance message with provider info if not already present
        var enhancedMessage = entry.message
        if !enhancedMessage.localizedCaseInsensitiveContains(entry.provider.rawValue) {
            enhancedMessage = "[\(entry.provider.rawValue.uppercased())] \(enhancedMessage)"
        }

        return SyncLogEntry(
            timestamp: entry.timestamp,
            message: enhancedMessage,
            type: type,
            file: file,
            operation: operation
        )
    }
}

/// A view that displays sync logs with filtering options
public struct SyncLogViewer: View {
    /// The view model
    @StateObject private var viewModel = SyncLogViewModel()

    /// The number of items per page
    @State private var itemsPerPage = 20

    /// The current page
    @State private var currentPage = 0

    /// Whether the filter panel is expanded
    @State private var isFilterExpanded = false

    /// Whether to show the date range picker
    @State private var showDateRangePicker = false

    /// The start date for filtering
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

    /// The end date for filtering
    @State private var endDate = Date()

    /// The date formatter
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    /// The time formatter
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    /// The date formatter for the date range
    private let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    public var body: some View {
        VStack(spacing: 0) {
            // Search and filter bar
            searchAndFilterBar

            // Filter panel (expandable)
            if isFilterExpanded {
                filterPanel
            }

            // Log entries
            logEntriesList

            // Pagination controls
            paginationControls
        }
        .background(Color.clear)
        .onAppear {
            // Set initial date range
            viewModel.dateRange = .custom
            viewModel.customStartDate = startDate
            viewModel.customEndDate = endDate
        }
    }

    /// The search and filter bar
    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            // Search field — pause menu search bar style
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.retroCyan.opacity(0.7))

                TextField("Search logs...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(.white)

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.retroCyan.opacity(0.45), lineWidth: 1)
            )

            // Filter toggle
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isFilterExpanded.toggle()
                }
#if !os(tvOS)
                HapticFeedbackService.shared.playSelection()
#endif
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle\(isFilterExpanded ? ".fill" : "")")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isFilterExpanded ? .retroPink : .white.opacity(0.7))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isFilterExpanded ? Color.retroPurple.opacity(0.3) : Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isFilterExpanded ? Color.retroPink.opacity(0.6) : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())

            // Clear logs
            Button(action: {
                viewModel.clearLogs()
#if !os(tvOS)
                HapticFeedbackService.shared.playWarning()
#endif
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.retroOrange)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.retroOrange.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.retroOrange.opacity(0.4), lineWidth: 1)
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// The filter panel — retrowave panel style with gradient border
    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Log type filters
            VStack(alignment: .leading, spacing: 6) {
                Text("LOG TYPES")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.retroPink)
                    .tracking(1.2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SyncLogEntry.LogType.allCases, id: \.self) { logType in
                            let isSelected = viewModel.selectedLogTypes.contains(logType)

                            Button(action: {
                                if isSelected {
                                    viewModel.selectedLogTypes.remove(logType)
                                } else {
                                    viewModel.selectedLogTypes.insert(logType)
                                }
#if !os(tvOS)
                                HapticFeedbackService.shared.playSelection()
#endif
                            }) {
                                Text(logType.rawValue.uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(isSelected ? logType.color.opacity(0.25) : Color.white.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(isSelected ? logType.color.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: isSelected ? logType.color.opacity(0.4) : .clear, radius: 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            // Operation filters
            VStack(alignment: .leading, spacing: 6) {
                Text("OPERATIONS")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.retroPink)
                    .tracking(1.2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SyncLogEntry.SyncOperation.allCases, id: \.self) { operation in
                            let isSelected = viewModel.selectedOperations.contains(operation)

                            Button(action: {
                                if isSelected {
                                    viewModel.selectedOperations.remove(operation)
                                } else {
                                    viewModel.selectedOperations.insert(operation)
                                }
#if !os(tvOS)
                                HapticFeedbackService.shared.playSelection()
#endif
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: operation.icon)
                                        .font(.system(size: 11))
                                    Text(operation.rawValue.uppercased())
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isSelected ? Color.retroBlue.opacity(0.25) : Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(isSelected ? Color.retroBlue.opacity(0.7) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                                .shadow(color: isSelected ? Color.retroBlue.opacity(0.4) : .clear, radius: 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            // Date range filter
            VStack(alignment: .leading, spacing: 6) {
                Text("DATE RANGE")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.retroPink)
                    .tracking(1.2)

                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation {
                            showDateRangePicker.toggle()
                        }
#if !os(tvOS)
                        HapticFeedbackService.shared.playSelection()
#endif
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                                .foregroundColor(.retroCyan)
                            Text("\(dateOnlyFormatter.string(from: startDate)) – \(dateOnlyFormatter.string(from: endDate))")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundColor(.white.opacity(0.8))
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.retroCyan.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button(action: {
                        startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        endDate = Date()
                        viewModel.customStartDate = startDate
                        viewModel.customEndDate = endDate
#if !os(tvOS)
                        HapticFeedbackService.shared.playSelection()
#endif
                    }) {
                        Text("RESET")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.8)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundColor(.retroPurple)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.retroPurple.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.retroPurple.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
#if !os(tvOS)
                if showDateRangePicker {
                    VStack {
                        DatePicker("Start Date", selection: $startDate, displayedComponents: [.date])
                            .datePickerStyle(CompactDatePickerStyle())
                            .onChange(of: startDate) { _ in
                                viewModel.customStartDate = startDate
                            }

                        DatePicker("End Date", selection: $endDate, displayedComponents: [.date])
                            .datePickerStyle(CompactDatePickerStyle())
                            .onChange(of: endDate) { _ in
                                viewModel.customEndDate = endDate
                            }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.retroPurple.opacity(0.3), lineWidth: 1)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
#endif
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.retroPurple.opacity(0.65), Color.retroPink.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// The log entries list
    private var logEntriesList: some View {
        let paginatedEntries = getPaginatedEntries()

        return ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(paginatedEntries) { entry in
                    logEntryRow(entry)
                        .transition(.opacity)
                }

                if paginatedEntries.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundColor(.retroPurple.opacity(0.5))
                        Text("No logs match the current filters")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    /// Get the paginated entries
    /// - Returns: The paginated entries
    private func getPaginatedEntries() -> [SyncLogEntry] {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, viewModel.filteredEntries.count)

        guard startIndex < viewModel.filteredEntries.count else {
            return []
        }

        return Array(viewModel.filteredEntries[startIndex..<endIndex])
    }

    /// Create a log entry row — retrowave panel card style
    private func logEntryRow(_ entry: SyncLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Operation icon with glow
                Image(systemName: entry.operation.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(entry.type.color)
                    .shadow(color: entry.type.color.opacity(0.7), radius: 4)

                // Timestamp
                Text(timeFormatter.string(from: entry.timestamp))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                // Log type badge — neon pill style
                Text(entry.type.rawValue.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundColor(.white)
                    .background(
                        Capsule()
                            .fill(entry.type.color.opacity(0.3))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(entry.type.color.opacity(0.7), lineWidth: 1)
                    )
                    .shadow(color: entry.type.color.opacity(0.4), radius: 3)
            }

            // Message
            Text(entry.message)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            // File if available
            if let file = entry.file {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundColor(.retroCyan.opacity(0.6))

                    Text(file)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.retroCyan.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [entry.type.color.opacity(0.4), entry.type.color.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    /// The pagination controls — retrowave divider bar style
    private var paginationControls: some View {
        HStack(spacing: 16) {
            // Previous page
            Button(action: {
                withAnimation {
                    currentPage = max(0, currentPage - 1)
                }
#if !os(tvOS)
                HapticFeedbackService.shared.playSelection()
#endif
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(currentPage > 0 ? .retroCyan : .white.opacity(0.2))
            }
            .disabled(currentPage <= 0)
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // Page info
            Text("\(currentPage + 1) / \(max(1, (viewModel.filteredEntries.count + itemsPerPage - 1) / itemsPerPage))")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))

            // Items per page selector
            if #available(tvOS 17.0, *) {
                Menu {
                    Button("10 per page") { itemsPerPage = 10 }
                    Button("20 per page") { itemsPerPage = 20 }
                    Button("50 per page") { itemsPerPage = 50 }
                    Button("100 per page") { itemsPerPage = 100 }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(itemsPerPage)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.retroPurple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.retroPurple.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.retroPurple.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            Spacer()

            // Next page
            Button(action: {
                withAnimation {
                    let maxPage = max(0, (viewModel.filteredEntries.count - 1) / itemsPerPage)
                    currentPage = min(maxPage, currentPage + 1)
                }
#if !os(tvOS)
                HapticFeedbackService.shared.playSelection()
#endif
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(currentPage < (viewModel.filteredEntries.count - 1) / itemsPerPage ? .retroCyan : .white.opacity(0.2))
            }
            .disabled(currentPage >= (viewModel.filteredEntries.count - 1) / itemsPerPage)
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.5))
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.retroPurple.opacity(0.4), .retroPink.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
    }
}

#Preview {
    SyncLogViewer()
        .preferredColorScheme(.dark)
}
