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
                    Image(systemName: "cloud.slash")
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
            return "doc"
        }
    }
    
    var iconColor: Color {
        switch recordType {
        case "ROM":
            return .retroPink
        case "SaveState":
            return .retroBlue
        case "BIOS":
            return .retroPurple
        default:
            return .gray
        }
    }
}

/// View model for CloudKit on-demand downloads
class CloudKitOnDemandViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published var records: [CloudKitRecordViewModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var syncers: [CloudKitSyncer] = []
    
    // MARK: - Initialization
    
    init() {
        setupSyncers()
    }
    
    // MARK: - Methods
    
    /// Set up CloudKit syncers for different record types
    private func setupSyncers() {
        // Get the main CloudKit syncer
        if let syncer = CloudKitSyncerStore.shared.getSyncer() {
            syncers.append(syncer)
        }
    }
    
    /// Refresh metadata from CloudKit
    func refreshMetadata() async {
        guard !syncers.isEmpty else {
            ELOG("No CloudKit syncers available")
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        var allRecords: [CloudKitRecordViewModel] = []
        
        // Sync metadata for each syncer
        for syncer in syncers {
            do {
                // Sync metadata only (no file downloads)
                let count = await syncer.syncMetadataOnly()
                DLOG("Synced \(count) metadata records for \(syncer.recordType)")
                
                // Fetch records from database
                let records = await fetchRecordsFromDatabase(forType: syncer.recordType)
                allRecords.append(contentsOf: records)
            } catch {
                ELOG("Error syncing metadata: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Failed to sync metadata: \(error.localizedDescription)"
                }
            }
        }
        
        await MainActor.run {
            self.records = allRecords
            isLoading = false
        }
    }
    
    /// Download a record by its ID
    func downloadRecord(recordID: String) async {
        // Find the record in our list
        guard let index = records.firstIndex(where: { $0.recordID == recordID }) else {
            ELOG("Record not found: \(recordID)")
            return
        }
        
        // Update UI to show download in progress
        await MainActor.run {
            records[index].isDownloading = true
        }
        
        // Find the appropriate syncer
        let recordType = records[index].recordType
        guard let syncer = syncers.first(where: { $0.recordType == recordType }) else {
            ELOG("No syncer found for record type: \(recordType)")
            await MainActor.run {
                records[index].isDownloading = false
            }
            return
        }
        
        do {
            // Download the file
            let fileURL = try await syncer.downloadFileOnDemand(recordName: recordID)
            DLOG("Downloaded file to: \(fileURL.path)")
            
            // Update the record status in the database
            await updateRecordDownloadStatus(recordID: recordID, recordType: recordType, isDownloaded: true)
            
            // Update the UI
            await MainActor.run {
                records[index].isDownloading = false
                records[index].isDownloaded = true
            }
        } catch {
            ELOG("Error downloading file: \(error.localizedDescription)")
            await MainActor.run {
                records[index].isDownloading = false
                errorMessage = "Failed to download file: \(error.localizedDescription)"
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
    private func fetchRecordsFromDatabase(forType recordType: String) async -> [CloudKitRecordViewModel] {
        do {
            // Get the Realm instance
            let realm = try await Realm()
            var viewModels: [CloudKitRecordViewModel] = []
            
            switch recordType {
            case CloudKitSchema.RecordType.rom:
                // Query PVGame objects with cloudRecordID
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
                // Query PVSaveState objects with cloudRecordID
                let saveStates = realm.objects(PVSaveState.self).filter("cloudRecordID != nil")
                
                for saveState in saveStates {
                    guard let recordID = saveState.cloudRecordID else { continue }
                    
                    let gameTitle = saveState.game?.title ?? "Unknown Game"
                    let description = saveState.userDescription ?? "Save State"
                    let fileSize = ByteCountFormatter.string(fromByteCount: Int64(saveState.fileSize), countStyle: .file)
                    
                    viewModels.append(CloudKitRecordViewModel(
                        recordID: recordID,
                        recordType: CloudKitSchema.RecordType.saveState,
                        title: description,
                        subtitle: "\(gameTitle) • \(fileSize)",
                        isDownloaded: saveState.isDownloaded
                    ))
                }
                
            case CloudKitSchema.RecordType.bios:
                // Query PVBIOS objects with cloudRecordID
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
