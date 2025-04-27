//
//  CloudKitOnDemandView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/23/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

import SwiftUI
import PVLibrary
import PVLogging
import Combine
import Defaults
import PVSettings
import CloudKit
import RealmSwift
import PVRealm

/// A view that displays CloudKit records available for on-demand download
public struct CloudKitOnDemandView: View {
    // MARK: - Properties

    @StateObject private var viewModel = CloudKitOnDemandViewModel()
    @State private var showingFilterOptions = false
    @State private var selectedFilter: RecordTypeFilter = .all

    // MARK: - Body

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header with filter options
            HStack {
                Text("Available CloudKit Records")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Button(action: {
                    showingFilterOptions = true
                }) {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.retroBlue)
                }
                .actionSheet(isPresented: $showingFilterOptions) {
                    ActionSheet(
                        title: Text("Filter Records"),
                        buttons: [
                            .default(Text("All Records")) { selectedFilter = .all },
                            .default(Text("ROMs Only")) { selectedFilter = .roms },
                            .default(Text("Save States Only")) { selectedFilter = .saveStates },
                            .default(Text("BIOS Files Only")) { selectedFilter = .bios },
                            .default(Text("Not Downloaded")) { selectedFilter = .notDownloaded },
                            .cancel()
                        ]
                    )
                }

                Button(action: {
                    Task {
                        await viewModel.refreshMetadata()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .foregroundColor(.retroBlue)
                }
            }
            .padding()
            .background(Color.retroDarkBlue.opacity(0.3))

            // Record list
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    Text("Loading records...")
                        .foregroundColor(.secondary)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredRecords(filter: selectedFilter).isEmpty {
                VStack {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.retroPurple.opacity(0.5))
                        .padding()

                    Text("No records found")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Text("Sync your devices to see available files")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    Button("Sync Metadata") {
                        Task {
                            await viewModel.refreshMetadata()
                        }
                    }
                    .padding()
                    .background(Color.retroPink)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 16)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .padding()
                    }

                    if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            .padding()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.filteredRecords(filter: selectedFilter)) { record in
                        CloudKitRecordRow(record: record, onDownload: { recordID in
                            Task {
                                await viewModel.downloadRecord(recordID: recordID)
                            }
                        })
                    }
                }
            }
        }
        .navigationTitle("On-Demand Downloads")
        .onAppear {
            Task {
                await viewModel.refreshMetadata()
            }
        }
    }
}

// MARK: - Supporting Views

/// Row displaying a CloudKit record with download option
struct CloudKitRecordRow: View {
    let record: CloudKitRecordViewModel
    let onDownload: (String) -> Void

    var body: some View {
        HStack {
            // Record icon
            Image(systemName: record.iconName)
                .font(.title2)
                .foregroundColor(record.iconColor)
                .frame(width: 40, height: 40)
                .background(record.iconColor.opacity(0.1))
                .cornerRadius(8)

            // Record details
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title)
                    .font(.headline)

                HStack {
                    Text(record.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if record.isDownloaded {
                        Text("Downloaded")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            // Download button
            if !record.isDownloaded {
                Button(action: {
                    onDownload(record.recordID)
                }) {
                    if record.isDownloading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    } else {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.title3)
                            .foregroundColor(.retroPink)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 44, height: 44)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - View Model

/// Filter options for CloudKit records
enum RecordTypeFilter {
    case all
    case roms
    case saveStates
    case bios
    case notDownloaded
}

/// View model for a CloudKit record
struct CloudKitRecordViewModel: Identifiable {
    let id = UUID()
    let recordID: String
    let recordType: String
    let title: String
    let subtitle: String
    var isDownloaded: Bool
    var isDownloading: Bool = false

    var iconName: String {
        switch recordType {
        case "ROM":
            return "gamecontroller"
        case "SaveState":
            return "bookmark"
        case "BIOS":
            return "cpu"
        default:
            return "doc.fill"
        }
    }

    var iconColor: Color {
        switch recordType {
        case "ROM", "GAME":
            return .retroPink
        case "SaveState":
            return .retroBlue
        case "BIOS":
            return .retroPurple
        case "File":
            return .retroGreen
        default:
            return .gray
        }
    }
}

/// View model for CloudKit on-demand downloads
class CloudKitOnDemandViewModel: ObservableObject {
    // MARK: - Properties

    @Published var records: [CloudKitRecordViewModel] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var searchText = ""

    // CloudKit container and database
    private let container = CKContainer(identifier: iCloudConstants.containerIdentifier)
    private let privateDatabase: CKDatabase

    // MARK: - Initialization

    init() {
        privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Methods

    /// Refresh metadata directly from CloudKit
    func refreshMetadata() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            successMessage = nil
        }

        do {
            var allRecords: [CloudKitRecordViewModel] = []

            // Query each record type directly from CloudKit
            for recordType in CloudKitSchema.RecordType.all {
                DLOG("Querying CloudKit for record type: \(recordType)")

                // Create a query for this record type
                let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
                let queryOperation = CKQueryOperation(query: query)
                queryOperation.resultsLimit = 100 // Adjust as needed

                var recordsForType: [CKRecord] = []

                // Set up the record matched handler
                queryOperation.recordMatchedBlock = { recordID, result in
                    switch result {
                    case .success(let record):
                        recordsForType.append(record)
                    case .failure(let error):
                        ELOG("Error fetching record \(recordID.recordName): \(error.localizedDescription)")
                    }
                }

                // Set up the query completion handler
                queryOperation.queryResultBlock = { result in
                    switch result {
                    case .success(let cursor):
                        DLOG("Query completed for \(recordType), found \(recordsForType.count) records")
                        if let cursor = cursor {
                            DLOG("More records available with cursor: \(cursor)")
                        }
                    case .failure(let error):
                        ELOG("Query failed for \(recordType): \(error.localizedDescription)")
                    }
                }

                // Execute the query operation
                try await privateDatabase.add(queryOperation)

                // Process the records for this type
                let viewModels = await self.processRecords(recordsForType, recordType: recordType)
                allRecords.append(contentsOf: viewModels)
            }

            // Update UI on main thread
            await MainActor.run {
                self.records = allRecords
                self.isLoading = false

                if allRecords.isEmpty {
                    self.successMessage = "No records found in CloudKit"
                } else {
                    self.successMessage = "Found \(allRecords.count) records in CloudKit"
                }
            }
        } catch {
            ELOG("Error querying CloudKit: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Error querying CloudKit: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Process CloudKit records into view models
    private func processRecords(_ records: [CKRecord], recordType: String) async -> [CloudKitRecordViewModel] {
        var viewModels: [CloudKitRecordViewModel] = []

        for record in records {
            // Extract common fields
            let recordID = record.recordID.recordName
            let filename = record[CloudKitSchema.FileAttributes.filename] as? String ?? "Unknown"

            // Check if this file is already downloaded locally
            let isDownloaded = await checkIfFileIsDownloaded(record: record, recordType: recordType)

            // Create view model based on record type
            var viewModel: CloudKitRecordViewModel

            switch recordType {
            case CloudKitSchema.RecordType.rom:
                let title = record[CloudKitSchema.ROMAttributes.title] as? String ?? filename
                let system = record[CloudKitSchema.ROMAttributes.systemIdentifier] as? String ?? "Unknown"

                // Get file size
                let fileSize = getFileSizeFromAsset(record[CloudKitSchema.FileAttributes.fileData] as? CKAsset)
                let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

                viewModel = CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType, title: title,
                    subtitle: "\(system) • \(fileSizeString)",
                    isDownloaded: isDownloaded,
                    isDownloading: false
                )

            case CloudKitSchema.RecordType.saveState:
                let description = record[CloudKitSchema.SaveStateAttributes.description] as? String ?? "Save State"
                let gameID = record[CloudKitSchema.SaveStateAttributes.gameID] as? String ?? "Unknown"

                // Get file size
                let fileSize = getFileSizeFromAsset(record[CloudKitSchema.FileAttributes.fileData] as? CKAsset)
                let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

                viewModel = CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType, title: description,
                    subtitle: "Save State • \(fileSizeString)",
                    isDownloaded: isDownloaded,
                    isDownloading: false
                )

            case CloudKitSchema.RecordType.bios:
                let description = record[CloudKitSchema.BIOSAttributes.description] as? String ?? filename
                let system = record[CloudKitSchema.BIOSAttributes.systemIdentifier] as? String ?? "Unknown"

                // Get file size
                let fileSize = getFileSizeFromAsset(record[CloudKitSchema.FileAttributes.fileData] as? CKAsset)
                let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

                viewModel = CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType, title: description,
                    subtitle: "\(system) BIOS • \(fileSizeString)",
                    isDownloaded: isDownloaded,
                    isDownloading: false
                )

            default: // Generic file
                let directory = record[CloudKitSchema.FileAttributes.directory] as? String ?? "Unknown"

                // Get file size
                let fileSize = getFileSizeFromAsset(record[CloudKitSchema.FileAttributes.fileData] as? CKAsset)
                let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

                viewModel = CloudKitRecordViewModel(
                    recordID: recordID,
                    recordType: recordType, title: filename,
                    subtitle: "\(directory) • \(fileSizeString)",
                    isDownloaded: isDownloaded,
                    isDownloading: false
                )
            }

            viewModels.append(viewModel)
        }

        return viewModels
    }

    /// Get file size from a CKAsset
    private func getFileSizeFromAsset(_ asset: CKAsset?) -> Int64 {
        guard let asset = asset, let fileURL = asset.fileURL else { return 0 }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let size = attributes[.size] as? NSNumber {
                return size.int64Value
            }
        } catch {
            ELOG("Error getting file size: \(error.localizedDescription)")
        }

        return 0
    }

    /// Check if a file is already downloaded locally
    private func checkIfFileIsDownloaded(record: CKRecord, recordType: String) async -> Bool {
        do {
            let realm = try await Realm()

            switch recordType {
            case CloudKitSchema.RecordType.rom:
                if let gameID = record[CloudKitSchema.FileAttributes.gameID] as? String,
                   let game = realm.objects(PVGame.self).filter("gameID == %@", gameID).first {
                    return game.isDownloaded
                }

            case CloudKitSchema.RecordType.saveState:
                if let saveStateID = record[CloudKitSchema.FileAttributes.saveStateID] as? String,
                   let saveState = realm.objects(PVSaveState.self).filter("saveStateID == %@", saveStateID).first {
                    return saveState.isDownloaded
                }

            case CloudKitSchema.RecordType.bios:
                if let md5 = record[CloudKitSchema.BIOSAttributes.md5Hash] as? String,
                   let bios = realm.objects(PVBIOS.self).filter("md5 == %@", md5).first {
                    return bios.isDownloaded
                }

            default:
                // For other file types, check if the file exists locally
                if let directory = record[CloudKitSchema.FileAttributes.directory] as? String,
                   let filename = record[CloudKitSchema.FileAttributes.filename] as? String {
                    let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let filePath = documentsDir.appendingPathComponent(directory).appendingPathComponent(filename)
                    return FileManager.default.fileExists(atPath: filePath.path)
                }
            }
        } catch {
            ELOG("Error checking if file is downloaded: \(error.localizedDescription)")
        }

        return false
    }

    /// Download a record by its ID
    /// - Parameter recordID: The record ID to download
    func downloadRecord(recordID: String) async {
        // Find the record in our list
        guard let index = records.firstIndex(where: { $0.recordID == recordID }) else {
            ELOG("Record not found: \(recordID)")
            return
        }

        // Update UI to show download in progress
        await MainActor.run {
            records[index].isDownloading = true
            errorMessage = nil // Clear any previous error
        }

        let recordType = records[index].recordType

        do {
            // Fetch the record from CloudKit
            let recordID = CKRecord.ID(recordName: recordID)
            let record = try await privateDatabase.record(for: recordID)

            // Extract file asset and download it
            guard let fileAsset = record[CloudKitSchema.FileAttributes.fileData] as? CKAsset,
                  let fileURL = fileAsset.fileURL else {
                throw NSError(domain: "com.provenance.cloudkit", code: 1001,
                              userInfo: [NSLocalizedDescriptionKey: "No file data found in record"])
            }

            // Get destination directory and filename
            let directory = record[CloudKitSchema.FileAttributes.directory] as? String ?? "Unknown"
            let filename = record[CloudKitSchema.FileAttributes.filename] as? String ?? "file.dat"

            // Create destination directory
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationDir = documentsDir.appendingPathComponent(directory)

            do {
                try FileManager.default.createDirectory(at: destinationDir,
                                                      withIntermediateDirectories: true)
            } catch {
                ELOG("Error creating directory \(destinationDir.path): \(error.localizedDescription)")
                throw error
            }

            // Create destination file URL
            let destinationURL = destinationDir.appendingPathComponent(filename)

            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Copy file to destination
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)

            DLOG("Downloaded file to: \(destinationURL.path)")

            // Update the record status in the database
            await updateRecordDownloadStatus(recordID: recordID.recordName, recordType: recordType, isDownloaded: true)

            // Update the UI
            await MainActor.run {
                records[index].isDownloading = false
                records[index].isDownloaded = true

                // Show success message
                let title = records[index].title
                successMessage = "Downloaded \(title) successfully"

                // Clear success message after a delay
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    await MainActor.run {
                        if successMessage == "Downloaded \(title) successfully" {
                            successMessage = nil
                        }
                    }
                }
            }
        } catch {
            ELOG("Error downloading file: \(error.localizedDescription)")
            await MainActor.run {
                records[index].isDownloading = false
                errorMessage = "Error downloading file: \(error.localizedDescription)"

                // Clear error message after a delay
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                    await MainActor.run {
                        if errorMessage?.contains(error.localizedDescription) == true {
                            errorMessage = nil
                        }
                    }
                }
            }
        }
    }

    /// Update the download status of a record in the database
    private func updateRecordDownloadStatus(recordID: String, recordType: String, isDownloaded: Bool) async {
        do {
            let realm = try await Realm()

            try await realm.write {
                switch recordType {
                case CloudKitSchema.RecordType.rom:
                    if let game = realm.objects(PVGame.self).filter("cloudRecordID == %@", recordID).first {
                        game.isDownloaded = isDownloaded
                        DLOG("Updated download status for game: \(game.title)")
                    }

                case CloudKitSchema.RecordType.saveState:
                    if let saveState = realm.objects(PVSaveState.self).filter("cloudRecordID == %@", recordID).first {
                        saveState.isDownloaded = isDownloaded
                        DLOG("Updated download status for save state: \(saveState.userDescription ?? "Unknown")")
                    }

                case CloudKitSchema.RecordType.bios:
                    if let bios = realm.objects(PVBIOS.self).filter("cloudRecordID == %@", recordID).first {
                        bios.isDownloaded = isDownloaded
                        DLOG("Updated download status for BIOS: \(bios.descriptionText)")
                    }

                default:
                    ELOG("Unknown record type: \(recordType)")
                }
            }
        } catch {
            ELOG("Error updating record download status: \(error.localizedDescription)")
        }
    }

    /// Fetch records from the database
    @MainActor
    private func fetchRecordsFromDatabase(forType recordType: String) async -> [CloudKitRecordViewModel] {
        do {
            var viewModels: [CloudKitRecordViewModel] = []

            switch recordType {
            case CloudKitSchema.RecordType.rom:
                // First, try to get records directly from the CloudKit syncer
                if let romSyncer = CloudKitSyncerStore.shared.romSyncers.first as? CloudKitRomsSyncer {
                    DLOG("Fetching ROM records from CloudKit syncer")
                    let records = await romSyncer.getAllRecords()

                    for record in records {
                        guard let filename = record[CloudKitSchema.FileAttributes.filename] as? String else { continue }
                        guard let system = record[CloudKitSchema.ROMAttributes.systemIdentifier] as? String else { continue }

                        let title = record[CloudKitSchema.ROMAttributes.title] as? String ?? filename
                        // Get file size from the fileData asset if available
                        let fileSize: Int64
                        if let fileAsset = record[CloudKitSchema.FileAttributes.fileData] as? CKAsset,
                           let fileURL = fileAsset.fileURL,
                           let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                           let size = attributes[.size] as? NSNumber {
                            fileSize = size.int64Value
                        } else {
                            fileSize = 0
                        }
                        let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

                        // Check if this ROM is downloaded locally
                        let isDownloaded = await romSyncer.isFileDownloaded(filename: filename, inSystem: system)

                        viewModels.append(CloudKitRecordViewModel(
                            recordID: record.recordID.recordName,
                            recordType: CloudKitSchema.RecordType.rom,
                            title: title,
                            subtitle: "\(system) • \(fileSizeString)",
                            isDownloaded: isDownloaded
                        ))
                    }

                    DLOG("Found \(viewModels.count) ROM records from CloudKit")

                    // If we got records from CloudKit, return them
                    if !viewModels.isEmpty {
                        return viewModels
                    }
                }

                // Fallback: Query PVGame objects with cloudRecordID
                DLOG("Falling back to Realm database for ROM records")
                // Get the Realm instance
                let realm = try! await Realm()
                let games = realm.objects(PVGame.self).filter("cloudRecordID != nil")

                for game in games {
                    guard let recordID = game.cloudRecordID else { continue }

                    let systemName = game.system?.name ?? "Unknown System"
                    let fileSize = ByteCountFormatter.string(fromByteCount: Int64(game.fileSize), countStyle: .file)

                    viewModels.append(CloudKitRecordViewModel(
                        recordID: recordID,
                        recordType: CloudKitSchema.RecordType.rom,
                        title: game.title,
                        subtitle: "\(systemName) • \(fileSize)",
                        isDownloaded: game.isDownloaded
                    ))
                }

            case CloudKitSchema.RecordType.saveState:
                // First, try to get records directly from the CloudKit syncer
                if let saveStateSyncer = CloudKitSyncerStore.shared.saveStateSyncers.first as? CloudKitSaveStatesSyncer {
                    DLOG("Fetching SaveState records from CloudKit syncer")
                    let records = await saveStateSyncer.getAllRecords()

                    for record in records {
                        guard let filename = record[CloudKitSchema.FileAttributes.filename] as? String else { continue }
                        // Get system from the FileAttributes.system field
                        guard let system = record[CloudKitSchema.FileAttributes.system] as? String else { continue }

                        let gameID = record[CloudKitSchema.FileAttributes.gameID] as? String
                        let description = record[CloudKitSchema.SaveStateAttributes.description] as? String ?? filename
                        // Get file size from the fileData asset if available
                        let fileSize: Int64
                        if let fileAsset = record[CloudKitSchema.FileAttributes.fileData] as? CKAsset,
                           let fileURL = fileAsset.fileURL,
                           let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                           let size = attributes[.size] as? NSNumber {
                            fileSize = size.int64Value
                        } else {
                            fileSize = 0
                        }
                        let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

                        // Check if this save state is downloaded locally
                        let isDownloaded = await saveStateSyncer.isFileDownloaded(filename: filename, inSystem: system, gameID: gameID)

                        viewModels.append(CloudKitRecordViewModel(
                            recordID: record.recordID.recordName,
                            recordType: CloudKitSchema.RecordType.saveState,
                            title: description,
                            subtitle: "\(system) • \(fileSizeString)",
                            isDownloaded: isDownloaded
                        ))
                    }

                    DLOG("Found \(viewModels.count) SaveState records from CloudKit")

                    // If we got records from CloudKit, return them
                    if !viewModels.isEmpty {
                        return viewModels
                    }
                }

                // Fallback: Query PVSaveState objects with cloudRecordID
                DLOG("Falling back to Realm database for SaveState records")
                let realm = try! await Realm()
                let saveStates = realm.objects(PVSaveState.self).filter("cloudRecordID != nil")

                for saveState in saveStates {
                    guard let recordID = saveState.cloudRecordID else { continue }

                    let game = saveState.game
                    let systemName = game?.system?.name ?? "Unknown System"
                    let fileSize = ByteCountFormatter.string(fromByteCount: Int64(saveState.fileSize), countStyle: .file)

                    viewModels.append(CloudKitRecordViewModel(
                        recordID: recordID,
                        recordType: CloudKitSchema.RecordType.saveState,
                        title: saveState.fileName,
                        subtitle: "\(systemName) • \(fileSize)",
                        isDownloaded: saveState.isDownloaded
                    ))
                }

            case CloudKitSchema.RecordType.bios:
                // First, try to get records directly from the CloudKit syncer
                if let biosSyncer = CloudKitSyncerStore.shared.biosSyncers.first as? CloudKitBIOSSyncer {
                    DLOG("Fetching BIOS records from CloudKit syncer")
                    let records = await biosSyncer.getAllRecords()

                    for record in records {
                        guard let filename = record[CloudKitSchema.FileAttributes.filename] as? String else { continue }

                        let systemId = record[CloudKitSchema.ROMAttributes.systemIdentifier] as? String ?? "Unknown"
                        let description = record[CloudKitSchema.BIOSAttributes.description] as? String ?? filename
                        // Get file size from the fileData asset if available
                        let fileSize: Int64
                        if let fileAsset = record[CloudKitSchema.FileAttributes.fileData] as? CKAsset,
                           let fileURL = fileAsset.fileURL,
                           let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                           let size = attributes[.size] as? NSNumber {
                            fileSize = size.int64Value
                        } else {
                            fileSize = 0
                        }
                        let fileSizeString = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

                        // Check if this BIOS file is downloaded locally
                        let isDownloaded = await biosSyncer.isFileDownloaded(filename: filename)

                        viewModels.append(CloudKitRecordViewModel(
                            recordID: record.recordID.recordName,
                            recordType: CloudKitSchema.RecordType.bios,
                            title: description,
                            subtitle: "\(systemId) • \(fileSizeString)",
                            isDownloaded: isDownloaded
                        ))
                    }

                    DLOG("Found \(viewModels.count) BIOS records from CloudKit")

                    // If we got records from CloudKit, return them
                    if !viewModels.isEmpty {
                        return viewModels
                    }
                }

                // Fallback: Query PVBIOS objects with cloudRecordID
                DLOG("Falling back to Realm database for BIOS records")
                let realm = try! await Realm()
                let biosFiles = realm.objects(PVBIOS.self).filter("cloudRecordID != nil")

                for bios in biosFiles {
                    guard let recordID = bios.cloudRecordID else { continue }

                    let systemName = bios.system?.name ?? "Unknown System"
                    let fileSize = ByteCountFormatter.string(fromByteCount: Int64(bios.fileSize), countStyle: .file)

                    viewModels.append(CloudKitRecordViewModel(
                        recordID: recordID,
                        recordType: CloudKitSchema.RecordType.bios,
                        title: bios.descriptionText.isEmpty ? bios.expectedFilename : bios.descriptionText,
                        subtitle: "\(systemName) • \(fileSize)",
                        isDownloaded: bios.isDownloaded
                    ))
                }

            default:
                ELOG("Unknown record type: \(recordType)")
            }

            DLOG("Found \(viewModels.count) records for type \(recordType)")
            return viewModels

        } catch {
            ELOG("Error fetching records from database: \(error.localizedDescription)")
            return []
        }
    }

    /// Filter records based on the selected filter
    func filteredRecords(filter: RecordTypeFilter) -> [CloudKitRecordViewModel] {
        switch filter {
        case .all:
            return records
        case .roms:
            return records.filter { $0.recordType == CloudKitSchema.RecordType.rom }
        case .saveStates:
            return records.filter { $0.recordType == CloudKitSchema.RecordType.saveState }
        case .bios:
            return records.filter { $0.recordType == CloudKitSchema.RecordType.bios }
        case .notDownloaded:
            return records.filter { !$0.isDownloaded }
        }
    }
}

#Preview {
    NavigationView {
        CloudKitOnDemandView()
    }
}
