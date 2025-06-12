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
        
        /// The color associated with the log type
        public var color: Color {
            switch self {
            case .info:
                return .retroBlue
            case .warning:
                return .yellow
            case .error:
                return .red
            case .debug:
                return .green
            case .verbose:
                return .gray
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
        Publishers.CombineLatest4(
            $selectedLogTypes,
            $selectedOperations,
            $searchText,
            $dateRange
        )
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] newDateRange in
            self?.applyFilters(
                logTypes: Array(self?.selectedLogTypes ?? []),
                operations: Array(self?.selectedOperations ?? []),
                searchText: self?.searchText ?? "",
                dateRange: self?.getDateRangeForFilter() ?? nil
            )
        }
        .store(in: &subscribers)
    }
    
    /// Apply the filters
    /// - Parameters:
    ///   - logTypes: The log types to include
    ///   - operations: The operations to include
    ///   - searchText: The search text
    ///   - dateRange: The date range
    private func applyFilters(
        logTypes: [SyncLogEntry.LogType] = [],
        operations: [SyncLogEntry.SyncOperation] = [],
        searchText: String = "",
        dateRange: ClosedRange<Date>? = nil
    ) {
        filteredEntries = logEntries.filter { entry in
            // Filter by log type
            guard logTypes.contains(entry.type) else { return false }
            
            // Filter by operation
            guard operations.contains(entry.operation) else { return false }
            
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
        let file: String? = entry.filePath.flatMap { URL(fileURLWithPath: $0).lastPathComponent }
        
        return SyncLogEntry(
            timestamp: entry.timestamp,
            message: entry.message,
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
        .onAppear {
            // Set initial date range
            viewModel.dateRange = .custom
            viewModel.customStartDate = startDate
            viewModel.customEndDate = endDate
        }
    }
    
    /// The search and filter bar
    private var searchAndFilterBar: some View {
        HStack {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search logs...", text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color.retroBlack.opacity(0.3))
            .cornerRadius(8)
            
            // Filter toggle
            Button(action: {
                withAnimation(.spring()) {
                    isFilterExpanded.toggle()
                }
#if !os(tvOS)
                HapticFeedbackService.shared.playSelection()
#endif
            }) {
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle\(isFilterExpanded ? ".fill" : "")")
            }
            .retroButton(colors: [.retroPurple])
            
            // Clear logs
            Button(action: {
                viewModel.clearLogs()
#if !os(tvOS)
                HapticFeedbackService.shared.playWarning()
#endif
            }) {
                Label("Clear", systemImage: "trash")
            }
            .retroButton(colors: [.red.opacity(0.7), .orange.opacity(0.7)])
        }
        .padding()
    }
    
    /// The filter panel
    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Log type filters
            VStack(alignment: .leading, spacing: 8) {
                Text("Log Types")
                    .retroSectionHeader()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
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
                                Text(logType.rawValue.capitalized)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? logType.color.opacity(0.7) : Color.retroBlack.opacity(0.5))
                                    .cornerRadius(16)
                                    .foregroundColor(isSelected ? .white : .gray)
                                    .retroGlowingBorder(color: isSelected ? logType.color : .clear, lineWidth: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Operation filters
            VStack(alignment: .leading, spacing: 8) {
                Text("Operations")
                    .retroSectionHeader()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
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
                                    Text(operation.rawValue.capitalized)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.retroBlue.opacity(0.7) : Color.retroBlack.opacity(0.5))
                                .cornerRadius(16)
                                .foregroundColor(isSelected ? .white : .gray)
                                .retroGlowingBorder(color: isSelected ? .retroBlue : .clear, lineWidth: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Date range filter
            VStack(alignment: .leading, spacing: 8) {
                Text("Date Range")
                    .retroSectionHeader()
                
                HStack {
                    Button(action: {
                        withAnimation {
                            showDateRangePicker.toggle()
                        }
#if !os(tvOS)
                        HapticFeedbackService.shared.playSelection()
#endif
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("\(dateOnlyFormatter.string(from: startDate)) - \(dateOnlyFormatter.string(from: endDate))")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.retroBlack.opacity(0.5))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // Reset to last 7 days
                        startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                        endDate = Date()
                        viewModel.customStartDate = startDate
                        viewModel.customEndDate = endDate
#if !os(tvOS)
                        HapticFeedbackService.shared.playSelection()
#endif
                    }) {
                        Text("Reset")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.retroPurple.opacity(0.7))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                    }
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
                    .padding()
                    .background(Color.retroBlack.opacity(0.3))
                    .cornerRadius(8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
#endif
            }
        }
        .padding()
        .background(Color.retroBlack.opacity(0.2))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    /// The log entries list
    private var logEntriesList: some View {
        let paginatedEntries = getPaginatedEntries()
        
        return ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(paginatedEntries) { entry in
                    logEntryRow(entry)
                        .transition(.opacity)
                }
                
                if paginatedEntries.isEmpty {
                    Text("No logs match the current filters")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .padding()
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
    
    /// Create a log entry row
    /// - Parameter entry: The log entry
    /// - Returns: A view
    private func logEntryRow(_ entry: SyncLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Timestamp
                Text(dateFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Log type badge
                Text(entry.type.rawValue.uppercased())
                    .retroBadge(color: entry.type.color)
                
                // Operation icon
                Image(systemName: entry.operation.icon)
                    .foregroundColor(entry.type.color)
            }
            
            // Message
            Text(entry.message)
                .font(.body)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // File if available
            if let file = entry.file {
                HStack {
                    Image(systemName: "doc")
                        .foregroundColor(.gray)
                    
                    Text(file)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding()
        .background(Color.retroBlack.opacity(0.3))
        .cornerRadius(8)
        .retroGlowingBorder(color: entry.type.color.opacity(0.5), lineWidth: 1)
    }
    
    /// The pagination controls
    private var paginationControls: some View {
        HStack {
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
                    .foregroundColor(currentPage > 0 ? .white : .gray)
            }
            .disabled(currentPage <= 0)
            
            Spacer()
            
            // Page info
            Text("Page \(currentPage + 1) of \(max(1, (viewModel.filteredEntries.count + itemsPerPage - 1) / itemsPerPage))")
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            // Items per page selector
            if #available(tvOS 17.0, *) {
                Menu {
                    Button("10 per page") { itemsPerPage = 10 }
                    Button("20 per page") { itemsPerPage = 20 }
                    Button("50 per page") { itemsPerPage = 50 }
                    Button("100 per page") { itemsPerPage = 100 }
                } label: {
                    HStack {
                        Text("\(itemsPerPage) per page")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                // Fallback on earlier versions
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
                    .foregroundColor(currentPage < (viewModel.filteredEntries.count - 1) / itemsPerPage ? .white : .gray)
            }
            .disabled(currentPage >= (viewModel.filteredEntries.count - 1) / itemsPerPage)
        }
        .padding()
        .background(Color.retroBlack.opacity(0.2))
    }
}

#Preview {
    SyncLogViewer()
        .preferredColorScheme(.dark)
}
