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
import PVUIBase // RetroTheme, RetroScanlineOverlay
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
    let modificationDate: Date // For date sorting
    let fileSize: Int64 // For size sorting
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

    // Use CloudKitSyncAnalytics for observing status
    @ObservedObject var analytics = CloudKitSyncAnalytics.shared

    // Keep track of download/delete operations keyed by record name
    @Published var activeOperations: [String: Bool] = [:] // recordName -> true if active


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
            let queryableTypes: [CloudKitSchema.RecordType] = [.rom, .saveState, .bios] // Metadata type not deployed to CloudKit yet

            for recordType in queryableTypes {
                let typeQuery = CKQuery(recordType: recordType.rawValue, predicate: NSPredicate(value: true))
                // Consider adding sorting to the CKQuery itself if performance is an issue
                // typeQuery.sortDescriptors = [NSSortDescriptor(key: CKRecord.SystemFieldKey.modificationDate, ascending: false)]
                let database = CKContainer.default().privateCloudDatabase
                let (matchResults, _) = try await database.records(matching: typeQuery, resultsLimit: 100) // Handle pagination later if needed

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
            } else if let asset = record[CloudKitSchema.ROMFields.fileData] as? CKAsset {
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

        // Screenshot and artwork record types have been removed from schema

            // Remove .file and .metadata cases as they are not displayed or handled here
        case .file, .metadata:
            WLOG("Skipping unsupported record type in view: \(recordType.rawValue)")
            return nil // Don't create view models for these types
        }

        let modificationDate = record.modificationDate ?? record.creationDate ?? Date()

        return CloudKitRecordViewModel(
            recordID: record.recordID,
            recordType: recordType.rawValue,
            title: title,
            subtitle: subtitle,
            modificationDate: modificationDate,
            fileSize: fileSize,
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
                let recordID = CKRecord.ID(recordName: recordName)
                let systemName = getSystemName(fromIdentifier: game.systemIdentifier)
                let fileSizeBytes = Int64(game.fileSize)
                let fileSizeFormatted = formatBytes(fileSizeBytes)
                let modificationDate = game.importDate

                return CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType.rawValue,
                    title: game.title,
                    subtitle: "\(systemName) • \(fileSizeFormatted)",
                    modificationDate: modificationDate,
                    fileSize: fileSizeBytes,
                    isDownloaded: game.isDownloaded,
                    isDownloading: false
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
                let recordID = CKRecord.ID(recordName: recordName)
                let systemName = getSystemName(fromIdentifier: game.systemIdentifier)
                let fileSizeBytes = Int64(file.size)
                let fileSizeFormatted = formatBytes(fileSizeBytes)
                let gameTitle = game.title
                let modificationDate = saveState.date ?? Date()

                return CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType.rawValue,
                    title: file.fileName,
                    subtitle: "\(gameTitle) (\(systemName)) • \(fileSizeFormatted)",
                    modificationDate: modificationDate,
                    fileSize: fileSizeBytes,
                    isDownloaded: saveState.isDownloaded,
                    isDownloading: false
                )
            }

        case .bios:
            // Use PVBIOS from PVRealm
            let bioses = realm.objects(PVBIOS.self).filter("cloudRecordID != nil")
            DLOG("Found \(bioses.count) local BIOSes linked to CloudKit")
            viewModels = bioses.compactMap { bios -> CloudKitRecordViewModel? in
                guard let recordName = bios.cloudRecordID else { return nil }
                let recordID = CKRecord.ID(recordName: recordName)
                let systemIdentifier = bios.system?.identifier
                let systemName = getSystemName(fromIdentifier: systemIdentifier)
                let fileSizeBytes = Int64(bios.fileSize)
                let fileSizeFormatted = formatBytes(fileSizeBytes)
                let modificationDate = Date() // BIOS doesn't have date field, use current date

                return CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType.rawValue,
                    title: bios.descriptionText.isEmpty ? bios.expectedFilename : bios.descriptionText,
                    subtitle: "\(systemName) • \(fileSizeFormatted)",
                    modificationDate: modificationDate,
                    fileSize: fileSizeBytes,
                    isDownloaded: bios.isDownloaded,
                    isDownloading: false
                )
            }

            // Add cases for other synced types (Screenshots, etc.) if needed
        case .file, .metadata:
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

                case .saveState, .bios:
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

            let database = CKContainer.default().privateCloudDatabase

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

            case .bios:
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
        // Screenshot and artwork record types have been removed from schema
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

            case .bios:
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
        @State private var selectedFilter: RecordTypeFilter = .all
        @State private var searchText = ""

        // Computed property for filtered and sorted records
        private var filteredAndSortedRecords: [CloudKitRecordViewModel] {
            let filtered = viewModel.filteredRecords(filter: selectedFilter, searchText: searchText)

            switch viewModel.sortOrder {
            case .title:
                return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .date:
                return filtered.sorted { $0.modificationDate > $1.modificationDate } // Newest first
            case .type:
                return filtered.sorted { $0.recordType < $1.recordType }
            case .size:
                return filtered.sorted { $0.fileSize > $1.fileSize } // Largest first
            }
        }

        // MARK: - Body
        var body: some View {
            ZStack {
                // Retrowave background
                Color.retroBlack.edgesIgnoringSafeArea(.all)
                RetroTheme.RetroGridView()
                    .edgesIgnoringSafeArea(.all)
                    .opacity(0.18)
                RetroScanlineOverlay()
                    .opacity(0.05)
                    .allowsHitTesting(false)
                    .edgesIgnoringSafeArea(.all)

                Group { // Use Group to handle conditional content
                    if viewModel.isLoading && viewModel.records.isEmpty { // Show loading only on initial load
                        VStack(spacing: 14) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                                .scaleEffect(1.5)
                            Text("LOADING RECORDS…")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .tracking(1.4)
                                .foregroundColor(.retroPink)
                                .shadow(color: .retroPink.opacity(0.5), radius: 4)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    } else if let error = viewModel.error {
                        ErrorView(error: error, viewModel: viewModel)

                    } else if viewModel.records.isEmpty && !viewModel.isLoading { // Show empty state only when not loading
                        VStack(spacing: 14) {
                            Image(systemName: "icloud.slash")
                                .font(.system(size: 48, weight: .light))
                                .foregroundStyle(
                                    LinearGradient(colors: [.retroPurple, .retroPink],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .shadow(color: .retroPurple.opacity(0.5), radius: 6)
                            Text("NO CLOUD RECORDS FOUND")
                                .font(.system(size: 13, weight: .heavy))
                                .tracking(1.4)
                                .foregroundColor(.retroPink)
                            Text("No records were found in CloudKit for the \(viewModel.selectedScope == .private ? "Private" : "Shared") database. Ensure sync is enabled and has completed at least once.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            Button {
                                Task { await viewModel.refreshMetadata() }
                            } label: {
                                Text("REFRESH")
                                    .font(.system(size: 12, weight: .heavy))
                                    .tracking(1.2)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 22)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(LinearGradient(colors: [.retroPink, .retroPurple],
                                                                 startPoint: .leading, endPoint: .trailing))
                                    )
                                    .shadow(color: .retroPink.opacity(0.5), radius: 6)
                            }
                            .buttonStyle(.plain)
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
            }
            .preferredColorScheme(.dark)
            .navigationTitle("On-Demand Downloads")
            .searchable(text: $searchText, prompt: "Search Records")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Picker("Database Scope", selection: $viewModel.selectedScope) {
                        Text("Private").tag(CKDatabase.Scope.private)
                        Text("Shared").tag(CKDatabase.Scope.shared)
                        // Public scope might not be relevant here
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
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
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            // Initial data load
            .task(id: viewModel.selectedScope) { // Re-run task when scope changes
                await viewModel.refreshMetadata()
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            ), actions: {
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

}

// MARK: - File-scope sub-views
// Lifted out of `CloudKitOnDemandViewModel` to keep that class under the
// SwiftLint `type_body_length` error threshold (600 lines).

private struct CloudKitRecordRow: View {
        // Use the immutable ViewModel passed in. State changes are handled by the parent @StateObject.
        let record: CloudKitRecordViewModel
        let viewModel: CloudKitOnDemandViewModel // Pass ViewModel for activeOperations access
        var onDownload: (CloudKitRecordViewModel) -> Void
        var onDelete: (CloudKitRecordViewModel) -> Void

        var body: some View {
            HStack(spacing: 12) {
                // Type icon
                typeIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(record.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer()

                statusIndicator
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.retroDarkBlue.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.retroBlue.opacity(0.35), .retroPurple.opacity(0.3)],
                                       startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1
                    )
            )
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

        // MARK: - Row helpers

        private var typeIcon: some View {
            let (symbol, accent) = typeAccent
            return ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 32, height: 32)
                Circle()
                    .strokeBorder(accent.opacity(0.6), lineWidth: 1)
                    .frame(width: 32, height: 32)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accent)
                    .shadow(color: accent.opacity(0.5), radius: 3)
            }
        }

        private var typeAccent: (String, Color) {
            switch CloudKitSchema.RecordType(rawValue: record.recordType) {
            case .rom: return ("gamecontroller.fill", .retroBlue)
            case .saveState: return ("square.and.arrow.down.fill", .retroPurple)
            case .bios: return ("cpu.fill", .retroPink)
            case .file: return ("doc.fill", .retroGreen)
            case .metadata: return ("info.circle.fill", .retroCyan)
            case .none: return ("questionmark.circle.fill", .gray)
            }
        }

        @ViewBuilder
        private var statusIndicator: some View {
            let isDownloadable = CloudKitSchema.RecordType(rawValue: record.recordType) == .rom ||
                                 CloudKitSchema.RecordType(rawValue: record.recordType) == .saveState ||
                                 CloudKitSchema.RecordType(rawValue: record.recordType) == .bios

            if viewModel.activeOperations[record.recordID.recordName] == true || record.isDownloading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    .scaleEffect(0.75)
            } else if record.isDownloaded {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("LOCAL")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                }
                .foregroundColor(.retroGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(Color.retroGreen.opacity(0.12))
                )
                .overlay(
                    Capsule().strokeBorder(Color.retroGreen.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: .retroGreen.opacity(0.4), radius: 3)
            } else if isDownloadable {
                Button {
                    onDownload(record)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 11, weight: .bold))
                        Text("GET")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(0.8)
                    }
                    .foregroundColor(.retroBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(Color.retroBlue.opacity(0.12))
                    )
                    .overlay(
                        Capsule().strokeBorder(Color.retroBlue.opacity(0.5), lineWidth: 1)
                    )
                }
                #if !os(tvOS)
                .buttonStyle(.borderless)
                #endif
                .disabled(viewModel.activeOperations[record.recordID.recordName] == true)
            } else {
                EmptyView()
            }
        }
    }

// MARK: - Error View
private struct ErrorView: View {
        let error: String
        let viewModel: CloudKitOnDemandViewModel

        var body: some View {
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.retroOrange, .retroPink],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .retroOrange.opacity(0.6), radius: 6)

                Text("ERROR LOADING RECORDS")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.4)
                    .foregroundColor(.retroOrange)
                    .shadow(color: .retroOrange.opacity(0.5), radius: 3)

                Text(error)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .lineLimit(6)

                Button {
                    Task { await viewModel.refreshMetadata() }
                } label: {
                    Text("RETRY")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LinearGradient(colors: [.retroOrange, .retroPink],
                                                     startPoint: .leading, endPoint: .trailing))
                        )
                        .shadow(color: .retroOrange.opacity(0.5), radius: 6)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.retroOrange.opacity(0.45), lineWidth: 1)
            )
            .padding(24)
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
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: onDeleteItems) // Swipe to delete
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .refreshable { await viewModel.refreshMetadata() } // Pull-to-refresh for List
        }
    }
