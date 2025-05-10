//  UnifiedCloudSyncViewModel.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/27/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLibrary
import PVLogging
import Combine
import CloudKit
import Defaults
import PVSettings
import PVFileSystem
import Foundation
import RealmSwift

/// A record counts structure for CloudKit
public struct CloudKitRecordCounts: Equatable {
    var roms: Int
    var saveStates: Int
    var bios: Int
    var batteryStates: Int
    var screenshots: Int
    var deltaSkins: Int

    var total: Int {
        return roms + saveStates + bios + batteryStates + screenshots + deltaSkins
    }
}

/// A structure representing a sync difference between local and iCloud
public struct SyncDifference: Identifiable {
    public var id = UUID()
    var directory: String
    var filename: String
    var status: SyncStatus
    var localURL: URL?
    var iCloudURL: URL?
    var localSize: Int64?
    var iCloudSize: Int64?
    var localModified: Date?
    var iCloudModified: Date?

    enum SyncStatus {
        case localOnly
        case iCloudOnly
        case different
        case synced
    }
}

/// Represents daily sync statistics for a specific provider.
public struct DailyProviderSyncStats: Equatable {
    var uploads: Int = 0
    var downloads: Int = 0
    // Add other relevant stats if needed, e.g., deletes, conflicts

    static var zero: DailyProviderSyncStats {
        DailyProviderSyncStats(uploads: 0, downloads: 0)
    }
}

/// A unified view model for cloud sync settings
public class UnifiedCloudSyncViewModel: ObservableObject {
    // MARK: - Published Properties

    // General sync status
    @Published public var iCloudAvailable = false
    @Published public var isSyncing = false
    @Published public var syncStatus = "Checking sync status..."
    @Published public var lastSyncDate: Date?

    // File comparison
    @Published public var localFiles: [String: [URL]] = [:]
    @Published public var iCloudFiles: [String: [URL]] = [:]
    @Published public var syncDifferences: [String] = []
    @Published public var isLoading = true
    
    /// The total count of local files across all directories
    public var localFileCount: Int {
        return localFiles.values.reduce(0) { $0 + $1.count }
    }
    
    /// The total count of iCloud files across all directories
    public var iCloudFileCount: Int {
        return iCloudFiles.values.reduce(0) { $0 + $1.count }
    }

    // CloudKit record counts
    @Published public var cloudKitRecords = CloudKitRecordCounts(
        roms: 0, saveStates: 0, bios: 0, batteryStates: 0, screenshots: 0, deltaSkins: 0
    )
    @Published public var isLoadingCloudKitRecords = false

    // Sync progress
    @Published public var syncProgress: Double = 0.0
    @Published public var syncingFiles: Int = 0
    @Published public var totalFiles: Int? = nil
    @Published public var currentSyncFile: String?

    // Debug information
    @Published public var iCloudDiagnostics = ""
    @Published public var entitlementInfo = ""
    @Published public var infoPlistInfo = ""
    @Published public var containerInfo = ""
    @Published public var refreshInfo = ""

    // UI state
    @Published public var showDiagnostics = false
    @Published public var showCopiedToast = false
    @Published public var showSyncLog = false

    // Cloud Sync Log Data
    @Published public var cloudSyncLogEntries: [CloudSyncLogEntry] = []
    /// Processed chart data: [DayStartDate: [Provider: Stats]]
    @Published public var syncChartData: [Date: [CloudSyncLogEntry.SyncProviderType: DailyProviderSyncStats]] = [:]
    @Published public var isLoadingLogs = false

    // Pagination
    @Published public var currentPage = 0
    @Published public var itemsPerPage = 20

    /// Computed property for paginated differences
    public var paginatedDifferences: [String] {
        let startIndex = currentPage * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, syncDifferences.count)

        guard startIndex < syncDifferences.count else {
            return []
        }

        return Array(syncDifferences[startIndex..<endIndex])
    }

    /// Total number of pages
    public var totalPages: Int {
        max(1, (syncDifferences.count + itemsPerPage - 1) / itemsPerPage)
    }

    // MARK: - Private Properties

    // Directories to monitor
    private let monitoredDirectories = ["ROMs", "Save States", "BIOS", "DeltaSkins", "Battery States", "Screenshots", "RetroArch"]

    // Sync status for each domain
    private var syncingDomains: Set<String> = []

    // Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        setupObservers()
        checkiCloudAvailability()
        loadSyncInfo()
    }

    // MARK: - Public Methods

    /// Load all sync information
    public func loadSyncInfo() {
        checkiCloudAvailability()
        loadCloudKitRecordCounts()
        refreshFileComparison()
        loadLastSyncDate()
        loadDiagnosticInfo()
        loadCloudSyncLogs()
    }

    /// Start a full sync of all content
    public func startFullSync() {
        guard iCloudAvailable else { return }

        isSyncing = true
        syncStatus = "Starting full sync..."

        // Post notification to start sync
        NotificationCenter.default.post(name: .startFullSync, object: nil)

        // Update UI after a delay to allow sync to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.syncStatus = "Syncing all content..."
        }
    }

    /// Reset cloud sync data
    public func resetCloudSync() {
        // Show status
        syncStatus = "Resetting cloud sync..."
        
        // Post notification to reset sync
        NotificationCenter.default.post(name: Notification.Name("iCloudSyncReset"), object: nil)
        
        // Update UI after a delay to allow reset to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.syncStatus = "Cloud sync reset in progress..."
        }
    }
    
    /// Download ROMs from iCloud to local device
    public func downloadRoms() {
        // Show status
        syncStatus = "Starting ROM download..."
        
        // Update UI
        isLoading = true
        
        Task {
            do {
                // Scan for differences first
                await scanLocalFiles()
                await scanICloudFiles()
                await compareFiles()
                
                // Find all files that exist in iCloud but not locally
                let differences = await findFilesToDownload(fileType: .rom)
                
                // Log the download operation
                DLOG("Starting download of \(differences.count) ROMs from iCloud")
                CloudSyncLogManager.shared.logSyncOperation(
                    "Starting download of \(differences.count) ROMs from iCloud",
                    level: .info,
                    operation: .download,
                    provider: .iCloudDrive
                )
                
                // Post notification to download files
                NotificationCenter.default.post(
                    name: .iCloudSyncStarted,
                    object: nil,
                    userInfo: ["operation": "download_roms", "count": differences.count]
                )
                
                // Update UI
                await MainActor.run {
                    syncStatus = "Downloading \(differences.count) ROMs..."
                    isLoading = false
                }
            } catch {
                // Log error
                ELOG("Error starting ROM download: \(error.localizedDescription)")
                CloudSyncLogManager.shared.logSyncOperation(
                    "Error starting ROM download: \(error.localizedDescription)",
                    level: .error,
                    operation: .download,
                    provider: .iCloudDrive
                )
                
                // Update UI
                await MainActor.run {
                    syncStatus = "Error starting ROM download"
                    isLoading = false
                }
            }
        }
    }
    
    /// Download save states from iCloud to local device
    public func downloadSaveStates() {
        // Show status
        syncStatus = "Starting save state download..."
        
        // Update UI
        isLoading = true
        
        Task {
            do {
                // Scan for differences first
                await scanLocalFiles()
                await scanICloudFiles()
                await compareFiles()
                
                // Find all save states that exist in iCloud but not locally
                let differences = await findFilesToDownload(fileType: .saveState)
                
                // Log the download operation
                DLOG("Starting download of \(differences.count) save states from iCloud")
                CloudSyncLogManager.shared.logSyncOperation(
                    "Starting download of \(differences.count) save states from iCloud",
                    level: .info,
                    operation: .download,
                    provider: .iCloudDrive
                )
                
                // Post notification to download files
                NotificationCenter.default.post(
                    name: .iCloudSyncStarted,
                    object: nil,
                    userInfo: ["operation": "download_save_states", "count": differences.count]
                )
                
                // Update UI
                await MainActor.run {
                    syncStatus = "Downloading \(differences.count) save states..."
                    isLoading = false
                }
            } catch {
                // Log error
                ELOG("Error starting save state download: \(error.localizedDescription)")
                CloudSyncLogManager.shared.logSyncOperation(
                    "Error starting save state download: \(error.localizedDescription)",
                    level: .error,
                    operation: .download,
                    provider: .iCloudDrive
                )
                
                // Update UI
                await MainActor.run {
                    syncStatus = "Error starting save state download"
                    isLoading = false
                }
            }
        }
    }
    
    /// Download BIOS files from iCloud to local device
    public func downloadBios() {
        // Show status
        syncStatus = "Starting BIOS download..."
        
        // Update UI
        isLoading = true
        
        Task {
            do {
                // Scan for differences first
                await scanLocalFiles()
                await scanICloudFiles()
                await compareFiles()
                
                // Find all BIOS files that exist in iCloud but not locally
                let differences = await findFilesToDownload(fileType: .bios)
                
                // Log the download operation
                DLOG("Starting download of \(differences.count) BIOS files from iCloud")
                CloudSyncLogManager.shared.logSyncOperation(
                    "Starting download of \(differences.count) BIOS files from iCloud",
                    level: .info,
                    operation: .download,
                    provider: .iCloudDrive
                )
                
                // Post notification to download files
                NotificationCenter.default.post(
                    name: .iCloudSyncStarted,
                    object: nil,
                    userInfo: ["operation": "download_bios", "count": differences.count]
                )
                
                // Update UI
                await MainActor.run {
                    syncStatus = "Downloading \(differences.count) BIOS files..."
                    isLoading = false
                }
            } catch {
                // Log error
                ELOG("Error starting BIOS download: \(error.localizedDescription)")
                CloudSyncLogManager.shared.logSyncOperation(
                    "Error starting BIOS download: \(error.localizedDescription)",
                    level: .error,
                    operation: .download,
                    provider: .iCloudDrive
                )
                
                // Update UI
                await MainActor.run {
                    syncStatus = "Error starting BIOS download"
                    isLoading = false
                }
            }
        }
    }
    
    /// File types for sync operations
    private enum SyncFileType {
        case rom
        case saveState
        case bios
        case any
        
        func matches(path: String) -> Bool {
            switch self {
            case .rom:
                // Check for common ROM extensions
                let romExtensions = [".smc", ".sfc", ".nes", ".gba", ".gbc", ".gb", ".md", ".gen", ".sms", ".gg", ".pce", ".cue", ".iso", ".z64", ".v64", ".n64"]
                return romExtensions.contains { path.lowercased().hasSuffix($0) }
            case .saveState:
                // Check for save state extensions
                return path.lowercased().hasSuffix(".svs") || path.contains("/Save States/")
            case .bios:
                // Check for BIOS files
                let biosExtensions = [".bin", ".rom", ".bios"]
                let biosDirectories = ["/BIOS/", "/System/"]
                
                // Check if file is in a BIOS directory
                let isInBiosDirectory = biosDirectories.contains { path.contains($0) }
                
                // Check if file has a BIOS extension
                let hasBiosExtension = biosExtensions.contains { path.lowercased().hasSuffix($0) }
                
                // Check for common BIOS filenames
                let commonBiosFiles = ["scph", "bios", "firmware", "bootrom", "gba_bios"]
                let containsCommonBiosName = commonBiosFiles.contains { path.lowercased().contains($0) }
                
                return isInBiosDirectory || (hasBiosExtension && containsCommonBiosName)
            case .any:
                return true
            }
        }
    }
    
    /// Find files that need to be downloaded from iCloud
    private func findFilesToDownload(fileType: SyncFileType = .any) async -> [SyncDifference] {
        var filesToDownload: [SyncDifference] = []
        
        // Find files that exist in iCloud but not locally or are newer in iCloud
        for (directory, urls) in localFiles {
            for url in urls where fileType.matches(path: url.path) {
                // Get the relative path for comparison
                let relativePath = getRelativePath(for: url)
                
                // Find matching iCloud file
                if let iCloudUrls = iCloudFiles[directory],
                   let iCloudUrl = iCloudUrls.first(where: { getRelativePath(for: $0) == relativePath }) {
                    
                    // Get modification dates
                    let localModified = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    let iCloudModified = try? iCloudUrl.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    
                    // Check if iCloud version is newer
                    if let localModified = localModified,
                       let iCloudModified = iCloudModified,
                       iCloudModified > localModified {
                        // iCloud version is newer
                        filesToDownload.append(SyncDifference(
                            directory: directory,
                            filename: url.lastPathComponent,
                            status: .different,
                            localURL: url,
                            iCloudURL: iCloudUrl,
                            localModified: localModified,
                            iCloudModified: iCloudModified
                        ))
                    }
                }
            }
        }
        
        // Find files that only exist in iCloud
        for (directory, iCloudUrls) in iCloudFiles {
            for iCloudUrl in iCloudUrls where fileType.matches(path: iCloudUrl.path) {
                // Get the relative path for comparison
                let relativePath = getRelativePath(for: iCloudUrl)
                
                // Check if file exists locally
                let existsLocally = localFiles[directory]?.contains(where: { 
                    getRelativePath(for: $0) == relativePath 
                }) ?? false
                
                if !existsLocally {
                    // File only exists in iCloud
                    filesToDownload.append(SyncDifference(
                        directory: directory,
                        filename: iCloudUrl.lastPathComponent,
                        status: .iCloudOnly,
                        localURL: nil,
                        iCloudURL: iCloudUrl,
                        iCloudModified: try? iCloudUrl.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                    ))
                }
            }
        }
        
        return filesToDownload
    }
    
    /// Helper method to get the relative path for a URL
    private func getRelativePath(for url: URL) -> String {
        // Extract the relative path from the URL
        // This will be used for comparing local and iCloud files
        let components = url.pathComponents
        
        // Find the last common directory component (e.g., "ROMs", "Save States", "BIOS")
        let commonDirs = ["ROMs", "Save States", "BIOS", "System"]
        if let lastCommonIndex = components.lastIndex(where: { commonDirs.contains($0) }) {
            // Get the path components after the common directory
            let relativePath = components[(lastCommonIndex + 1)...].joined(separator: "/")
            return relativePath
        }
        
        // Fallback to just the filename if no common directory is found
        return url.lastPathComponent
    }

    // MARK: - Private Methods

    /// Set up observers for notifications
    private func setupObservers() {
        // Observe sync status changes
        NotificationCenter.default.publisher(for: .iCloudSyncStarted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isSyncing = true
                self?.syncStatus = "Syncing..."
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .iCloudSyncCompleted)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isSyncing = false
                self?.syncStatus = "Sync completed"
                self?.loadSyncInfo()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .iCloudSyncFailed)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                self?.isSyncing = false
                if let error = notification.userInfo?["error"] as? Error {
                    self?.syncStatus = "Sync failed: \(error.localizedDescription)"
                } else {
                    self?.syncStatus = "Sync failed"
                }
            }
            .store(in: &cancellables)

        // Observe file recovery progress
        NotificationCenter.default.publisher(for: .iCloudFileRecoveryProgress)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let userInfo = notification.userInfo else { return }

                if let currentFile = userInfo["currentFile"] as? String {
                    self?.currentSyncFile = currentFile
                }

                if let progress = userInfo["progress"] as? Float {
                    self?.syncProgress = Double(progress)
                }

                if let totalFiles = userInfo["totalFiles"] as? Int {
                    self?.totalFiles = totalFiles
                }

                if let completedFiles = userInfo["completedFiles"] as? Int {
                    self?.syncingFiles = completedFiles
                }
            }
            .store(in: &cancellables)
    }

    /// Check if iCloud is available
    private func checkiCloudAvailability() {
        // Check if iCloud is available
        let fileManager = FileManager.default
        if let ubiquityContainer = fileManager.url(forUbiquityContainerIdentifier: nil) {
            iCloudAvailable = true
            DLOG("iCloud is available at: \(ubiquityContainer.path)")
        } else {
            iCloudAvailable = false
            DLOG("iCloud is not available")
        }

        // Update sync status based on availability
        if iCloudAvailable {
            syncStatus = "iCloud is available"
        } else {
            syncStatus = "iCloud is not available"
        }
    }

    /// Load CloudKit record counts
    private func loadCloudKitRecordCounts() {
        isLoadingCloudKitRecords = true

        Task {
            // Create CloudKit container
            let container = CKContainer.default()
            let privateDB = container.privateCloudDatabase

            // Get ROM records
            let romQuery = CKQuery(recordType: CloudKitSchema.RecordType.rom.rawValue, predicate: NSPredicate(value: true))
            let saveStateQuery = CKQuery(recordType: CloudKitSchema.RecordType.saveState.rawValue, predicate: NSPredicate(value: true))
            let biosQuery = CKQuery(recordType: CloudKitSchema.RecordType.bios.rawValue, predicate: NSPredicate(value: true))
            let fileQuery = CKQuery(recordType: CloudKitSchema.RecordType.file.rawValue, predicate: NSPredicate(value: true))

            do {
                // Get ROM records
                let (romRecords, _) = try await privateDB.records(matching: romQuery, resultsLimit: 1000)
                let romCount = romRecords.count

                // Get save state records
                let (saveStateRecords, _) = try await privateDB.records(matching: saveStateQuery, resultsLimit: 1000)
                let saveStateCount = saveStateRecords.count

                // Get BIOS records
                let (biosRecords, _) = try await privateDB.records(matching: biosQuery, resultsLimit: 1000)
                let biosCount = biosRecords.count

                // Get file records and categorize them
                let (fileRecords, _) = try await privateDB.records(matching: fileQuery, resultsLimit: 1000)

                var batteryStatesCount = 0
                var screenshotsCount = 0
                var deltaSkinsCount = 0

                // Process file records to categorize them
                for (_, result) in fileRecords {
                    if case .success(let record) = result, let directory = record["directory"] as? String {
                        switch directory {
                        case "Battery States":
                            batteryStatesCount += 1
                        case "Screenshots":
                            screenshotsCount += 1
                        case "DeltaSkins":
                            deltaSkinsCount += 1
                        default:
                            break
                        }
                    }
                }

                // Update record counts on main thread
                await MainActor.run {
                    self.cloudKitRecords = CloudKitRecordCounts(
                        roms: romCount,
                        saveStates: saveStateCount,
                        bios: biosCount,
                        batteryStates: batteryStatesCount,
                        screenshots: screenshotsCount,
                        deltaSkins: deltaSkinsCount
                    )
                    self.isLoadingCloudKitRecords = false
                }

            } catch {
                ELOG("Error loading CloudKit record counts: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingCloudKitRecords = false
                }
            }
        }
    }

    /// Load the last sync date
    private func loadLastSyncDate() {
        // Get last sync date from UserDefaults
        if let lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date {
            self.lastSyncDate = lastSyncDate
        }
    }

    /// Refresh file comparison between local and iCloud
    private func refreshFileComparison() {
        isLoading = true
        refreshInfo = "Starting refresh at \(Date().formatted())"

        // Clear previous data
        localFiles = [:]
        iCloudFiles = [:]
        syncDifferences = []

        // Check if iCloud sync is enabled and available
        guard Defaults[.iCloudSync] && iCloudAvailable else {
            DLOG("Skipping iCloud scan - iCloud sync is disabled or unavailable")
            DLOG("iCloudSyncMode=\(Defaults[.iCloudSyncMode].description), iCloudAvailable=\(iCloudAvailable)")
            isLoading = false
            return
        }

        // Start scanning files
        Task {
            await scanLocalFiles()
            await scanICloudFiles()
            await compareFiles()

            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    /// Scan local files in monitored directories
    private func scanLocalFiles() async {
        let fileManager = FileManager.default
        var localFileResults: [String: [URL]] = [:]

        for directory in monitoredDirectories {
            let directoryPath = URL.documentsPath.appendingPathComponent(directory)

            DLOG("Scanning local directory: \(directoryPath.path)")

            do {
                // Create directory if it doesn't exist
                if !fileManager.fileExists(atPath: directoryPath.path) {
                    try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
                    DLOG("Created local directory: \(directoryPath.path)")
                }

                // Get files in directory
                let files = try fileManager.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
                DLOG("Found \(files.count) files in local directory: \(directory)")

                // Store files
                localFileResults[directory] = files

                // Log sample files for debugging
                if !files.isEmpty {
                    let sampleCount = min(3, files.count)
                    let sampleFiles = Array(files.prefix(sampleCount))
                    var fileDetails = ""

                    for file in sampleFiles {
                        fileDetails += "\n- \(file.lastPathComponent)"
                    }

                    let moreFilesMessage = files.count > sampleCount ? "\n- ... and \(files.count - sampleCount) more" : ""
                    DLOG("Sample local files: \(fileDetails)\(moreFilesMessage)")
                }
            } catch {
                ELOG("Error scanning local directory: \(error.localizedDescription)")

                if let nsError = error as NSError? {
                    DLOG("Error details: domain=\(nsError.domain), code=\(nsError.code)")
                }
            }
        }

        await MainActor.run {
            self.localFiles = localFileResults
        }
    }

    /// Scan iCloud files in monitored directories
    private func scanICloudFiles() async {
        let fileManager = FileManager.default
        var iCloudFileResults: [String: [URL]] = [:]

        // Get iCloud container URL
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else {
            ELOG("iCloud container directory is nil")
            return
        }

        for directory in monitoredDirectories {
            let directoryPath = containerURL.appendingPathComponent(directory)

            DLOG("Scanning iCloud directory: \(directoryPath.path)")

            do {
                // Create directory if it doesn't exist
                if !fileManager.fileExists(atPath: directoryPath.path) {
                    try fileManager.createDirectory(at: directoryPath, withIntermediateDirectories: true, attributes: nil)
                    DLOG("Created iCloud directory: \(directoryPath.path)")
                }

                // Get files in directory
                let files = try fileManager.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
                DLOG("Found \(files.count) files in iCloud directory: \(directory)")

                // Store files
                iCloudFileResults[directory] = files

                // Log sample files for debugging
                if !files.isEmpty {
                    let sampleCount = min(3, files.count)
                    let sampleFiles = Array(files.prefix(sampleCount))
                    var fileDetails = ""

                    for file in sampleFiles {
                        fileDetails += "\n- \(file.lastPathComponent)"
                    }

                    let moreFilesMessage = files.count > sampleCount ? "\n- ... and \(files.count - sampleCount) more" : ""
                    DLOG("Sample iCloud files: \(fileDetails)\(moreFilesMessage)")
                }
            } catch {
                ELOG("Error scanning iCloud directory: \(error.localizedDescription)")

                if let nsError = error as NSError? {
                    DLOG("Error details: domain=\(nsError.domain), code=\(nsError.code)")
                }
            }
        }

        await MainActor.run {
            self.iCloudFiles = iCloudFileResults
        }
    }

    /// Go to the next page of sync differences
    public func nextPage() {
        let maxPage = max(0, (syncDifferences.count - 1) / itemsPerPage)
        currentPage = min(maxPage, currentPage + 1)
    }

    /// Go to the previous page of sync differences
    public func previousPage() {
        currentPage = max(0, currentPage - 1)
    }

    /// Reset pagination to the first page
    public func resetPagination() {
        currentPage = 0
    }

    /// Compare local and iCloud files to find differences
    internal func compareFiles() async {
        var differences: [SyncDifference] = []
        let fileManager = FileManager.default

        for directory in monitoredDirectories {
            let localFilesInDir = localFiles[directory] ?? []
            let iCloudFilesInDir = iCloudFiles[directory] ?? []

            // Create maps of filename to URL for easier comparison
            var localFileMap: [String: URL] = [:]
            var iCloudFileMap: [String: URL] = [:]

            for url in localFilesInDir {
                localFileMap[url.lastPathComponent] = url
            }

            for url in iCloudFilesInDir {
                iCloudFileMap[url.lastPathComponent] = url
            }

            // Find files that are only in local storage
            for (filename, localURL) in localFileMap {
                if iCloudFileMap[filename] == nil {
                    // File exists only locally
                    var localSize: Int64?
                    var localModified: Date?

                    do {
                        let attributes = try fileManager.attributesOfItem(atPath: localURL.path)
                        localSize = attributes[.size] as? Int64
                        localModified = attributes[.modificationDate] as? Date
                    } catch {
                        ELOG("Error getting attributes for local file: \(error.localizedDescription)")
                    }

                    let difference = SyncDifference(
                        directory: directory,
                        filename: filename,
                        status: .localOnly,
                        localURL: localURL,
                        iCloudURL: nil,
                        localSize: localSize,
                        iCloudSize: nil,
                        localModified: localModified,
                        iCloudModified: nil
                    )

                    differences.append(difference)
                }
            }

            // Find files that are only in iCloud
            for (filename, iCloudURL) in iCloudFileMap {
                if localFileMap[filename] == nil {
                    // File exists only in iCloud
                    var iCloudSize: Int64?
                    var iCloudModified: Date?

                    do {
                        let attributes = try fileManager.attributesOfItem(atPath: iCloudURL.path)
                        iCloudSize = attributes[.size] as? Int64
                        iCloudModified = attributes[.modificationDate] as? Date
                    } catch {
                        ELOG("Error getting attributes for iCloud file: \(error.localizedDescription)")
                    }

                    let difference = SyncDifference(
                        directory: directory,
                        filename: filename,
                        status: .iCloudOnly,
                        localURL: nil,
                        iCloudURL: iCloudURL,
                        localSize: nil,
                        iCloudSize: iCloudSize,
                        localModified: nil,
                        iCloudModified: iCloudModified
                    )

                    differences.append(difference)
                }
            }

            // Compare files that exist in both locations
            for (filename, localURL) in localFileMap {
                if let iCloudURL = iCloudFileMap[filename] {
                    var localSize: Int64?
                    var iCloudSize: Int64?
                    var localModified: Date?
                    var iCloudModified: Date?
                    var status: SyncDifference.SyncStatus = .synced

                    do {
                        let localAttributes = try fileManager.attributesOfItem(atPath: localURL.path)
                        localSize = localAttributes[.size] as? Int64
                        localModified = localAttributes[.modificationDate] as? Date

                        let iCloudAttributes = try fileManager.attributesOfItem(atPath: iCloudURL.path)
                        iCloudSize = iCloudAttributes[.size] as? Int64
                        iCloudModified = iCloudAttributes[.modificationDate] as? Date

                        // Compare sizes to determine if files are different
                        if let localSize = localSize, let iCloudSize = iCloudSize, localSize != iCloudSize {
                            status = .different
                        }

                        // If sizes are the same but modification dates are different, mark as different
                        if status == .synced, let localModified = localModified, let iCloudModified = iCloudModified,
                           abs(localModified.timeIntervalSince(iCloudModified)) > 60 { // Allow 1 minute difference
                            status = .different
                        }
                    } catch {
                        ELOG("Error comparing files: \(error.localizedDescription)")
                        status = .different // Mark as different if we can't compare
                    }

                    // Only add to differences if files are not synced
                    if status != .synced {
                        let difference = SyncDifference(
                            directory: directory,
                            filename: filename,
                            status: status,
                            localURL: localURL,
                            iCloudURL: iCloudURL,
                            localSize: localSize,
                            iCloudSize: iCloudSize,
                            localModified: localModified,
                            iCloudModified: iCloudModified
                        )

                        differences.append(difference)
                    }
                }
            }
        }

        // Sort differences by directory and filename
        differences.sort { lhs, rhs in
            if lhs.directory != rhs.directory {
                return lhs.directory < rhs.directory
            } else {
                return lhs.filename < rhs.filename
            }
        }

        // Convert SyncDifference objects to formatted strings
        let formattedDifferences = differences.map { formatMessage(for: $0) }
        
        await MainActor.run {
            self.syncDifferences = formattedDifferences
        }
    }

    private func formatMessage(for difference: SyncDifference) -> String {
        var message = "\(difference.filename) ("
        
        switch difference.status {
        case .localOnly:
            message = message + "Local Only"
        case .iCloudOnly:
            message = message + "iCloud Only"
        case .different:
            message = message + "Different"
        case .synced:
            message = message + "Synced"
        }
        
        message = message + ")\n"
        
        return message
    }

    /// Load diagnostic information
    internal func loadDiagnosticInfo() {
        // Load iCloud container diagnostics
        Task {
            await loadiCloudContainerDiagnostics()
            await loadEntitlementInfo()
            await loadInfoPlistInfo()
            await loadContainerInfo()
        }
    }

    /// Load iCloud container diagnostics
    private func loadiCloudContainerDiagnostics() async {        let fileManager = FileManager.default
        var diagnostics = "iCloud Container Diagnostics:\n"

        // Check if iCloud is available
        if let ubiquityContainer = fileManager.url(forUbiquityContainerIdentifier: nil) {
            diagnostics += "iCloud is available at: \(ubiquityContainer.path)\n"

            // Check if Documents directory exists
            let documentsURL = ubiquityContainer.appendingPathComponent("Documents")
            if fileManager.fileExists(atPath: documentsURL.path) {
                diagnostics += "Documents directory exists at: \(documentsURL.path)\n"

                // Check for monitored directories
                for directory in monitoredDirectories {
                    let directoryURL = documentsURL.appendingPathComponent(directory)
                    if fileManager.fileExists(atPath: directoryURL.path) {
                        diagnostics += "Directory '\(directory)' exists\n"
                    } else {
                        diagnostics += "Directory '\(directory)' does not exist\n"
                    }
                }
            } else {
                diagnostics += "Documents directory does not exist at: \(documentsURL.path)\n"
            }
        } else {
            diagnostics += "iCloud is not available\n"

            // Check for common issues
            var message = "Possible issues:\n"
            message += "- iCloud may not be enabled on this device\n"
            message += "- The app may not have iCloud entitlements\n"
            message += "- The user may not be signed in to iCloud\n"
            message += "- There may be network connectivity issues\n"

            diagnostics += message
            DLOG(message)
        }

        await MainActor.run {
            self.iCloudDiagnostics = diagnostics
        }
    }

    /// Load entitlement information
    private func loadEntitlementInfo() async {
        var entitlementInfo = "iCloud Entitlement Information:\n"

        // Check for iCloud entitlements in the app bundle
        if let entitlementsPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
            entitlementInfo += "Found embedded.mobileprovision at: \(entitlementsPath)\n"

            // We can't easily parse the binary plist, so just note its existence
            entitlementInfo += "The app has a provisioning profile, which should contain iCloud entitlements\n"
        } else {
            entitlementInfo += "No embedded.mobileprovision found in the app bundle\n"
        }

        // Check for iCloud container identifiers
        if let containerIdentifiers = Bundle.main.object(forInfoDictionaryKey: "NSUbiquitousContainerIdentifiers") as? [String] {
            entitlementInfo += "iCloud container identifiers:\n"
            for identifier in containerIdentifiers {
                entitlementInfo += "- \(identifier)\n"
            }
        } else {
            entitlementInfo += "No iCloud container identifiers found in Info.plist\n"
        }

        DLOG(entitlementInfo)

        await MainActor.run {
            self.entitlementInfo = entitlementInfo
        }
    }

    /// Load Info.plist information
    private func loadInfoPlistInfo() async {
        var infoPlistInfo = "Info.plist iCloud Configuration:\n"

        // Check for iCloud-related keys in Info.plist
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            infoPlistInfo += "Bundle identifier: \(bundleIdentifier)\n"
        }

        if let containerIdentifiers = Bundle.main.object(forInfoDictionaryKey: "NSUbiquitousContainerIdentifiers") as? [String] {
            infoPlistInfo += "NSUbiquitousContainerIdentifiers:\n"
            for identifier in containerIdentifiers {
                infoPlistInfo += "- \(identifier)\n"
            }
        } else {
            infoPlistInfo += "NSUbiquitousContainerIdentifiers not found\n"
        }

        if let ubiquitousContainerName = Bundle.main.object(forInfoDictionaryKey: "NSUbiquitousContainerName") as? String {
            infoPlistInfo += "NSUbiquitousContainerName: \(ubiquitousContainerName)\n"
        } else {
            infoPlistInfo += "NSUbiquitousContainerName not found\n"
        }

        DLOG(infoPlistInfo)

        await MainActor.run {
            self.infoPlistInfo = infoPlistInfo
        }
    }

    /// Load CloudKit container information
    private func loadContainerInfo() async {
        var containerInfo = "CloudKit Container Information:\n"

        // Get CloudKit container configuration
        let container = CKContainer.default()

        // Check if the user is signed in to iCloud
        containerInfo += "iCloud Status:\n"
        containerInfo += "  - User is signed in: \(iCloudAvailable ? "Yes" : "No")\n"

        // Check if the user has granted permission for CloudKit
        containerInfo += "\nPermissions:\n"
        do {
            let status = try await container.accountStatus()
            containerInfo += "  - Account Status: \(String(describing: status))\n"
            
            if #available(iOS 16.0, *) {
                let status = try await container.requestApplicationPermission(.userDiscoverability)
                containerInfo += "  - User Discoverability: \(status == .granted ? "Granted" : "Denied")\n"
            } else {
                containerInfo += "  - User Discoverability: Not available on this iOS version\n"
            }
        } catch {
            containerInfo += "  - Permission Check Error: \(error.localizedDescription)\n"
        }

        await MainActor.run {
            self.containerInfo = containerInfo
        }
    }

    /// Convert CKAccountStatus to string
    private func accountStatusString(_ status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .couldNotDetermine:
            return "Could not determine"
        case .restricted:
            return "Restricted"
        case .noAccount:
            return "No account"
        @unknown default:
            return "Unknown"
        }
    }

    /// Convert CKApplicationPermissionStatus to string
    private func permissionStatusString(_ status: CKContainer.ApplicationPermissionStatus) -> String {
        switch status {
        case .initialState:
            return "Initial state"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        @unknown default:
            return "Unknown"
        }
    }

    // MARK: - Private Log Handling Methods

    /// Fetches the latest log entries from the log manager.
    private func loadCloudSyncLogs() {
        isLoadingLogs = true
        Task {
            // Access the shared log manager instance
            let logManager = CloudSyncLogManager.shared
            let entries = logManager.getRecentLogEntriesSync()

            await MainActor.run {
                self.cloudSyncLogEntries = entries
                self.processLogEntriesForChart()
                self.isLoadingLogs = false
            }
        }
    }

    /// Processes the raw log entries into data suitable for charts.
    private func processLogEntriesForChart() {
        var dailyStats: [Date: [CloudSyncLogEntry.SyncProviderType: DailyProviderSyncStats]] = [:]
        let calendar = Calendar.current

        for entry in cloudSyncLogEntries {
            // Provider and operation are non-optional, so direct access is safe.
            let provider = entry.provider
            let operation = entry.operation

            // Get the start of the day for the entry's timestamp
            let day = calendar.startOfDay(for: entry.timestamp)

            // Initialize dictionary for the day if needed
            if dailyStats[day] == nil {
                dailyStats[day] = [:]
            }

            // Initialize stats for the provider on that day if needed
            if dailyStats[day]![provider] == nil {
                dailyStats[day]![provider] = DailyProviderSyncStats.zero
            }

            // Increment counts based on operation type
            switch operation {
            case .upload:
                dailyStats[day]![provider]?.uploads += 1
            case .download:
                dailyStats[day]![provider]?.downloads += 1
            // Add cases for other operations if needed (e.g., .delete, .conflict)
            default:
                // Handle other cases or ignore
                break
            }
        }

        // Update the published property on the main thread
        DispatchQueue.main.async {
             // Sort by date for consistent chart presentation (optional but recommended)
             let sortedData = dailyStats.sorted { $0.key < $1.key }
             self.syncChartData = Dictionary(uniqueKeysWithValues: sortedData)
        }
    }
}
