//
//  CloudKitRecordsViewModel.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 12/7/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLibrary
import PVLogging
import Combine
import CloudKit

/// Represents statistics for a CloudKit record type
public struct CloudKitRecordTypeStats: Identifiable, Equatable {
    public let id: String
    public let recordType: String
    public let displayName: String
    public var count: Int
    public var totalSize: Int64
    public var lastModified: Date?
    public var icon: String
    public var color: Color

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    public static func == (lhs: CloudKitRecordTypeStats, rhs: CloudKitRecordTypeStats) -> Bool {
        lhs.id == rhs.id && lhs.count == rhs.count && lhs.totalSize == rhs.totalSize
    }
}

/// Represents a CloudKit record for display
public struct CloudKitRecordItem: Identifiable, Equatable {
    public let id: String
    public let recordID: CKRecord.ID
    public let recordType: String
    public let displayName: String
    public let subtitle: String
    public let size: Int64?
    public let createdAt: Date?
    public let modifiedAt: Date?
    public let fields: [String: String]

    public var formattedSize: String? {
        guard let size = size else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public static func == (lhs: CloudKitRecordItem, rhs: CloudKitRecordItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// View model for CloudKit Records Management
@MainActor
public class CloudKitRecordsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published public var recordTypeStats: [CloudKitRecordTypeStats] = []
    @Published public var selectedRecordType: String? = nil
    @Published public var records: [CloudKitRecordItem] = []
    @Published public var filteredRecords: [CloudKitRecordItem] = []
    @Published public var searchText: String = "" {
        didSet { filterRecords() }
    }

    @Published public var isLoading = false
    @Published public var isLoadingRecords = false
    @Published public var isDeletingRecords = false
    @Published public var errorMessage: String? = nil
    @Published public var successMessage: String? = nil
    @Published public var loadingProgress: String? = nil  // Shows which record type is loading

    // Pagination
    @Published public var currentPage = 0
    @Published public var itemsPerPage = 20
    @Published public var hasMoreRecords = false

    // Selection for batch operations
    @Published public var selectedRecordIDs: Set<String> = []
    @Published public var isSelectionMode = false

    // MARK: - Private Properties

    // Optional on purpose: `CKContainer(identifier:)` TRAPS (does not throw) when the
    // container is missing from the process entitlements, so building it eagerly crashed
    // the app as soon as this screen opened on a build without the CloudKit entitlement
    // (notably sideloads signed with a different team). `iCloudConstants.container` is the
    // entitlement-gated accessor and yields nil rather than trapping.
    private let container: CKContainer?
    private let database: CKDatabase?

    /// False when the app has no CloudKit entitlement — the UI can explain instead of
    /// offering actions that cannot work.
    public var isCloudKitAvailable: Bool { container != nil }

    /// Surfaces a clear message instead of silently doing nothing when unentitled.
    private func reportCloudKitUnavailable() {
        errorMessage = "iCloud is not available in this build (no CloudKit entitlement)."
    }

    /// Thrown by the `throws` helpers when CloudKit isn't entitled.
    struct CloudKitUnavailableError: LocalizedError {
        var errorDescription: String? { "iCloud is not available in this build." }
    }
    private var queryCursor: CKQueryOperation.Cursor?
    private var lastStatsRefresh: Date?
    private let statsRefreshInterval: TimeInterval = 60  // Minimum seconds between auto-refreshes

    // Record type definitions
    private let recordTypes: [(type: String, name: String, icon: String, color: Color)] = [
        (CloudKitSchema.RecordType.rom.rawValue, "ROMs", "gamecontroller.fill", .retroBlue),
        (CloudKitSchema.RecordType.saveState.rawValue, "Save States", "square.and.arrow.down.fill", .retroPurple),
        (CloudKitSchema.RecordType.bios.rawValue, "BIOS", "cpu.fill", .retroPink),
        (CloudKitSchema.RecordType.file.rawValue, "Files", "doc.fill", .retroGreen)
    ]

    // MARK: - Computed Properties

    public var paginatedRecords: [CloudKitRecordItem] {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredRecords.count)
        guard startIndex < filteredRecords.count else { return [] }
        return Array(filteredRecords[startIndex..<endIndex])
    }

    public var totalPages: Int {
        max(1, (filteredRecords.count + itemsPerPage - 1) / itemsPerPage)
    }

    public var totalRecordCount: Int {
        recordTypeStats.reduce(0) { $0 + $1.count }
    }

    public var totalStorageSize: Int64 {
        recordTypeStats.reduce(0) { $0 + $1.totalSize }
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalStorageSize, countStyle: .file)
    }

    // MARK: - Initialization

    public init() {
        self.container = iCloudConstants.container
        self.database = container?.privateCloudDatabase

        // Initialize stats with zero counts
        recordTypeStats = recordTypes.map { type in
            CloudKitRecordTypeStats(
                id: type.type,
                recordType: type.type,
                displayName: type.name,
                count: 0,
                totalSize: 0,
                lastModified: nil,
                icon: type.icon,
                color: type.color
            )
        }
    }

    // MARK: - Public Methods

    /// Refresh statistics for all record types (parallel fetch for speed)
    /// - Parameter forceRefresh: If false, will skip refresh if recently fetched
    public func refreshStats(forceRefresh: Bool = true) async {
        // Skip if recently refreshed (unless forced)
        if !forceRefresh, let lastRefresh = lastStatsRefresh,
           Date().timeIntervalSince(lastRefresh) < statsRefreshInterval {
            DLOG("Skipping stats refresh - last refresh was \(Int(Date().timeIntervalSince(lastRefresh)))s ago")
            return
        }

        isLoading = true
        errorMessage = nil
        loadingProgress = "Fetching record counts..."

        // Fetch all record type stats in parallel for faster loading
        await withTaskGroup(of: (Int, CloudKitRecordTypeStats?).self) { group in
            for (index, recordType) in recordTypes.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else { return (index, nil) }
                    do {
                        let stats = try await self.fetchStatsForRecordType(recordType.type)
                        return (index, CloudKitRecordTypeStats(
                            id: recordType.type,
                            recordType: recordType.type,
                            displayName: recordType.name,
                            count: stats.count,
                            totalSize: stats.totalSize,
                            lastModified: stats.lastModified,
                            icon: recordType.icon,
                            color: recordType.color
                        ))
                    } catch {
                        ELOG("Error fetching stats for \(recordType.type): \(error.localizedDescription)")
                        return (index, nil)
                    }
                }
            }

            // Collect results maintaining order
            var results: [Int: CloudKitRecordTypeStats] = [:]
            for await (index, stats) in group {
                if let stats = stats {
                    results[index] = stats
                }
            }

            // Build final array in order, falling back to existing stats on error
            var updatedStats: [CloudKitRecordTypeStats] = []
            for (index, recordType) in recordTypes.enumerated() {
                if let newStats = results[index] {
                    updatedStats.append(newStats)
                } else if index < recordTypeStats.count {
                    updatedStats.append(recordTypeStats[index])
                } else {
                    // Fallback with zero counts
                    updatedStats.append(CloudKitRecordTypeStats(
                        id: recordType.type,
                        recordType: recordType.type,
                        displayName: recordType.name,
                        count: 0,
                        totalSize: 0,
                        lastModified: nil,
                        icon: recordType.icon,
                        color: recordType.color
                    ))
                }
            }

            recordTypeStats = updatedStats
            lastStatsRefresh = Date()
        }

        loadingProgress = nil
        isLoading = false
    }

    /// Quick refresh - counts only, no size calculation (much faster)
    public func quickRefreshCounts() async {
        isLoading = true
        errorMessage = nil
        loadingProgress = "Quick counting records..."

        await withTaskGroup(of: (Int, Int?).self) { group in
            for (index, recordType) in recordTypes.enumerated() {
                group.addTask { [weak self] in
                    guard let self = self else { return (index, nil) }
                    do {
                        let count = try await self.fetchCountForRecordType(recordType.type)
                        return (index, count)
                    } catch {
                        ELOG("Error counting \(recordType.type): \(error.localizedDescription)")
                        return (index, nil)
                    }
                }
            }

            // Collect counts
            var counts: [Int: Int] = [:]
            for await (index, count) in group {
                if let count = count {
                    counts[index] = count
                }
            }

            // Update only the counts, preserve existing sizes
            for (index, _) in recordTypes.enumerated() {
                if let newCount = counts[index], index < recordTypeStats.count {
                    recordTypeStats[index].count = newCount
                }
            }
        }

        loadingProgress = nil
        isLoading = false
    }

    /// Load records for a specific record type
    public func loadRecords(forType recordType: String, reset: Bool = true) async {
        if reset {
            selectedRecordType = recordType
            records = []
            filteredRecords = []
            currentPage = 0
            queryCursor = nil
        }

        isLoadingRecords = true
        errorMessage = nil

        do {
            let result = try await fetchRecords(ofType: recordType, cursor: queryCursor)
            records.append(contentsOf: result.records)
            filteredRecords = records
            filterRecords()
            queryCursor = result.cursor
            hasMoreRecords = result.cursor != nil
            isLoadingRecords = false
        } catch {
            ELOG("Error loading records: \(error.localizedDescription)")
            errorMessage = "Failed to load records: \(error.localizedDescription)"
            isLoadingRecords = false
        }
    }

    /// Load more records (pagination)
    public func loadMoreRecords() async {
        guard let selectedType = selectedRecordType, hasMoreRecords, !isLoadingRecords else { return }
        await loadRecords(forType: selectedType, reset: false)
    }

    /// Delete a single record
    public func deleteRecord(_ record: CloudKitRecordItem) async -> Bool {
        guard let database else { reportCloudKitUnavailable(); return false }
        isDeletingRecords = true
        errorMessage = nil

        do {
            try await database.deleteRecord(withID: record.recordID)

            // Remove from local arrays
            records.removeAll { $0.id == record.id }
            filteredRecords.removeAll { $0.id == record.id }
            selectedRecordIDs.remove(record.id)

            // Update stats
            if let index = recordTypeStats.firstIndex(where: { $0.recordType == record.recordType }) {
                recordTypeStats[index].count -= 1
                if let size = record.size {
                    recordTypeStats[index].totalSize -= size
                }
            }

            successMessage = "Record deleted successfully"
            isDeletingRecords = false

            // Clear success message after delay
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.successMessage = nil
                }
            }

            return true
        } catch {
            ELOG("Error deleting record: \(error.localizedDescription)")
            errorMessage = "Failed to delete record: \(error.localizedDescription)"
            isDeletingRecords = false
            return false
        }
    }

    /// Delete selected records
    public func deleteSelectedRecords() async -> Int {
        guard let database else { reportCloudKitUnavailable(); return 0 }
        guard !selectedRecordIDs.isEmpty else { return 0 }

        isDeletingRecords = true
        errorMessage = nil
        var deletedCount = 0

        let recordsToDelete = records.filter { selectedRecordIDs.contains($0.id) }

        for record in recordsToDelete {
            do {
                try await database.deleteRecord(withID: record.recordID)

                records.removeAll { $0.id == record.id }
                filteredRecords.removeAll { $0.id == record.id }

                if let index = recordTypeStats.firstIndex(where: { $0.recordType == record.recordType }) {
                    recordTypeStats[index].count -= 1
                    if let size = record.size {
                        recordTypeStats[index].totalSize -= size
                    }
                }

                deletedCount += 1
            } catch {
                ELOG("Error deleting record \(record.id): \(error.localizedDescription)")
            }
        }

        selectedRecordIDs.removeAll()
        isSelectionMode = false
        isDeletingRecords = false

        if deletedCount > 0 {
            successMessage = "Deleted \(deletedCount) record(s)"

            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.successMessage = nil
                }
            }
        }

        return deletedCount
    }

    /// Fire-and-forget delete - starts deletion in background, returns immediately
    /// This is the fastest option - doesn't wait for completion
    public func nukeAllRecords(ofType recordType: String) {
        guard let database else { reportCloudKitUnavailable(); return }
        // Update UI immediately
        if let index = recordTypeStats.firstIndex(where: { $0.recordType == recordType }) {
            recordTypeStats[index].count = 0
            recordTypeStats[index].totalSize = 0
        }
        if selectedRecordType == recordType {
            records = []
            filteredRecords = []
        }

        isDeletingRecords = true
        loadingProgress = "Deleting all \(recordType) records in background..."
        successMessage = "Delete started - records are being removed in background"

        // Fire and forget - run deletion in background task
        Task.detached(priority: .utility) { [weak self, database] in
            guard let self = self else { return }
            var totalDeleted = 0
            var cursor: CKQueryOperation.Cursor? = nil

            repeat {
                do {
                    // Minimal query - only get record IDs
                    let result: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)

                    if let existingCursor = cursor {
                        result = try await database.records(
                            continuingMatchFrom: existingCursor,
                            desiredKeys: [],
                            resultsLimit: 400  // Max CloudKit allows per operation
                        )
                    } else {
                        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                        result = try await database.records(
                            matching: query,
                            desiredKeys: [],
                            resultsLimit: 400
                        )
                    }

                    let recordIDs = result.matchResults.compactMap { (id, res) -> CKRecord.ID? in
                        if case .success = res { return id }
                        return nil
                    }

                    if !recordIDs.isEmpty {
                        // Batch delete - up to 400 at once
                        _ = try? await database.modifyRecords(
                            saving: [],
                            deleting: recordIDs,
                            savePolicy: .allKeys
                        )
                        totalDeleted += recordIDs.count

                        await MainActor.run {
                            self.loadingProgress = "Deleted \(totalDeleted) \(recordType) records..."
                        }
                    }

                    cursor = result.queryCursor
                } catch {
                    ELOG("Background delete error: \(error.localizedDescription)")
                    break
                }
            } while cursor != nil

            await MainActor.run {
                self.isDeletingRecords = false
                self.loadingProgress = nil
                self.successMessage = "Finished: Deleted \(totalDeleted) \(recordType) records"

                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    await MainActor.run {
                        self.successMessage = nil
                    }
                }
            }
        }
    }

    /// Delete all records of a specific type (deletes in batches as fetched for speed)
    public func deleteAllRecords(ofType recordType: String) async -> Int {
        guard let database else { reportCloudKitUnavailable(); return 0 }
        isDeletingRecords = true
        errorMessage = nil
        loadingProgress = "Deleting \(recordType) records..."
        var deletedCount = 0
        var cursor: CKQueryOperation.Cursor? = nil
        var batchNumber = 0

        repeat {
            do {
                batchNumber += 1
                loadingProgress = "Batch \(batchNumber): Fetching \(recordType) records..."

                let result: ([CKRecord.ID: Result<CKRecord, Error>], CKQueryOperation.Cursor?)

                if let existingCursor = cursor {
                    let continuationResult = try await database.records(
                        continuingMatchFrom: existingCursor,
                        desiredKeys: [],  // Empty = fastest fetch
                        resultsLimit: 100  // Smaller batches = more responsive
                    )
                    result = (Dictionary(uniqueKeysWithValues: continuationResult.matchResults), continuationResult.queryCursor)
                } else {
                    let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                    let matchResult = try await database.records(
                        matching: query,
                        desiredKeys: [],  // Empty = fastest fetch
                        resultsLimit: 100  // Smaller batches = more responsive
                    )
                    result = (Dictionary(uniqueKeysWithValues: matchResult.matchResults), matchResult.queryCursor)
                }

                let recordIDs = result.0.compactMap { (recordID, fetchResult) -> CKRecord.ID? in
                    if case .success = fetchResult { return recordID }
                    return nil
                }

                if !recordIDs.isEmpty {
                    loadingProgress = "Batch \(batchNumber): Deleting \(recordIDs.count) records..."

                    // Batch delete for much better performance
                    let deleteResults = try await database.modifyRecords(
                        saving: [],
                        deleting: recordIDs,
                        savePolicy: .allKeys
                    )

                    // Count successful deletes
                    for (_, result) in deleteResults.deleteResults {
                        if case .success = result {
                            deletedCount += 1
                        }
                    }

                    // Update UI count in real-time
                    if let index = recordTypeStats.firstIndex(where: { $0.recordType == recordType }) {
                        recordTypeStats[index].count = max(0, recordTypeStats[index].count - recordIDs.count)
                    }

                    loadingProgress = "Deleted \(deletedCount) \(recordType) records so far..."
                }

                cursor = result.1
            } catch {
                ELOG("Error in batch \(batchNumber): \(error.localizedDescription)")
                // Continue trying - don't break on individual batch errors
                if cursor == nil {
                    // Only break if this was the initial query that failed
                    errorMessage = "Error deleting records: \(error.localizedDescription)"
                    break
                }
            }
        } while cursor != nil

        // Final stats update
        if let index = recordTypeStats.firstIndex(where: { $0.recordType == recordType }) {
            recordTypeStats[index].count = 0
            recordTypeStats[index].totalSize = 0
            recordTypeStats[index].lastModified = nil
        }

        // Clear local records if this is the selected type
        if selectedRecordType == recordType {
            records = []
            filteredRecords = []
        }

        loadingProgress = nil
        isDeletingRecords = false

        if deletedCount > 0 {
            successMessage = "Deleted \(deletedCount) \(recordType) record(s)"

            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self.successMessage = nil
                }
            }
        }

        return deletedCount
    }

    /// Toggle selection for a record
    public func toggleSelection(_ recordID: String) {
        if selectedRecordIDs.contains(recordID) {
            selectedRecordIDs.remove(recordID)
        } else {
            selectedRecordIDs.insert(recordID)
        }
    }

    /// Select all visible records
    public func selectAll() {
        selectedRecordIDs = Set(filteredRecords.map { $0.id })
    }

    /// Deselect all records
    public func deselectAll() {
        selectedRecordIDs.removeAll()
    }

    /// Navigate to next page
    public func nextPage() {
        let maxPage = max(0, totalPages - 1)
        currentPage = min(maxPage, currentPage + 1)
    }

    /// Navigate to previous page
    public func previousPage() {
        currentPage = max(0, currentPage - 1)
    }

    // MARK: - Private Methods

    private func filterRecords() {
        if searchText.isEmpty {
            filteredRecords = records
        } else {
            filteredRecords = records.filter { record in
                record.displayName.localizedCaseInsensitiveContains(searchText) ||
                record.subtitle.localizedCaseInsensitiveContains(searchText) ||
                record.id.localizedCaseInsensitiveContains(searchText)
            }
        }
        currentPage = 0
    }

    private func fetchStatsForRecordType(_ recordType: String) async throws -> (count: Int, totalSize: Int64, lastModified: Date?) {
        guard let database else { throw CloudKitUnavailableError() }
        var count = 0
        var totalSize: Int64 = 0
        var lastModified: Date? = nil
        var cursor: CKQueryOperation.Cursor? = nil

        // Use minimal desiredKeys for faster queries
        // Only request fileSize field - system fields (modificationDate) come automatically
        // Using empty array [] would be even faster but we lose size info
        let desiredKeys: [CKRecord.FieldKey] = ["fileSize"]

        repeat {
            let result: ([CKRecord.ID: Result<CKRecord, Error>], CKQueryOperation.Cursor?)

            if let existingCursor = cursor {
                let continuationResult = try await database.records(
                    continuingMatchFrom: existingCursor,
                    desiredKeys: desiredKeys,
                    resultsLimit: CKQueryOperation.maximumResults
                )
                result = (Dictionary(uniqueKeysWithValues: continuationResult.matchResults), continuationResult.queryCursor)
            } else {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                let matchResult = try await database.records(
                    matching: query,
                    desiredKeys: desiredKeys,
                    resultsLimit: CKQueryOperation.maximumResults
                )
                result = (Dictionary(uniqueKeysWithValues: matchResult.matchResults), matchResult.queryCursor)
            }

            for (_, fetchResult) in result.0 {
                if case .success(let record) = fetchResult {
                    count += 1

                    // Try multiple field names for size (different record types use different fields)
                    if let size = record["fileSize"] as? Int64 {
                        totalSize += size
                    }

                    // System field - always available
                    if let modDate = record.modificationDate {
                        if lastModified == nil || modDate > lastModified! {
                            lastModified = modDate
                        }
                    }
                }
            }

            cursor = result.1
        } while cursor != nil

        return (count, totalSize, lastModified)
    }

    /// Quick count-only fetch (faster, no size calculation)
    private func fetchCountForRecordType(_ recordType: String) async throws -> Int {
        guard let database else { throw CloudKitUnavailableError() }
        var count = 0
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            let result: ([CKRecord.ID: Result<CKRecord, Error>], CKQueryOperation.Cursor?)

            if let existingCursor = cursor {
                let continuationResult = try await database.records(
                    continuingMatchFrom: existingCursor,
                    desiredKeys: [],  // Empty = fastest, only get record IDs
                    resultsLimit: CKQueryOperation.maximumResults
                )
                result = (Dictionary(uniqueKeysWithValues: continuationResult.matchResults), continuationResult.queryCursor)
            } else {
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                let matchResult = try await database.records(
                    matching: query,
                    desiredKeys: [],  // Empty = fastest, only get record IDs
                    resultsLimit: CKQueryOperation.maximumResults
                )
                result = (Dictionary(uniqueKeysWithValues: matchResult.matchResults), matchResult.queryCursor)
            }

            // Just count successful fetches
            for (_, fetchResult) in result.0 {
                if case .success = fetchResult {
                    count += 1
                }
            }

            cursor = result.1
        } while cursor != nil

        return count
    }

    private func fetchRecords(ofType recordType: String, cursor: CKQueryOperation.Cursor?) async throws -> (records: [CloudKitRecordItem], cursor: CKQueryOperation.Cursor?) {
        guard let database else { throw CloudKitUnavailableError() }
        var items: [CloudKitRecordItem] = []

        let result: ([CKRecord.ID: Result<CKRecord, Error>], CKQueryOperation.Cursor?)

        if let existingCursor = cursor {
            let continuationResult = try await database.records(
                continuingMatchFrom: existingCursor,
                resultsLimit: 50
            )
            result = (Dictionary(uniqueKeysWithValues: continuationResult.matchResults), continuationResult.queryCursor)
        } else {
            // Note: We don't use sortDescriptors here because CloudKit system fields
            // like modificationDate may not be marked as sortable in the schema.
            // We'll sort locally after fetching instead.
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let matchResult = try await database.records(
                matching: query,
                resultsLimit: 50
            )
            result = (Dictionary(uniqueKeysWithValues: matchResult.matchResults), matchResult.queryCursor)
        }

        for (_, fetchResult) in result.0 {
            if case .success(let record) = fetchResult {
                let item = createRecordItem(from: record)
                items.append(item)
            }
        }

        // Sort locally by modification date (descending - newest first)
        items.sort { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }

        return (items, result.1)
    }

    private func createRecordItem(from record: CKRecord) -> CloudKitRecordItem {
        let recordType = record.recordType
        var displayName = record.recordID.recordName
        var subtitle = recordType
        var size: Int64? = nil
        var fields: [String: String] = [:]

        // Extract display name based on record type
        switch recordType {
        case CloudKitSchema.RecordType.rom.rawValue:
            if let filename = record[CloudKitSchema.ROMFields.originalFilename] as? String {
                displayName = filename
            }
            if let system = record[CloudKitSchema.ROMFields.systemIdentifier] as? String {
                subtitle = system
            }
            if let fileSize = record[CloudKitSchema.ROMFields.fileSize] as? Int64 {
                size = fileSize
            }
            if let md5 = record[CloudKitSchema.ROMFields.md5] as? String {
                fields["MD5"] = md5
            }

        case CloudKitSchema.RecordType.saveState.rawValue:
            if let filename = record[CloudKitSchema.SaveStateFields.filename] as? String {
                displayName = filename
            }
            if let gameID = record[CloudKitSchema.SaveStateFields.gameID] as? String {
                subtitle = "Game: \(gameID)"
            }
            if let fileSize = record[CloudKitSchema.SaveStateFields.fileSize] as? Int64 {
                size = fileSize
            }
            if let core = record[CloudKitSchema.SaveStateFields.coreIdentifier] as? String {
                fields["Core"] = core
            }

        case CloudKitSchema.RecordType.bios.rawValue:
            if let system = record[CloudKitSchema.BIOSAttributes.systemIdentifier] as? String {
                subtitle = system
            }
            if let md5 = record[CloudKitSchema.BIOSAttributes.md5Hash] as? String {
                fields["MD5"] = md5
                displayName = "BIOS (\(md5.prefix(8))...)"
            }
            if let desc = record[CloudKitSchema.BIOSAttributes.description] as? String {
                fields["Description"] = desc
                displayName = desc
            }

        case CloudKitSchema.RecordType.file.rawValue:
            if let filename = record["filename"] as? String {
                displayName = filename
            }
            if let directory = record["directory"] as? String {
                subtitle = directory
                fields["Directory"] = directory
            }
            if let fileSize = record["fileSize"] as? Int64 {
                size = fileSize
            }

        default:
            break
        }

        // Add common fields
        if let creationDate = record.creationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            fields["Created"] = formatter.string(from: creationDate)
        }

        if let modificationDate = record.modificationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            fields["Modified"] = formatter.string(from: modificationDate)
        }

        return CloudKitRecordItem(
            id: record.recordID.recordName,
            recordID: record.recordID,
            recordType: recordType,
            displayName: displayName,
            subtitle: subtitle,
            size: size,
            createdAt: record.creationDate,
            modifiedAt: record.modificationDate,
            fields: fields
        )
    }
}
