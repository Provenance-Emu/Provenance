//
//  RetroLogViewModel.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/24/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import PVLogging

/// ViewModel for RetroLogView
public final class RetroLogViewModel: ObservableObject {
    // MARK: - Sort Order Enum
    public enum SortOrder {
        case newestFirst
        case oldestFirst
    }
    
    // MARK: - Published Properties
    
    /// The raw logs, typically appended chronologically
    @Published public var logs: [LogEntry] = []
    
    /// The minimum log level to display
    @Published public var minLogLevel: LogLevel = .info
    
    /// Whether to auto-scroll to the bottom
    @Published public var autoScroll = true
    
    /// Whether to show full log details
    @Published public var showFullDetails = false
    
    /// Search text
    @Published public var searchText = ""

    /// Current sort order for logs
    @Published public var sortOrder: SortOrder = .newestFirst // Default to newest first
    
    // MARK: - Private Properties
    
    /// Subscription to log publisher
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init() {
        // Load initial logs
        logs = PVLogPublisher.shared.getRecentLogs(minLevel: minLogLevel)
        
        // Subscribe to log updates
        PVLogPublisher.shared.logPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] entry in
                self?.logs.append(entry)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Clear all logs
    public func clearLogs() {
        logs.removeAll()
        PVLogPublisher.shared.clearLogs()
    }

    /// Toggle the sort order of logs.
    public func toggleSortOrder() {
        sortOrder = (sortOrder == .newestFirst) ? .oldestFirst : .newestFirst
        // Note: Auto-scroll behavior might need adjustment in the View
        // depending on the sort order, especially if autoScroll means "scroll to newest".
    }
    
    /// Get color for log level
    public func logLevelColor(_ level: LogLevel) -> Color {
        switch level {
        case .verbose:
            return Color.gray
        case .debug:
            return RetroTheme.retroBlue
        case .info:
            return Color.green
        case .warning:
            return Color.orange
        case .error:
            return RetroTheme.retroPink
        }
    }
    
    /// Get filtered and sorted logs based on search text, minimum log level, and sort order.
    public var displayedLogs: [LogEntry] { // Renamed from filteredLogs
        let filtered = logs.filter { log in
            (searchText.isEmpty || log.message.localizedCaseInsensitiveContains(searchText)) &&
            log.level.rawValue >= minLogLevel.rawValue
        }
        
        switch sortOrder {
        case .newestFirst:
            // Assumes 'logs' are [oldest, ..., newest], so reverse for newest first display.
            return filtered.reversed()
        case .oldestFirst:
            return filtered
        }
    }
}
