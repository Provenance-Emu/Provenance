//
//  CloudKitDiagnosticView.swift
//  PVSwiftUI
//
//  Created by Joseph Mattiello on 4/27/25.
//  Copyright 2025 Provenance Emu. All rights reserved.
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

/// A view that directly queries CloudKit to diagnose sync issues
public struct CloudKitDiagnosticView: View {
    @StateObject private var viewModel = CloudKitDiagnosticViewModel()
    @State private var showingActionSheet = false
    @State private var recordTypeToDelete: String? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header with actions
            HStack {
                Text("CloudKit Diagnostic")
                    .font(.headline)
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [.retroPink, .retroPurple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Spacer()
                
                if #available(tvOS 17.0, *) {
                    Menu {
                        Button(action: {
                            Task {
                                await viewModel.refreshAllRecords()
                            }
                        }) {
                            Label("Refresh All Records", systemImage: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            Task {
                                await viewModel.checkSchemaStatus()
                            }
                        }) {
                            Label("Check Schema Status", systemImage: "checklist")
                        }
                        
                        Button(action: {
                            showingActionSheet = true
                        }) {
                            Label("Delete All Records", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                            .foregroundColor(.retroBlue)
                    }
                } else {
                    // Fallback on earlier versions
                }
            }
            .padding()
            .background(Color.retroDarkBlue.opacity(0.3))
            
            // Status section
            VStack(alignment: .leading, spacing: 8) {
                Text("CloudKit Status")
                    .font(.headline)
                    .foregroundColor(.retroPink)
                
                HStack {
                    Text("Container:")
                        .foregroundColor(.secondary)
                    Text(viewModel.containerIdentifier)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Account Status:")
                        .foregroundColor(.secondary)
                    Text(viewModel.accountStatus)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.accountStatusColor)
                }
                
                HStack {
                    Text("Schema Status:")
                        .foregroundColor(.secondary)
                    Text(viewModel.schemaStatus)
                        .fontWeight(.medium)
                        .foregroundColor(viewModel.schemaStatusColor)
                }
                
                if !viewModel.recordCounts.isEmpty {
                    Text("Record Counts:")
                        .font(.headline)
                        .foregroundColor(.retroPink)
                        .padding(.top, 8)
                    
                    ForEach(viewModel.recordCounts.sorted(by: { $0.key < $1.key }), id: \.key) { type, count in
                        HStack {
                            Text(type)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(count)")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .padding()
            .background(Color.retroDarkBlue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.top)
            
            // Main content
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    Text("Querying CloudKit...")
                        .foregroundColor(.secondary)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.records.isEmpty {
                VStack {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.retroPurple.opacity(0.5))
                        .padding()
                    
                    Text("No records found in CloudKit")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button("Query CloudKit") {
                        Task {
                            await viewModel.refreshAllRecords()
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
                    ForEach(viewModel.recordTypeGroups.sorted(by: { $0.key < $1.key }), id: \.key) { recordType, records in
                        SwiftUI.Section(header:
                            HStack {
                                Text(recordType)
                                    .font(.headline)
                                    .foregroundColor(.retroPink)
                                Spacer()
                                Text("\(records.count) records")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        ) {
                            ForEach(records, id: \.recordID) { record in
                                CloudKitRecordDetailRow(record: record)
                            }
                        }
                    }
                }
            }
            
            // Error message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(8)
                    .padding()
            }
            
            // Success message
            if let successMessage = viewModel.successMessage {
                Text(successMessage)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(8)
                    .padding()
            }
        }
        .navigationTitle("CloudKit Diagnostic")
        .onAppear {
            Task {
                await viewModel.checkAccountStatus()
                await viewModel.refreshAllRecords()
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Delete CloudKit Records"),
                message: Text("This will permanently delete ALL records from your CloudKit database. This action cannot be undone."),
                buttons: [
                    .destructive(Text("Delete All Records")) {
                        Task {
                            await viewModel.deleteAllRecords()
                        }
                    },
                    .cancel()
                ]
            )
        }
    }
}

/// Row displaying CloudKit record details
struct CloudKitRecordDetailRow: View {
    let record: CloudKitRecordDetail
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Button(action: {
                isExpanded.toggle()
            }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.recordName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("ID: \(record.recordID)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.retroBlue)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(record.fields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(.retroPink)
                            
                            Text(value)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 8)
    }
}

/// View model for CloudKit diagnostic view
class CloudKitDiagnosticViewModel: ObservableObject {
    // MARK: - Properties
    
    @Published var records: [CloudKitRecordDetail] = []
    @Published var recordCounts: [String: Int] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var accountStatus = "Unknown"
    @Published var accountStatusColor = Color.gray
    @Published var schemaStatus = "Unknown"
    @Published var schemaStatusColor = Color.gray
    
    // CloudKit container
    private let container = CKContainer(identifier: iCloudConstants.containerIdentifier)
    private let privateDatabase: CKDatabase
    
    var containerIdentifier: String {
        iCloudConstants.containerIdentifier
    }
    
    var recordTypeGroups: [String: [CloudKitRecordDetail]] {
        Dictionary(grouping: records) { $0.recordType }
    }
    
    // MARK: - Initialization
    
    init() {
        privateDatabase = container.privateCloudDatabase
    }
    
    // MARK: - Methods
    
    /// Check the CloudKit account status
    func checkAccountStatus() async {
        do {
            let accountStatus = try await container.accountStatus()
            
            await MainActor.run {
                switch accountStatus {
                case .available:
                    self.accountStatus = "Available"
                    self.accountStatusColor = .green
                case .noAccount:
                    self.accountStatus = "No iCloud Account"
                    self.accountStatusColor = .red
                case .restricted:
                    self.accountStatus = "Restricted"
                    self.accountStatusColor = .orange
                case .couldNotDetermine:
                    self.accountStatus = "Could Not Determine"
                    self.accountStatusColor = .orange
                case .temporarilyUnavailable:
                    self.accountStatus = "Temporarily Unavailable"
                    self.accountStatusColor = .orange
                @unknown default:
                    self.accountStatus = "Unknown (\(accountStatus.rawValue))"
                    self.accountStatusColor = .gray
                }
            }
        } catch {
            await MainActor.run {
                self.accountStatus = "Error: \(error.localizedDescription)"
                self.accountStatusColor = .red
                self.errorMessage = "Failed to check account status: \(error.localizedDescription)"
            }
        }
    }
    
    /// Check the CloudKit schema status
    func checkSchemaStatus() async {
        await MainActor.run {
            isLoading = true
            schemaStatus = "Checking..."
            schemaStatusColor = .gray
        }
        
        do {
            // Try to initialize the schema
            let success = await CloudKitSchema.initializeSchema(in: privateDatabase)
            
            await MainActor.run {
                if success {
                    schemaStatus = "Initialized"
                    schemaStatusColor = .green
                    successMessage = "CloudKit schema initialized successfully"
                } else {
                    schemaStatus = "Failed to Initialize"
                    schemaStatusColor = .red
                    errorMessage = "Failed to initialize CloudKit schema"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                schemaStatus = "Error"
                schemaStatusColor = .red
                errorMessage = "Error checking schema status: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    /// Refresh all records from CloudKit
    func refreshAllRecords() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            successMessage = nil
        }
        
        do {
            var allRecords: [CloudKitRecordDetail] = []
            var counts: [String: Int] = [:]
            
            // Query each record type
            for recordTypeRawValue in CloudKitSchema.RecordType.allCases.map({ $0.rawValue }) {
                let query = CKQuery(recordType: recordTypeRawValue, predicate: NSPredicate(value: true))
                let (matchResults, _) = try await privateDatabase.records(matching: query)
                
                var recordsForType: [CKRecord] = []
                
                // Iterate through the results (recordID, result)
                for (_, result) in matchResults {
                    switch result {
                    case .success(let record):
                        recordsForType.append(record)
                    case .failure(let error):
                        // Log the specific error associated with this record fetch
                        ELOG("Error fetching a specific record: \(error.localizedDescription)")
                    }
                }
                
                // Process the records
                for record in recordsForType {
                    // Attempt to get a meaningful name, falling back to recordID
                    let displayName = record[CloudKitSchema.ROMFields.originalFilename] as? String ?? 
                                      record[CloudKitSchema.SaveStateFields.filename] as? String ??
                                      record.recordID.recordName
                    
                    let recordDetail = CloudKitRecordDetail(
                        recordID: record.recordID.recordName,
                        recordName: displayName, 
                        recordType: recordTypeRawValue,
                        fields: recordFieldsToStringDictionary(record: record)
                    )
                    allRecords.append(recordDetail)
                }
                
                // Update counts
                counts[recordTypeRawValue] = recordsForType.count
            }
            
            // Update UI on main thread
            await MainActor.run {
                self.records = allRecords
                self.recordCounts = counts
                self.isLoading = false
                
                if allRecords.isEmpty {
                    self.successMessage = "No records found in CloudKit"
                } else {
                    self.successMessage = "Found \(allRecords.count) records in CloudKit"
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error querying CloudKit: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Delete all records from CloudKit
    func deleteAllRecords() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            successMessage = nil
        }
        
        do {
            var totalDeleted = 0
            
            // Delete records for each record type
            for recordTypeRawValue in CloudKitSchema.RecordType.allCases.map({ $0.rawValue }) {
                let query = CKQuery(recordType: recordTypeRawValue, predicate: NSPredicate(value: true))
                let (results, _) = try await privateDatabase.records(matching: query)
                
                // Iterate through the results (recordID, result)
                for (recordID, result) in results {
                    switch result {
                    case .success(let record):
                        do {
                            _ = try await privateDatabase.deleteRecord(withID: record.recordID)
                            totalDeleted += 1
                        } catch {
                            ELOG("Error deleting record \(record.recordID.recordName): \(error.localizedDescription)")
                        }
                    case .failure(let error):
                        // Log the error encountered while fetching the record intended for deletion
                        ELOG("Error fetching record (ID: \(recordID.recordName)) intended for deletion: \(error.localizedDescription)")
                    }
                }
            }
            
            // Refresh records after deletion
            await refreshAllRecords()
            
            await MainActor.run {
                self.successMessage = "Deleted \(totalDeleted) records from CloudKit"
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Error deleting records: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Convert record fields to string dictionary for display
    private func recordFieldsToStringDictionary(record: CKRecord) -> [String: String] {
        var result: [String: String] = [:]
        
        for key in record.allKeys() {
            if let value = record[key] {
                if let stringValue = value as? String {
                    result[key] = stringValue
                } else if let dateValue = value as? Date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    result[key] = formatter.string(from: dateValue)
                } else if let numberValue = value as? NSNumber {
                    result[key] = numberValue.stringValue
                } else if let assetValue = value as? CKAsset {
                    if let fileURL = assetValue.fileURL {
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                            if let size = attributes[.size] as? NSNumber {
                                result[key] = "File Asset (\(ByteCountFormatter.string(fromByteCount: size.int64Value, countStyle: .file)))"
                            } else {
                                result[key] = "File Asset (unknown size)"
                            }
                        } catch {
                            result[key] = "File Asset (error getting size)"
                        }
                    } else {
                        result[key] = "File Asset (no URL)"
                    }
                } else {
                    result[key] = String(describing: value)
                }
            }
        }
        
        return result
    }
}

/// Model for CloudKit record details
struct CloudKitRecordDetail {
    let recordID: String
    let recordName: String
    let recordType: String
    let fields: [String: String]
}

#Preview {
    NavigationView {
        CloudKitDiagnosticView()
    }
}
