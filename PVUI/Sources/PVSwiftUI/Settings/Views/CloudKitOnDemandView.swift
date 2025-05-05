//
//  CloudKitOnDemandView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/23/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import CloudKit
import PVLibrary // Ensure PVLibrary is imported
import RealmSwift // Needed for Realm lookups
import PVLogging
import Foundation // For ByteCountFormatter

/// Represents a filter for CloudKit record types.
enum RecordTypeFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case roms = "ROMs"
    case saves = "Save States"
    case bios = "BIOS"
    // Add Artwork, Screenshots etc. if needed

    var id: String { self.rawValue }

    func recordTypeRawValues() -> [String] {
        switch self {
        // Use CloudKitSchema directly
        case .all: return CloudKitSchema.RecordType.allCases.map { $0.rawValue }
        case .roms: return [CloudKitSchema.RecordType.rom.rawValue]
        case .saves: return [CloudKitSchema.RecordType.saveState.rawValue]
        case .bios: return [CloudKitSchema.RecordType.bios.rawValue]
        // Add other cases
        }
    }

    // Use CloudKitSchema directly
    var recordType: CloudKitSchema.RecordType? {
        switch self {
        case .all: return nil // Represents all types
        case .roms: return .rom
        case .saves: return .saveState
        case .bios: return .bios
        }
    }
}

/// View model for a CloudKit record row
struct CloudKitRecordViewModel: Identifiable {
    let id = UUID() // Use UUID for Identifiable conformance
    let recordID: CKRecord.ID // CloudKit record name (CKRecord.ID.recordName)
    let recordType: String // Raw value from CloudKitSchema.RecordType
    let title: String
    let subtitle: String
    var isDownloaded: Bool
    var isDownloading: Bool = false

    // Computed property for sorting/filtering by CloudKitSchema.RecordType enum
    // Use CloudKitSchema directly
    var schemaRecordType: CloudKitSchema.RecordType? {
        CloudKitSchema.RecordType(rawValue: recordType)
    }
}

enum CloudKitSortOption: String, CaseIterable, Identifiable {
    case title = "Title"
    case date = "Date"
    case type = "Type"
    case size = "Size"

    var id: String { rawValue }
}


///ViewModel for the CloudKitOnDemandView. Handles fetching, merging, and actions.
@MainActor // Mark ViewModel as MainActor since it interacts with UI and Realm
final class CloudKitOnDemandViewModel: ObservableObject {
    @Published var records: [CloudKitRecordViewModel] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil // Store error messages as String
    @Published var selectedScope: CKDatabase.Scope = .private
    @Published var sortOrder: CloudKitSortOption = .title
    @Published var filterText: String = ""

    // Use CloudKitSyncAnalytics for observing status
    @ObservedObject var analytics = CloudKitSyncAnalytics.shared

    // Keep track of download/delete operations keyed by record name
    @Published var activeOperations: [String: Bool] = [:] // recordName -> true if active

    private var allFetchedRecords: [CloudKitRecordViewModel] = [] // Store unfiltered/unsorted records

    // MARK: - Data Fetching Logic

    /// Refreshes metadata by fetching from CloudKit and local Realm again.
    func refreshMetadata() async {
        await fetchAndMergeData()
    }

    /// Central function to fetch CloudKit records and local Realm data, then merge them.
    internal func fetchAndMergeData() async {
        isLoading = true
        error = nil
        var allViewModels: [CloudKitRecordViewModel] = []
        // Use CloudKitSchema directly
        let recordTypesToFetch = CloudKitSchema.RecordType.allCases // Fetch all defined types

        // Use a TaskGroup for potentially parallel fetches? For now, sequential.
        do {
            // Step 1: Fetch CloudKit Record details (metadata, not necessarily assets)
            // TODO: Refine query to fetch specific record types (ROM, SaveState, BIOS) based on CloudKitSchema
            // Example: Fetch all supported types
            var combinedResults: [CloudKitRecordViewModel] = []
            // Define the types we want to query for this view
            let queryableTypes: [CloudKitSchema.RecordType] = [.rom, .saveState, .bios, .screenshot, .artwork] // Add relevant types

            for recordType in queryableTypes {
                let typeQuery = CKQuery(recordType: recordType.rawValue, predicate: NSPredicate(value: true))
                // Consider adding sorting to the CKQuery itself if performance is an issue
                // typeQuery.sortDescriptors = [NSSortDescriptor(key: CKRecord.SystemFieldKey.modificationDate, ascending: false)]
                let database = CKContainer.default().privateCloudDatabase
                let (matchResults, _) = try await database.records(matching: typeQuery, resultsLimit: CKQueryOperation.maximumResults) // Handle pagination later if needed

                let fetchedCKRecords = matchResults.compactMap { try? $0.1.get() }

                // 2. Fetch Corresponding Local Records for Download Status (if applicable)
                let localViewModels = try await fetchLocalRecordsAsViewModels(for: recordType)
                let localRecordIDs = Set(localViewModels.map { $0.recordID.recordName }) // Fix: Store String names

                // 3. Create ViewModels from CloudKit Records, checking local status
                let cloudViewModels = fetchedCKRecords.compactMap { ckRecord -> CloudKitRecordViewModel? in
                    let isDownloaded = localRecordIDs.contains(ckRecord.recordID.recordName) // Now compares String with String
                    return createViewModel(from: ckRecord, isDownloaded: isDownloaded)
                }
                combinedResults.append(contentsOf: cloudViewModels)
            }

            allViewModels = combinedResults

        } catch let fetchError {
            ELOG("Error fetching CloudKit records: \(fetchError.localizedDescription)")
            // Handle specific CKError codes if needed
            self.error = "Error fetching records: \(fetchError.localizedDescription)" // Use generic Error string
        }

        isLoading = false

        // Update state on the main thread (already on @MainActor)
        self.records = allViewModels
    }

    /// Creates a basic ViewModel directly from a CKRecord. Assumes `isDownloaded = false`.
    private func createViewModel(from record: CKRecord, isDownloaded: Bool) -> CloudKitRecordViewModel? {
        // Use CloudKitSchema directly
        guard let recordType = CloudKitSchema.RecordType(rawValue: record.recordType) else {
            WLOG("Unknown CKRecord type encountered: \(record.recordType)")
            return nil
        }

        var title = "Unknown Record"
        var subtitle = "Type: \(recordType.rawValue)"
        var fileSize: Int64 = 0 // Store size as Int64
        var fileSizeString = "--"

        // Helper to attempt system name lookup using PVEmulatorConfiguration
        func getSystemName(fromIdentifier identifier: String?) -> String {
            guard let id = identifier else { return "Unknown System" }
            // Use PVEmulatorConfiguration static method
            let system: PVSystem? = PVEmulatorConfiguration.system(forIdentifier: id)
            return system?.shortName ?? id
        }

        // Helper to format bytes
        func formatBytes(_ bytes: Int64) -> String {
            ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }

        // Helper to get size from asset
        func getFileSize(from asset: CKAsset?) -> Int64 {
            guard let asset = asset, let fileURL = asset.fileURL else { return 0 }
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                return (attributes[.size] as? NSNumber)?.int64Value ?? 0
            } catch {
                ELOG("Error getting file size from CKAsset \(fileURL.lastPathComponent): \(error.localizedDescription)")
                return 0
            }
        }

        // Extract fields based on record type using CloudKitSchema
        switch recordType {
        case .rom:
            // Use CloudKitSchema directly
            title = record[CloudKitSchema.ROMFields.title] as? String ?? (record[CloudKitSchema.ROMFields.originalFilename] as? String ?? "Untitled ROM")
            let systemID = record[CloudKitSchema.ROMFields.systemIdentifier] as? String ?? "unknown"
            let system: PVSystem? = PVEmulatorConfiguration.system(forIdentifier: systemID)
            if let size = record[CloudKitSchema.ROMFields.fileSize] as? Int64, size > 0 {
                fileSize = size
            } else if let asset = record[CloudKitSchema.ROMFields.romFile] as? CKAsset {
                fileSize = getFileSize(from: asset)
            }
            fileSizeString = formatBytes(fileSize)
            subtitle = "\(system?.shortName ?? systemID) • \(fileSizeString)"

        case .saveState:
            // Use CloudKitSchema directly
            title = record[CloudKitSchema.SaveStateFields.filename] as? String ?? "Untitled Save"
            let gameIdentifier = record[CloudKitSchema.SaveStateFields.gameID] as? String // This is likely the PVGame md5
            let systemIdentifier = record[CloudKitSchema.SaveStateFields.systemIdentifier] as? String
            let systemName = getSystemName(fromIdentifier: systemIdentifier)
            let gameTitle = gameIdentifier // TODO: Need a way to look up game title from md5 if desired for subtitle

            if let size = record[CloudKitSchema.SaveStateFields.fileSize] as? Int64, size > 0 {
                fileSize = size
            } else if let asset = record[CloudKitSchema.SaveStateFields.fileData] as? CKAsset {
                fileSize = getFileSize(from: asset)
            }
            fileSizeString = formatBytes(fileSize)
            subtitle = "\(gameTitle ?? "Unknown Game") (\(systemName)) • \(fileSizeString)"

        case .bios:
            // Use correct BIOSAttributes fields
            title = record[CloudKitSchema.BIOSAttributes.description] as? String ?? record.recordID.recordName
            let systemIdentifier = record[CloudKitSchema.BIOSAttributes.systemIdentifier] as? String
            let systemName = getSystemName(fromIdentifier: systemIdentifier)
            // BIOS CKRecord likely uses SaveStateFields.fileData for the asset
            if let asset = record[CloudKitSchema.SaveStateFields.fileData] as? CKAsset {
                fileSize = getFileSize(from: asset)
            } else if let size = record[CloudKitSchema.SaveStateFields.fileSize] as? Int64, size > 0 {
                // Check SaveStateFields.fileSize as a fallback if asset size isn't available
                fileSize = size
            }
            fileSizeString = formatBytes(fileSize)
            subtitle = "\(systemName) • \(fileSizeString)"

        case .screenshot, .artwork:
            // Handle screenshot/artwork types similarly if needed, potentially using SaveStateFields
            title = record[CloudKitSchema.SaveStateFields.filename] as? String ?? "Untitled Media"
            let systemIdentifier = record[CloudKitSchema.SaveStateFields.systemIdentifier] as? String
            let systemName = getSystemName(fromIdentifier: systemIdentifier)
            if let size = record[CloudKitSchema.SaveStateFields.fileSize] as? Int64, size > 0 {
                fileSize = size
            } else if let asset = record[CloudKitSchema.SaveStateFields.fileData] as? CKAsset {
                fileSize = getFileSize(from: asset)
            }
            fileSizeString = formatBytes(fileSize)
            subtitle = "\(systemName) \(recordType.rawValue) • \(fileSizeString)"

            // Remove .file and .metadata cases as they are not displayed or handled here
        case .file, .metadata:
            WLOG("Skipping unsupported record type in view: \(recordType.rawValue)")
            return nil // Don't create view models for these types
        }

        return CloudKitRecordViewModel(
            recordID: record.recordID,
            recordType: recordType.rawValue,
            title: title,
            subtitle: subtitle,
            isDownloaded: isDownloaded, // Set based on parameter
            isDownloading: false // Assume false initially
        )
    }

    /// Fetches local Realm records corresponding to a given CloudKit record type and converts them to ViewModels.
    // Use CloudKitSchema directly
    private func fetchLocalRecordsAsViewModels(for recordType: CloudKitSchema.RecordType) async throws -> [CloudKitRecordViewModel] {
        var viewModels: [CloudKitRecordViewModel] = []
        let realm = try await Realm(actor: MainActor.shared) // Ensure Realm is accessed on the correct actor context

        // Helper to format bytes
        func formatBytes(_ bytes: Int64) -> String {
            ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        }
        // Helper to attempt system name lookup using PVEmulatorConfiguration
        func getSystemName(fromIdentifier identifier: String?) -> String {
            guard let id = identifier else { return "Unknown System" }
            // Use PVEmulatorConfiguration static method
            let system: PVSystem? = PVEmulatorConfiguration.system(forIdentifier: id)
            return system?.shortName ?? id
        }

        switch recordType {
        case .rom:
            // Use PVGame from PVRealm
            let games = realm.objects(PVGame.self).filter("cloudRecordID != nil")
            DLOG("Found \(games.count) local Games linked to CloudKit")
            viewModels = games.compactMap { game -> CloudKitRecordViewModel? in
                guard let recordName = game.cloudRecordID else { return nil }
                let recordID = CKRecord.ID(recordName: recordName) // Fix: Create CKRecord.ID from String
                let systemName = getSystemName(fromIdentifier: game.systemIdentifier)
                // Cast Int to Int64
                let fileSize = formatBytes(Int64(game.fileSize)) // PVGame stores fileSize directly

                return CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType.rawValue,
                    title: game.title,
                    subtitle: "\(systemName) • \(fileSize)",
                    isDownloaded: game.isDownloaded,
                    isDownloading: false // Default
                )
            }

        case .saveState:
            // Use PVSaveState from PVRealm
            let saveStates = realm.objects(PVSaveState.self).filter("cloudRecordID != nil")
            DLOG("Found \(saveStates.count) local SaveStates linked to CloudKit")
            viewModels = saveStates.compactMap { saveState -> CloudKitRecordViewModel? in
                // Ensure related objects exist
                guard let recordName = saveState.cloudRecordID,
                      let file = saveState.file,
                      let game = saveState.game else { return nil }
                let recordID = CKRecord.ID(recordName: recordName) // Fix: Create CKRecord.ID from String
                let systemName = getSystemName(fromIdentifier: game.systemIdentifier)
                // Cast UInt64 to Int64
                let fileSize = formatBytes(Int64(file.size)) // PVSaveState uses PVFile relationship
                let gameTitle = game.title

                return CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType.rawValue,
                    title: file.fileName, // Use filename from PVFile
                    subtitle: "\(gameTitle) (\(systemName)) • \(fileSize)",
                    isDownloaded: saveState.isDownloaded,
                    isDownloading: false // Default
                )
            }

        case .bios:
            // Use PVBIOS from PVRealm
            let bioses = realm.objects(PVBIOS.self).filter("cloudRecordID != nil")
            DLOG("Found \(bioses.count) local BIOSes linked to CloudKit")
            viewModels = bioses.compactMap { bios -> CloudKitRecordViewModel? in
                guard let recordName = bios.cloudRecordID else { return nil }
                let recordID = CKRecord.ID(recordName: recordName) // Fix: Create CKRecord.ID from String
                // Access system via relationship, ensuring PVSystem is correctly linked
                let systemIdentifier = bios.system?.identifier // Use optional chaining
                let systemName = getSystemName(fromIdentifier: systemIdentifier)
                // Cast Int to Int64
                let fileSize = formatBytes(Int64(bios.fileSize)) // PVBIOS stores fileSize directly

                return CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType.rawValue,
                    title: bios.descriptionText.isEmpty ? bios.expectedFilename : bios.descriptionText,
                    subtitle: "\(systemName) • \(fileSize)",
                    isDownloaded: bios.isDownloaded,
                    isDownloading: false // Default
                )
            }

            // Add cases for other synced types (Artwork, Screenshots, etc.) if needed
        case .screenshot, .artwork, .file, .metadata:
            DLOG("Local Realm fetch not implemented for type: \(recordType.rawValue)")
            break // No local mapping defined yet
        }

        DLOG("Mapped \(viewModels.count) local objects to ViewModels for type \(recordType.rawValue)")
        return viewModels
    }

    // MARK: - Filtering & Sorting (applied by the View)

    /// Filters records based on the selected filter and search text. To be called by the View.
    func filteredRecords(filter: RecordTypeFilter, searchText: String) -> [CloudKitRecordViewModel] {
        let typeFiltered = records.filter { vm in
            filter == .all || vm.schemaRecordType == filter.recordType
        }

        if searchText.isEmpty {
            return typeFiltered
        } else {
            let lowercasedSearch = searchText.lowercased()
            return typeFiltered.filter {
                vm in
                vm.recordID.recordName.localizedCaseInsensitiveContains(lowercasedSearch) ||
                vm.title.lowercased().contains(lowercasedSearch) ||
                vm.subtitle.lowercased().contains(lowercasedSearch)
            }
        }
    }

    // MARK: - Actions (Download / Delete)

    @MainActor
    func downloadRecord(_ record: CloudKitRecordViewModel) {
        guard !record.isDownloading, !record.isDownloaded else { return }

        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index].isDownloading = true
        }

        // Use Task for asynchronous download
        Task {
            do {
                let recordID = record.recordID
                let recordName = recordID.recordName
                guard let recordType = record.schemaRecordType else {
                    throw CloudSyncError.invalidData
                }
                let syncManager = CloudSyncManager.shared

                switch recordType {
                case .rom:
                    // Extract MD5 from record name (e.g., "rom_md5_HASH")
                    let prefix = CloudKitSchema.RecordType.rom.rawValue + "_md5_"
                    guard recordName.starts(with: prefix) else { throw CloudSyncError.invalidData }
                    let md5 = String(recordName.dropFirst(prefix.count))
                    try await syncManager.romsSyncer?.downloadGame(md5: md5) // Call correct method

                case .saveState, .bios, .screenshot, .artwork:
                    try await CloudSyncManager.shared.nonDatabaseSyncer?.downloadFile(for: recordID)

                default: // Other types like .file, .metadata not downloadable here
                    WLOG("Download not implemented for record type: \(recordType.rawValue)")
                    throw CloudSyncError.notImplemented
                }

                // Update UI on main thread upon completion
                await MainActor.run {
                    if let index = records.firstIndex(where: { $0.id == record.id }) {
                        records[index].isDownloading = false
                        records[index].isDownloaded = true // Assuming download implies success for now
                    }
                }
            } catch {
                ELOG("Error downloading record \(record.recordID.recordName): \(error.localizedDescription)")
                // Update UI on main thread upon error
                await MainActor.run {
                    if let index = records.firstIndex(where: { $0.id == record.id }) {
                        records[index].isDownloading = false
                        // Optionally show an error indicator
                    }
                    // Show error alert to user
                }
            }
        }
    }

    func deleteRecord(_ record: CloudKitRecordViewModel) async throws {
        let recordID = record.recordID
        let recordName = recordID.recordName

        guard activeOperations[recordName] != true else {
            DLOG("Operation already in progress for \(recordName)")
            return
        }
        activeOperations[recordName] = true
        self.error = nil

        // Update ViewModel state to show downloading status
        if let index = records.firstIndex(where: { $0.recordID.recordName == recordName }) {
            records[index].isDownloading = true
        }

        do {
            // Get record type from the ViewModel, not from CKRecord.ID
            guard let recordVM = records.first(where: { $0.recordID.recordName == recordName }),
                  let recordType = CloudKitSchema.RecordType(rawValue: recordVM.recordType) else {
                throw CloudSyncError.invalidData
            }

            let syncManager = CloudSyncManager.shared
            let realm = try await Realm(actor: MainActor.shared)
            let database = CKContainer.default().privateCloudDatabase // Get database for direct operation

            switch recordType {
            case .rom:
                DLOG("Attempting direct CloudKit delete for ROM: \(recordID.recordName)")
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
                try await database.add(operation)
                // Note: Local Realm object deletion might be needed separately depending on sync logic

            case .saveState:
                DLOG("Attempting direct CloudKit delete for Save State: \(recordID.recordName)")
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
                try await database.add(operation)
                // Note: Local Realm object deletion might be needed separately

            case .bios, .screenshot, .artwork:
                DLOG("Attempting direct CloudKit delete for NonDatabase: \(recordID.recordName)")
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
                try await database.add(operation)

            default:
                WLOG("Delete not implemented for record type: \(recordType.rawValue)")
                throw CloudSyncError.notImplemented
            }

            // Update state upon completion
            if let index = records.firstIndex(where: { $0.recordID.recordName == recordName }) {
                records[index].isDownloading = false
                records[index].isDownloaded = false
            }

        } catch let deleteError {
            ELOG("Error deleting record \(recordName) from CloudKit: \(deleteError.localizedDescription)")
            self.error = "Error deleting \(recordName): \(deleteError.localizedDescription)"
            if let index = records.firstIndex(where: { $0.recordID.recordName == recordName }) {
                records[index].isDownloading = false
            }
            throw deleteError
        }

        activeOperations[recordName] = false
    }

    // Function to determine RecordType based on CKRecord.ID prefix
    private func recordType(for recordID: CKRecord.ID) -> CloudKitSchema.RecordType? {
        let recordName = recordID.recordName
        // Fix: Use rawValue + separator
        if recordName.starts(with: CloudKitSchema.RecordType.rom.rawValue + "_") {
            return .rom
        } else if recordName.starts(with: CloudKitSchema.RecordType.saveState.rawValue + "_") {
            return .saveState
        } else if recordName.starts(with: CloudKitSchema.RecordType.bios.rawValue + "_") {
            return .bios
        } else if recordName.starts(with: CloudKitSchema.RecordType.screenshot.rawValue + "_") {
            return .screenshot
        } else if recordName.starts(with: CloudKitSchema.RecordType.artwork.rawValue + "_") {
            return .artwork
        } else {
            // Consider other types or return nil/unknown
            // This simple prefix check might be insufficient for complex IDs
            WLOG("Could not determine record type from prefix for: \(recordName)")
            return nil // Or a default/unknown type if applicable
        }
    }

    @MainActor
    func deleteRecords(recordIDs: Set<CKRecord.ID>) async throws {
        let database = CKContainer.default().privateCloudDatabase // Get database for direct operation
        for recordID in recordIDs {
            let recordName = recordID.recordName
            // Determine record type from the recordID itself
            guard let recordType = self.recordType(for: recordID) else { continue }
            switch recordType {
            case .rom:
                DLOG("Attempting direct CloudKit delete for ROM: \(recordID.recordName)")
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
                try await database.add(operation)

            case .saveState:
                DLOG("Attempting direct CloudKit delete for Save State: \(recordID.recordName)")
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
                try await database.add(operation)

            case .bios, .screenshot, .artwork:
                DLOG("Attempting direct CloudKit delete for NonDatabase: \(recordID.recordName)")
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
                try await database.add(operation)

            case .file:
                DLOG("Attempting direct CloudKit delete for File: \(recordID.recordName)")
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
                try await database.add(operation)

            case .metadata:
                DLOG("Attempting direct CloudKit delete for Metadata: \(recordID.recordName)")
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: [recordID])
                try await database.add(operation)
            }
        }
        // Refresh or update UI after deletion
    }

    // MARK: - Preview

    // MARK: - SwiftUI View Definition

    struct CloudKitOnDemandView: View {
        @StateObject private var viewModel = CloudKitOnDemandViewModel()
        @State private var showingFilterSheet = false
        @State private var selectedFilter: RecordTypeFilter = .all
        @State private var sortOrder: [KeyPathComparator<CloudKitRecordViewModel>] = [
            .init(\.title, order: .forward) // Default sort by title
        ]
        @State private var searchText = ""

        // Computed property for filtered and sorted records
        private var filteredAndSortedRecords: [CloudKitRecordViewModel] {
            viewModel.filteredRecords(filter: selectedFilter, searchText: searchText)
                .sorted(using: sortOrder)
        }

        // MARK: - Body
        var body: some View {
            Group { // Use Group to handle conditional content
                if viewModel.isLoading && viewModel.records.isEmpty { // Show loading only on initial load
                    ProgressView("Loading Records...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    ErrorView(error: error, viewModel: viewModel)

                } else if viewModel.records.isEmpty && !viewModel.isLoading { // Show empty state only when not loading
                    // Replacement for ContentUnavailableView (iOS 16 compatible)
                    VStack(spacing: 16) {
                        Image(systemName: "icloud.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Cloud Records Found")
                            .font(.headline)
                        Text("No records were found in CloudKit for the \(viewModel.selectedScope == .private ? "Private" : "Shared") database. Ensure sync is enabled and has completed at least once.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Refresh") {
                            Task { await viewModel.refreshMetadata() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    // Main content: List for iOS/tvOS
                    RecordListView(
                        records: filteredAndSortedRecords,
                        viewModel: viewModel,
                        onDeleteItems: deleteItems
                    )
                }
            }
            .navigationTitle("On-Demand Downloads")
            .searchable(text: $searchText, prompt: "Search Records")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Picker("Database Scope", selection: $viewModel.selectedScope) {
                        Text("Private").tag(CKDatabase.Scope.private)
                        Text("Shared").tag(CKDatabase.Scope.shared)
                        // Public scope might not be relevant here
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    ProgressView()
                        .opacity(viewModel.isLoading ? 1 : 0)

                    Picker("Sort By", selection: $viewModel.sortOrder) {
                        ForEach(CloudKitSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }

                    Button {
                        Task { await viewModel.refreshMetadata() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            // Initial data load
            .task(id: viewModel.selectedScope) { // Re-run task when scope changes
                await viewModel.refreshMetadata()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil), actions: {
                Button("OK") { viewModel.error = nil }
            }, message: {
                Text(viewModel.error ?? "An unknown error occurred.")
            })
        }

        // Helper for swipe-to-delete on iOS/tvOS List
        private func deleteItems(offsets: IndexSet) {
            let recordsToDelete = offsets.map { filteredAndSortedRecords[$0] }
            Task {
                for record in recordsToDelete {
                    do {
                        try await viewModel.deleteRecord(record)
                    } catch {
                        DLOG("Error deleting record: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Row View

    struct CloudKitRecordRow: View {
        // Use the immutable ViewModel passed in. State changes are handled by the parent @StateObject.
        let record: CloudKitRecordViewModel
        let viewModel: CloudKitOnDemandViewModel // Pass ViewModel for activeOperations access
        var onDownload: (CloudKitRecordViewModel) -> Void
        var onDelete: (CloudKitRecordViewModel) -> Void

        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(record.title).font(.headline)
                    Text(record.subtitle).font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()

                // Status Indicator
                let cloudRecordID = record.recordID
                let isDownloadable = CloudKitSchema.RecordType(rawValue: record.recordType) == .rom || CloudKitSchema.RecordType(rawValue: record.recordType) == .saveState

                if viewModel.activeOperations[record.recordID.recordName] == true || record.isDownloading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7) // Make spinner smaller
                } else if record.isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if isDownloadable { // Only show download button if downloadable type
                    // Download Button
                    Button {
                        onDownload(record)
                    } label: {
                        Image(systemName: "icloud.and.arrow.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.activeOperations[record.recordID.recordName] == true)
                } else {
                    // Optionally show a different icon or nothing for non-downloadable types
                    // For example, an empty space or a specific icon:
                    // Image(systemName: "icloud.slash").foregroundColor(.gray)
                    EmptyView() // Or just show nothing
                }
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button(role: .destructive) {
                    onDelete(record)
                } label: {
                    Label("Delete from CloudKit", systemImage: "trash")
                }
                .disabled(viewModel.activeOperations[record.recordID.recordName] == true)
            }
        }
    }

    // MARK: - Error View
    private struct ErrorView: View {
        let error: String
        let viewModel: CloudKitOnDemandViewModel

        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text("Error Loading Records")
                    .font(.headline)
                Text(error)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await viewModel.refreshMetadata() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Record List View
    private struct RecordListView: View {
        let records: [CloudKitRecordViewModel]
        let viewModel: CloudKitOnDemandViewModel
        let onDeleteItems: (IndexSet) -> Void

        var body: some View {
            List {
                ForEach(records) { record in
                    CloudKitRecordRow(record: record, viewModel: viewModel, onDownload: { recordToDownload in
                        Task { await viewModel.downloadRecord(recordToDownload) }
                    }, onDelete: { recordToDelete in
                        Task {
                            do {
                                try await viewModel.deleteRecord(recordToDelete)
                            } catch {
                                ELOG("Error deleting record: \(error)")
                            }
                        }
                    })
                }
                .onDelete(perform: onDeleteItems) // Swipe to delete
            }
            .listStyle(.plain) // Adjust list style as needed
            .refreshable { await viewModel.refreshMetadata() } // Pull-to-refresh for List
        }
    }
}
