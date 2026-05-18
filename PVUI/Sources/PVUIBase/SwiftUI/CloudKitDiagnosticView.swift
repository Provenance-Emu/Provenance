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

/// A view that directly queries CloudKit to diagnose sync issues — retrowave restyle.
public struct CloudKitDiagnosticView: View {
    @StateObject private var viewModel = CloudKitDiagnosticViewModel()
    @State private var showingActionSheet = false
    @State private var recordTypeToDelete: String? = nil

    public init() {}

    public var body: some View {
        ZStack {
            // Retro background layers
            backgroundLayers

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    headerBar
                    statusPanel
                    contentSection
                    messagesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("CloudKit Diagnostic")
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                await viewModel.checkAccountStatus()
                await viewModel.checkSchemaStatus()
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

    // MARK: - Background

    private var backgroundLayers: some View {
        ZStack {
            Color.retroBlack.edgesIgnoringSafeArea(.all)
            RetroTheme.RetroGridView()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.22)
            RetroScanlineOverlay()
                .opacity(0.05)
                .allowsHitTesting(false)
                .edgesIgnoringSafeArea(.all)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 10) {
            // Pink section bar
            Rectangle()
                .fill(LinearGradient(colors: [.retroPink, .retroPurple], startPoint: .top, endPoint: .bottom))
                .frame(width: 4, height: 22)
                .shadow(color: .retroPink.opacity(0.7), radius: 4)

            Text("CLOUDKIT DIAGNOSTIC")
                .font(.system(size: 15, weight: .heavy))
                .tracking(1.6)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.retroPink, .retroPurple, .retroBlue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: .retroPink.opacity(0.4), radius: 4)

            Spacer()

            if #available(tvOS 17.0, *) {
                Menu {
                    Button(action: {
                        Task { await viewModel.refreshAllRecords() }
                    }) {
                        Label("Refresh All Records", systemImage: "arrow.clockwise")
                    }

                    Button(action: {
                        Task { await viewModel.checkSchemaStatus() }
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
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 12, weight: .bold))
                        Text("ACTIONS")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(0.8)
                    }
                    .foregroundColor(.retroBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.retroBlue.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.retroBlue.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.retroDarkBlue.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.retroPink.opacity(0.5), .retroBlue.opacity(0.4)],
                                   startPoint: .leading, endPoint: .trailing),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Status panel

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("STATUS")

            statusRow(label: "CONTAINER",
                      value: viewModel.containerIdentifier,
                      valueColor: .white)

            statusRow(label: "ACCOUNT",
                      value: viewModel.accountStatus,
                      valueColor: viewModel.accountStatusColor)

            statusRow(label: "SCHEMA",
                      value: viewModel.schemaStatus,
                      valueColor: viewModel.schemaStatusColor)

            if !viewModel.recordCounts.isEmpty {
                Rectangle()
                    .fill(LinearGradient(colors: [.retroPurple.opacity(0.4), .retroPink.opacity(0.2)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .padding(.vertical, 2)

                Text("RECORD COUNTS")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.2)
                    .foregroundColor(.retroPink)
                    .padding(.top, 2)

                ForEach(viewModel.recordCounts.sorted(by: { $0.key < $1.key }), id: \.key) { type, count in
                    HStack {
                        Text(type.uppercased())
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.75))
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.retroBlue)
                            .shadow(color: .retroBlue.opacity(0.4), radius: 3)
                    }
                }
            }
        }
        .padding(14)
        .background(panelBackground)
    }

    private func statusRow(label: String, value: String, valueColor: Color) -> some View {
        HStack(alignment: .center) {
            Text(label)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(valueColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer()
        }
    }

    // MARK: - Content section

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    .scaleEffect(1.4)
                Text("QUERYING CLOUDKIT…")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(.retroPink)
                    .shadow(color: .retroPink.opacity(0.6), radius: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .padding(20)
            .background(panelBackground)
        } else if viewModel.records.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [.retroPurple, .retroPink],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: .retroPurple.opacity(0.6), radius: 6)

                Text("NO RECORDS FOUND")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1.4)
                    .foregroundColor(.retroPink)

                Button {
                    Task { await viewModel.refreshAllRecords() }
                } label: {
                    Text("QUERY CLOUDKIT")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
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
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding(20)
            .background(panelBackground)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("RECORDS")

                ForEach(viewModel.recordTypeGroups.sorted(by: { $0.key < $1.key }), id: \.key) { recordType, records in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(recordType.uppercased())
                                .font(.system(size: 12, weight: .heavy))
                                .tracking(1.2)
                                .foregroundColor(.retroPink)
                            Spacer()
                            Text("\(records.count)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.retroBlue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color.retroBlue.opacity(0.15))
                                )
                                .overlay(
                                    Capsule().strokeBorder(Color.retroBlue.opacity(0.4), lineWidth: 1)
                                )
                        }
                        ForEach(records, id: \.recordID) { record in
                            CloudKitRecordDetailRow(record: record)
                        }
                    }
                    .padding(12)
                    .background(panelBackground)
                }
            }
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messagesSection: some View {
        if let errorMessage = viewModel.errorMessage {
            messageBanner(text: errorMessage,
                          accent: .retroOrange,
                          icon: "exclamationmark.triangle.fill")
        }

        if let successMessage = viewModel.successMessage {
            messageBanner(text: successMessage,
                          accent: .retroGreen,
                          icon: "checkmark.circle.fill")
        }
    }

    private func messageBanner(text: String, accent: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent)
                .shadow(color: accent.opacity(0.6), radius: 4)
            Text(text)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(accent.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Reusable bits

    private func sectionHeader(_ title: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(LinearGradient(colors: [.retroPink, .retroPurple],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 16)
                .shadow(color: .retroPink.opacity(0.7), radius: 3)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .heavy))
                .tracking(1.4)
                .foregroundColor(.retroPink)
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.black.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.retroPurple.opacity(0.4), Color.retroPink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

/// Row displaying CloudKit record details — retrowave restyle.
struct CloudKitRecordDetailRow: View {
    let record: CloudKitRecordDetail
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.recordName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(record.recordID)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.retroBlue)
                        .shadow(color: .retroBlue.opacity(0.5), radius: 3)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(record.fields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.uppercased())
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.8)
                                .foregroundColor(.retroPink)
                            Text(value)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.white.opacity(0.9))
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
                .padding(.top, 4)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.retroDarkBlue.opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.retroBlue.opacity(0.25), lineWidth: 1)
        )
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
                    self.accountStatusColor = .retroGreen
                case .noAccount:
                    self.accountStatus = "No iCloud Account"
                    self.accountStatusColor = .retroOrange
                case .restricted:
                    self.accountStatus = "Restricted"
                    self.accountStatusColor = .retroOrange
                case .couldNotDetermine:
                    self.accountStatus = "Could Not Determine"
                    self.accountStatusColor = .retroOrange
                case .temporarilyUnavailable:
                    self.accountStatus = "Temporarily Unavailable"
                    self.accountStatusColor = .retroOrange
                @unknown default:
                    self.accountStatus = "Unknown (\(accountStatus.rawValue))"
                    self.accountStatusColor = .gray
                }
            }
        } catch {
            await MainActor.run {
                self.accountStatus = "Error: \(error.localizedDescription)"
                self.accountStatusColor = .retroOrange
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
                    schemaStatusColor = .retroGreen
                    successMessage = "CloudKit schema initialized successfully"
                } else {
                    schemaStatus = "Failed to Initialize"
                    schemaStatusColor = .retroOrange
                    errorMessage = "Failed to initialize CloudKit schema"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                schemaStatus = "Error"
                schemaStatusColor = .retroOrange
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

            // Query each record type (excluding Metadata until deployed to CloudKit)
            let deployedRecordTypes = CloudKitSchema.RecordType.allCases.filter { $0 != .metadata }
            for recordTypeRawValue in deployedRecordTypes.map({ $0.rawValue }) {
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

            // Delete records for each record type (excluding Metadata until deployed to CloudKit)
            let deployedRecordTypes = CloudKitSchema.RecordType.allCases.filter { $0 != .metadata }
            for recordTypeRawValue in deployedRecordTypes.map({ $0.rawValue }) {
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
    NavigationStack {
        CloudKitDiagnosticView()
    }
}
