//
//  iCloudSyncStatusView.swift
//  PVUI
//
//  Created by Joseph Mattiello on 4/20/25.
//

import SwiftUI
import PVLibrary
import PVSupport
import PVLogging
import PVFileSystem
import PVRealm
import PVSettings
import Defaults
import Combine
import Foundation
import CloudKit

/// A view modifier that applies the appropriate toggle style based on OS version
struct ToggleStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
#if os(tvOS)
        // On tvOS, use default toggle style as SwitchToggleStyle is not available
        content.toggleStyle(DefaultToggleStyle())
#else
        // On iOS, use SwitchToggleStyle with tint
        if #available(iOS 15.0, *) {
            content.toggleStyle(SwitchToggleStyle(tint: .retroPink))
        } else {
            content.toggleStyle(SwitchToggleStyle())
        }
#endif
    }
}

/// View for monitoring iCloud sync status and comparing local vs iCloud files
struct iCloudSyncStatusView: View {
    // MARK: - Properties

    // iCloud sync status
    @Default(.iCloudSyncMode) private var currentiCloudSyncMode
    @Default(.iCloudSync) private var enablediCloudSync

    @State private var iCloudAvailable = false
    @State private var showSyncToggleAlert = false

    // File comparison states
    @State private var isLoading = true
    @State private var localFiles: [String: [URL]] = [:]
    @State private var iCloudFiles: [String: [URL]] = [:]
    @State private var syncDifferences: [SyncDifference] = []

    // Directories to monitor
    private let monitoredDirectories = ["ROMs", "Save States", "BIOS", "DeltaSkins", "Battery States", "Screenshots", "RetroArch"]

    // Debug information
    @State private var showDebugInfo = false
    @State private var iCloudDiagnostics = ""
    @State private var entitlementInfo = ""
    @State private var infoPlistInfo = ""
    @State private var refreshInfo = ""

    // CloudKit record counts
    @State private var cloudKitRecords = CloudKitRecordCounts(roms: 0, saveStates: 0, bios: 0, batteryStates: 0, screenshots: 0, deltaSkins: 0)
    @State private var isLoadingCloudKitRecords = false

    // Sync status for each domain
    @State private var syncingDomains: Set<String> = []

    // Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Color.retroDarkBlue.edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 20) {
                // Header with status
                statusHeader

                // Debug toggle
                Toggle("Show Diagnostics", isOn: $showDebugInfo)
                    .modifier(ToggleStyleModifier())
                    .foregroundColor(.white)
                    .padding(.horizontal)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Debug information section
                        if showDebugInfo {
                            debugInfoSection
                        }

                        // CloudKit Sync Analytics
                        CloudKitSyncAnalyticsView()
                            .padding(.horizontal)

                        // CloudKit record counts
                        cloudKitRecordsSection(records: cloudKitRecords, isLoading: isLoadingCloudKitRecords, onRefresh: fetchCloudKitRecordCounts)

                        // Sync differences
                        if !isLoading {
                            syncDifferencesSection
                        } else {
                            loadingView
                        }
                    }
                }

                Spacer()
            }
            .padding()

            // Loading overlay
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                    .scaleEffect(1.5)
                    .frame(width: 100, height: 100)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
            }
        }
        .navigationTitle("iCloud Sync Status")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.retroBlue)
                }
            }
        }
        .onAppear {
            checkiCloudAvailability()
            refreshData()
        }
        .alert(isPresented: $showSyncToggleAlert) {
            Alert(
                title: Text("iCloud Sync Changed"),
                message: Text("iCloud sync mode has been changed to \(currentiCloudSyncMode.description). This may require restarting the app for all changes to take effect."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - UI Components

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("iCloud Sync Status")
                    .font(.title2)
                    .foregroundColor(.retroPink)

                Spacer()

                // Refresh button
                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise.circle")
                        .font(.title2)
                        .foregroundColor(.retroBlue)
                }
#if os(tvOS)
                .buttonStyle(CardButtonStyle())
#endif
            }

            // iCloud Sync Settings
            VStack(alignment: .leading, spacing: 12) {
                // iCloud Sync Toggle
                HStack {
                    Text("iCloud Sync")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding<Bool>(
                        get: { Defaults[.iCloudSync] },
                        set: { handleSyncToggleChange($0) }
                    ))
                    .modifier(ToggleStyleModifier())
                }
                
                // Only show sync mode picker if sync is enabled
                if Defaults[.iCloudSync] {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sync Mode")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Picker("Sync Mode", selection: $currentiCloudSyncMode) {
                            ForEach(iCloudSyncMode.allCases, id: \.self) { mode in
                                HStack {
                                    Text(mode.description)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text(mode.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                                .tag(mode)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: currentiCloudSyncMode) { newMode in
                            handleSyncModeChange(newMode)
                        }
                        .foregroundColor(.white)
                        .accentColor(.retroPink)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal)

            // Status indicators
            HStack {
                Image(systemName: iCloudAvailable ? "checkmark.circle" : "xmark.circle")
                    .foregroundColor(iCloudAvailable ? .green : .red)
                Text("iCloud Available: \(iCloudAvailable ? "Yes" : "No")")
                    .foregroundColor(.white)
            }

            Divider()
                .background(Color.retroPurple)
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                .scaleEffect(1.5)
                .padding()

            Text("Scanning files...")
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var syncDifferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync Differences")
                .font(.title2)
                .foregroundColor(.retroPink)

            if syncDifferences.isEmpty {
                Text("All files are in sync")
                    .foregroundColor(.retroBlue)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(monitoredDirectories, id: \.self) { directory in
                    let dirDifferences = syncDifferences.filter { $0.directory == directory }
                    if !dirDifferences.isEmpty {
                        directorySection(directory, differences: dirDifferences)
                    }
                }
            }
        }
    }

    private func directorySection(_ directory: String, differences: [SyncDifference]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(directory)
                .font(.headline)
                .foregroundColor(.retroBlue)
                .padding(.top, 8)

            ForEach(differences) { difference in
                HStack {
                    Image(systemName: difference.type.iconName)
                        .foregroundColor(difference.type.color)

                    VStack(alignment: .leading) {
                        Text(difference.filename)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(difference.type.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    if difference.type == .missingInCloud {
                        Button(action: {
                            syncFileToiCloud(difference)
                        }) {
                            Text("Sync")
                                .foregroundColor(.retroPink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(8)
                        }
                    } else if difference.type == .missingLocally {
                        Button(action: {
                            syncFileFromiCloud(difference)
                        }) {
                            Text("Download")
                                .foregroundColor(.retroBlue)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.black.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Methods

    /// Handle changes to the sync mode
    private func handleSyncModeChange(_ newMode: iCloudSyncMode) {
        DLOG("iCloud sync mode changed to: \(newMode.description)")
        
        // Refresh data to reflect the new sync mode
        refreshData()
        
        // Show a message about the change
        let message = "Sync mode changed to \(newMode.description). \(newMode.subtitle)"
        ILOG("\(message)")
        
        // Show the alert with the change message
        showSyncToggleAlert = true
    }

    /// Handle changes to the iCloud sync toggle
    private func handleSyncToggleChange(_ newValue: Bool) {
        DLOG("iCloud sync setting changed to: \(newValue)")

        // Show alert about the change
        showSyncToggleAlert = true
        
        // If turning off sync, refresh the UI
        if !newValue {
            refreshData()
        }

        // Refresh data to update UI
        refreshData()
    }

    private func checkiCloudAvailability() {
        let token = FileManager.default.ubiquityIdentityToken
        iCloudAvailable = token != nil

        // Get container identifier from Info.plist
        let containerID = Bundle.main.object(forInfoDictionaryKey: "NSUbiquitousContainerIdentifier") as? String ?? "No container identifier"
        DLOG("""
        [iCloudSyncStatusView] iCloud Container Diagnostics:
        -------------------------------------
        ubiquityIdentityToken: \(token != nil ? "Available" : "NIL")
        Attempted to access: \(containerID)
        -------------------------------------
        """)

        // Build diagnostics string for UI display
        iCloudDiagnostics = """
        iCloud Diagnostics:
        -------------------------------------
        ubiquityIdentityToken: \(token != nil ? "Available" : "NIL")
        Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")
        iCloud Container URL: \(URL.iCloudContainerDirectory?.path ?? "NIL")
        iCloud Container Identifier: \(containerID)
        Documents Directory: \(URL.documentsDirectory.path)
        #if os(tvOS)
        Caches Directory: \(URL.cachesDirectory.path)
        #endif
        iCloud Sync Setting: \(Defaults[.iCloudSync])
        -------------------------------------
        """

        // Detailed debug logging
        DLOG("[iCloudSyncStatusView] \(iCloudDiagnostics)")

        // Check entitlements
        checkEntitlements()

        // Check Info.plist for iCloud keys
        checkInfoPlistForICloudKeys()
    }

    /// Check app entitlements to help diagnose iCloud issues
    private func checkEntitlements() {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            let message = "No embedded.mobileprovision found - this is normal for App Store builds"
            entitlementInfo = message
            DLOG("[iCloudSyncStatusView] \(message)")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let dataAsString = String(data: data, encoding: .ascii) ?? ""

            // Check for iCloud entitlements
            let hasICloudEntitlement = dataAsString.contains("com.apple.developer.icloud-container-identifiers") ||
            dataAsString.contains("com.apple.developer.ubiquity-container-identifiers")

            let hasDocumentsEntitlement = dataAsString.contains("com.apple.developer.icloud-services") &&
            dataAsString.contains("CloudDocuments")

            let hasKVSEntitlement = dataAsString.contains("com.apple.developer.ubiquity-kvstore-identifier")

            // Try to extract the container identifier
            var containerIdentifier = "Not found"
            if let range = dataAsString.range(of: "com.apple.developer.icloud-container-identifiers") {
                let startIndex = range.upperBound
                if let endRange = dataAsString[startIndex...].range(of: "</array>") {
                    let identifierSection = dataAsString[startIndex..<endRange.lowerBound]
                    if let stringRange = identifierSection.range(of: "<string>"),
                       let endStringRange = identifierSection[stringRange.upperBound...].range(of: "</string>") {
                        containerIdentifier = String(identifierSection[stringRange.upperBound..<endStringRange.lowerBound])
                    }
                }
            }

            // Build entitlement info string for UI display
            entitlementInfo = """
            Entitlement Check:
            -------------------------------------
            Has iCloud Container Entitlement: \(hasICloudEntitlement)
            Has iCloud Documents Entitlement: \(hasDocumentsEntitlement)
            Has KVS Entitlement: \(hasKVSEntitlement)
            Container Identifier in Entitlements: \(containerIdentifier)
            -------------------------------------
            """

            DLOG("[iCloudSyncStatusView] \(entitlementInfo)")
        } catch {
            entitlementInfo = "Error reading embedded.mobileprovision: \(error)"
            DLOG("[iCloudSyncStatusView] \(entitlementInfo)")

        }
    }

    /// Check Info.plist for iCloud keys
    private func checkInfoPlistForICloudKeys() {
        let bundle = Bundle.main

        // Check for iCloud keys in Info.plist
        let ubiquityContainerIdentifiers = bundle.object(forInfoDictionaryKey: "NSUbiquitousContainers") as? [String: Any]
        let ubiquityKVStoreIdentifier = bundle.object(forInfoDictionaryKey: "NSUbiquitousKeyValueStoreCompletionHandler") as? String

        // Build Info.plist info string for UI display
        infoPlistInfo = """
        Info.plist iCloud Keys:
        -------------------------------------
        NSUbiquitousContainers: \(ubiquityContainerIdentifiers != nil ? "Present" : "Not found")
        NSUbiquitousKeyValueStore: \(ubiquityKVStoreIdentifier != nil ? "Present" : "Not found")
        -------------------------------------
        """

        DLOG("[iCloudSyncStatusView] \(infoPlistInfo)")

        // Try to get more details about the container configuration
        if let containers = ubiquityContainerIdentifiers {
            var containerDetails = "\nContainer Details:\n"
            for (identifier, config) in containers {
                containerDetails += "\n\(identifier): \(config)"
                DLOG("[iCloudSyncStatusView] Container \(identifier) configuration: \(config)")
            }
            infoPlistInfo += containerDetails
        }
    }

    private func refreshData() {
        isLoading = true
        localFiles = [:]
        iCloudFiles = [:]
        syncDifferences = []

        // Fetch CloudKit record counts
        fetchCloudKitRecordCounts()

        // Log refresh action
        DLOG("Refreshing iCloud sync data and CloudKit record counts")

        // Build refresh info string for UI display
        refreshInfo = """
        Refresh Information:
        -------------------------------------
        Platform: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        Device: \(UIDevice.current.model)
        Monitored Directories: \(monitoredDirectories)
        iCloud Available: \(iCloudAvailable)
        iCloud Sync Mode: \(currentiCloudSyncMode.description)
        -------------------------------------
        """

        // Log current state before refresh
        DLOG("[iCloudSyncStatusView] Starting Refresh:\n\(refreshInfo)")

        // Scan local directories
        for directory in monitoredDirectories {
            scanLocalDirectory(directory) { [self] files in
                self.localFiles[directory] = files

                // Check if all directories have been scanned
                if self.localFiles.keys.count == self.monitoredDirectories.count {
                    self.scanICloudDirectories()
                }
            }
        }
    }

    private func scanICloudDirectories() {
        // Only scan iCloud if enabled and available
        if !enablediCloudSync || !iCloudAvailable {
            DLOG("[iCloudSyncStatusView] Skipping iCloud scan - iCloud sync is disabled or unavailable")
            DLOG("[iCloudSyncStatusView] iCloudSyncMode=\(currentiCloudSyncMode.description), iCloudAvailable=\(iCloudAvailable)")

            // Set empty arrays for iCloud files
            for directory in monitoredDirectories {
                iCloudFiles[directory] = []
            }

            // Compare files with empty iCloud arrays
            DispatchQueue.main.async { [self] in
                compareFiles()
                isLoading = false
            }
            return
        }

        // Add this information to the refresh info for display
        refreshInfo += "\n\nScanning iCloud directories: \(monitoredDirectories.joined(separator: ", "))"

        // Create a dispatch group to wait for all scans to complete
        let group = DispatchGroup()

        // Scan iCloud directories
        for directory in monitoredDirectories {
            group.enter()
            scanCloudDirectory(directory) { files in
                self.iCloudFiles[directory] = files
                group.leave()
            }
        }

        // When all scans complete, compare files
        group.notify(queue: .main) { [self] in
            compareFiles()
            isLoading = false
        }
    }

    private func scanLocalDirectory(_ directory: String, completion: @escaping ([URL]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
#if os(tvOS)
            let documentsPath = URL.cachesDirectory
#else
            let documentsPath = URL.documentsDirectory
#endif
            let directoryPath = documentsPath.appendingPathComponent(directory)

            DLOG("[iCloudSyncStatusView] Scanning local directory: \(directoryPath.path)")

            do {
                // Create directory if it doesn't exist
                if !FileManager.default.fileExists(atPath: directoryPath.path) {
                    try FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: true)
                    DLOG("[iCloudSyncStatusView] Created local directory: \(directoryPath.path)")
                }

                let files = try FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil)
                DLOG("[iCloudSyncStatusView] Found \(files.count) files in local directory: \(directory)")

                // Log some file details if there are files
                if !files.isEmpty {
                    let fileDetails = files.prefix(3).map { file -> String in
                        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                        let size = attributes?[.size] as? Int ?? 0
                        return "\(file.lastPathComponent) (\(size) bytes)"
                    }.joined(separator: ", ")

                    let moreFilesMessage = files.count > 3 ? " and \(files.count - 3) more..." : ""
                    DLOG("[iCloudSyncStatusView] Sample local files: \(fileDetails)\(moreFilesMessage)")
                }

                DispatchQueue.main.async {
                    completion(files)
                }
            } catch {
                ELOG("Error scanning local directory \(directory): \(error)")
                // Log more details about the error
                if let nsError = error as NSError? {
                    DLOG("[iCloudSyncStatusView] Error details: domain=\(nsError.domain), code=\(nsError.code)")
                }
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    /// Scans an iCloud directory for files
    private func scanCloudDirectory(_ directory: String, completion: @escaping ([URL]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let iCloudURL = URL.iCloudContainerDirectory else {
                ELOG("[iCloudSyncStatusView] iCloud container directory is nil")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }

            let directoryPath = iCloudURL.appendingPathComponent(directory)

            DLOG("[iCloudSyncStatusView] Scanning iCloud directory: \(directoryPath.path)")

            do {
                // Create directory if it doesn't exist
                if !FileManager.default.fileExists(atPath: directoryPath.path) {
                    try FileManager.default.createDirectory(at: directoryPath, withIntermediateDirectories: true)
                    DLOG("[iCloudSyncStatusView] Created iCloud directory: \(directoryPath.path)")
                }

                let files = try FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil)
                DLOG("[iCloudSyncStatusView] Found \(files.count) files in iCloud directory: \(directory)")

                // Log some file details if there are files
                if !files.isEmpty {
                    let fileDetails = files.prefix(3).map { file -> String in
                        let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
                        let size = attributes?[.size] as? Int ?? 0

                        // Check download status using the non-deprecated API
                        let resourceValues = try? file.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                        let downloadStatus = resourceValues?.ubiquitousItemDownloadingStatus
                        let isDownloaded = downloadStatus == URLUbiquitousItemDownloadingStatus.current

                        return "\(file.lastPathComponent) (\(size) bytes, status: \(downloadStatus?.rawValue ?? "unknown"))"
                    }.joined(separator: ", ")

                    let moreFilesMessage = files.count > 3 ? " and \(files.count - 3) more..." : ""
                    DLOG("[iCloudSyncStatusView] Sample iCloud files: \(fileDetails)\(moreFilesMessage)")
                }

                DispatchQueue.main.async {
                    completion(files)
                }
            } catch {
                ELOG("[iCloudSyncStatusView] Error scanning iCloud directory: \(error.localizedDescription)")
                // Log more details about the error
                if let nsError = error as NSError? {
                    DLOG("[iCloudSyncStatusView] Error details: domain=\(nsError.domain), code=\(nsError.code)")
                }
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }

    private func compareFiles() {
        var differences: [SyncDifference] = []

        for directory in monitoredDirectories {
            let localDirFiles = localFiles[directory] ?? []
            let iCloudDirFiles = iCloudFiles[directory] ?? []

            // Get filenames for comparison
            let localFilenames = Set(localDirFiles.map { $0.lastPathComponent })
            let iCloudFilenames = Set(iCloudDirFiles.map { $0.lastPathComponent })

            // Files in local but not in iCloud
            let missingInCloud = localFilenames.subtracting(iCloudFilenames)
            for filename in missingInCloud {
                if let localURL = localDirFiles.first(where: { $0.lastPathComponent == filename }) {
                    differences.append(SyncDifference(
                        id: UUID().uuidString,
                        directory: directory,
                        filename: filename,
                        localURL: localURL,
                        iCloudURL: nil,
                        type: .missingInCloud
                    ))
                }
            }

            // Files in iCloud but not in local
            let missingLocally = iCloudFilenames.subtracting(localFilenames)
            for filename in missingLocally {
                if let iCloudURL = iCloudDirFiles.first(where: { $0.lastPathComponent == filename }) {
                    differences.append(SyncDifference(
                        id: UUID().uuidString,
                        directory: directory,
                        filename: filename,
                        localURL: nil,
                        iCloudURL: iCloudURL,
                        type: .missingLocally
                    ))
                }
            }

            // Files that exist in both but might have different sizes/dates
            let commonFilenames = localFilenames.intersection(iCloudFilenames)
            for filename in commonFilenames {
                guard let localURL = localDirFiles.first(where: { $0.lastPathComponent == filename }),
                      let iCloudURL = iCloudDirFiles.first(where: { $0.lastPathComponent == filename }) else {
                    continue
                }

                do {
                    let localAttrs = try FileManager.default.attributesOfItem(atPath: localURL.path)
                    let iCloudAttrs = try FileManager.default.attributesOfItem(atPath: iCloudURL.path)

                    let localSize = localAttrs[.size] as? Int64 ?? 0
                    let iCloudSize = iCloudAttrs[.size] as? Int64 ?? 0

                    let localDate = localAttrs[.modificationDate] as? Date ?? Date.distantPast
                    let iCloudDate = iCloudAttrs[.modificationDate] as? Date ?? Date.distantPast

                    // If sizes differ or dates differ significantly (more than 5 seconds)
                    if localSize != iCloudSize || abs(localDate.timeIntervalSince(iCloudDate)) > 5 {
                        let type: SyncDifferenceType = localDate > iCloudDate ? .newerLocally : .newerInCloud
                        differences.append(SyncDifference(
                            id: UUID().uuidString,
                            directory: directory,
                            filename: filename,
                            localURL: localURL,
                            iCloudURL: iCloudURL,
                            type: type
                        ))
                    }
                } catch {
                    ELOG("Error comparing file attributes for \(filename): \(error)")
                }
            }
        }

        // Sort differences by directory then filename
        syncDifferences = differences.sorted {
            if $0.directory == $1.directory {
                return $0.filename < $1.filename
            }
            return $0.directory < $1.directory
        }
    }

    /// Debug information section
    private var debugInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("iCloud Diagnostics")
                .font(.headline)
                .foregroundColor(.retroPink)

            // iCloud Diagnostics
            VStack(alignment: .leading, spacing: 8) {
                Text(iCloudDiagnostics)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
            }

            // Entitlement Information
            Text("Entitlement Information")
                .font(.headline)
                .foregroundColor(.retroPink)

            Text(entitlementInfo)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)

            // Info.plist Information
            Text("Info.plist Information")
                .font(.headline)
                .foregroundColor(.retroPink)

            Text(infoPlistInfo)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)

            // Refresh Information
            Text("Refresh Information")
                .font(.headline)
                .foregroundColor(.retroPink)

            Text(refreshInfo)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
        }
        .padding()
        .background(Color.retroDarkBlue.opacity(0.7))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func syncFileToiCloud(_ difference: SyncDifference) {
        guard let localURL = difference.localURL,
              let iCloudDocsURL = URL.iCloudDocumentsDirectory else {
            return
        }

        let destinationURL = iCloudDocsURL.appendingPathComponent(difference.directory).appendingPathComponent(difference.filename)

        // Ensure the directory exists
        let directoryURL = destinationURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            // Copy the file
            try FileManager.default.copyItem(at: localURL, to: destinationURL)

            // Refresh data after sync
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.refreshData()
            }
        } catch {
            ELOG("Error syncing file to iCloud: \(error)")
        }
    }

    private func syncFileFromiCloud(_ difference: SyncDifference) {
        guard let iCloudURL = difference.iCloudURL else {
            return
        }

        let documentsPath = URL.documentsDirectory
        let destinationURL = documentsPath.appendingPathComponent(difference.directory).appendingPathComponent(difference.filename)

        // Ensure the directory exists
        let directoryURL = destinationURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

            // Copy the file
            try FileManager.default.copyItem(at: iCloudURL, to: destinationURL)

            // Refresh data after sync
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.refreshData()
            }
        } catch {
            ELOG("Error syncing file from iCloud: \(error)")
        }
    }

    // MARK: - Sync Actions

    /// Force sync for a specific domain
    /// - Parameter domain: The domain to sync
    private func forceSyncDomain(_ domain: String) {
        DLOG("Force syncing domain: \(domain)")

        // Update UI to show syncing status
        Task { @MainActor in
            syncingDomains.insert(domain)
        }

        Task {
            do {
                // Find the appropriate syncer for the domain
                let activeSyncers = CloudKitSyncerStore.shared.activeSyncers

                switch domain {
                case "ROMs":
                    if let syncer = activeSyncers.first(where: { $0 is CloudKitRomsSyncer }) as? CloudKitRomsSyncer {
                        DLOG("Starting force sync for ROMs")
                        // Get all ROMs from Realm
                        let realm = RomDatabase.sharedInstance.realm
                        let games = realm.objects(PVGame.self)

                        var syncCount = 0
                        for game in games {
                            if let localURL = syncer.localURL(for: game), FileManager.default.fileExists(atPath: localURL.path) {
                                // Upload ROM
                                _ = try await syncer.uploadROM(for: game).value
                                syncCount += 1
                            }
                        }
                        DLOG("Completed force sync for \(syncCount) ROMs")
                    }

                case "Save States":
                    if let syncer = activeSyncers.first(where: { $0 is CloudKitSaveStatesSyncer }) as? CloudKitSaveStatesSyncer {
                        DLOG("Starting force sync for Save States")
                        // Get all save states from Realm
                        let realm = RomDatabase.sharedInstance.realm
                        let saveStates = realm.objects(PVSaveState.self)

                        var syncCount = 0
                        for saveState in saveStates {
                            if let localURL = syncer.localURL(for: saveState), FileManager.default.fileExists(atPath: localURL.path) {
                                // Upload save state
                                _ = try await syncer.uploadSaveState(for: saveState).value
                                syncCount += 1
                            }
                        }
                        DLOG("Completed force sync for \(syncCount) save states")
                    }

                case "BIOS":
                    if let syncer = activeSyncers.first(where: { $0 is CloudKitBIOSSyncer }) as? CloudKitBIOSSyncer {
                        DLOG("Starting force sync for BIOS files")
                        // Get all BIOS files from Realm
                        let realm = RomDatabase.sharedInstance.realm
                        let biosFiles = realm.objects(PVBIOS.self)

                        var syncCount = 0
                        for bios in biosFiles {
                            if let file = bios.file, let system = bios.system {
                                let fileName = file.fileName
                                // Construct the relative path including system subdirectory
                                let relativePath = "\(system.identifier)/\(fileName)"

                                // Get the local URL using the system's BIOS directory
                                let localURL = system.biosDirectory.appendingPathComponent(fileName)

                                if FileManager.default.fileExists(atPath: localURL.path) {
                                    DLOG("Uploading BIOS file: \(relativePath)")
                                    // Upload BIOS with the relative path
                                    _ = try await syncer.uploadBIOS(filename: relativePath).value
                                    syncCount += 1
                                } else {
                                    WLOG("BIOS file not found at path: \(localURL.path)")
                                }
                            }
                        }
                        DLOG("Completed force sync for \(syncCount) BIOS files")
                    }

                case "Battery States", "Screenshots", "DeltaSkins":
                    if let syncer = activeSyncers.first(where: { $0 is CloudKitNonDatabaseSyncer }) as? CloudKitNonDatabaseSyncer {
                        DLOG("Starting force sync for \(domain)")

                        // Use the enhanced forceSyncFiles method that handles subdirectories
                        _ = try await syncer.forceSyncFiles(in: domain).value

                        DLOG("Completed force sync for \(domain) files")
                    }

                default:
                    DLOG("Unknown domain: \(domain)")
                }

                // Refresh record counts after sync
                await MainActor.run {
                    fetchCloudKitRecordCounts()
                    // Remove domain from syncing set
                    syncingDomains.remove(domain)
                }
            } catch {
                ELOG("Error during force sync of \(domain): \(error.localizedDescription)")

                // Remove domain from syncing set on error
                await MainActor.run {
                    syncingDomains.remove(domain)
                }
            }
        }
    }

    // MARK: - CloudKit Records Section

    /// CloudKit record counts section
    private func cloudKitRecordsSection(records: CloudKitRecordCounts, isLoading: Bool, onRefresh: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CloudKit Records")
                .font(.headline)
                .foregroundColor(.retroPink)

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .retroBlue))
                    Spacer()
                }
                .frame(height: 100)
                .padding(10)
                .background(Color.retroBlack.opacity(0.7))
                .cornerRadius(8)
            } else {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Database files
                        Group {
                            HStack {
                                Image(systemName: "doc")
                                    .foregroundColor(.retroBlue)
                                Text("ROMs:")
                                    .foregroundColor(.white)
                                Text("\(records.roms)")
                                    .foregroundColor(.retroBlue)
                                    .bold()
                                Spacer()
                                if syncingDomains.contains("ROMs") {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .retroBlue))
                                        .scaleEffect(0.7)
                                } else {
                                    Button(action: { forceSyncDomain("ROMs") }) {
                                        Image(systemName: "arrow.clockwise.circle")
                                            .foregroundColor(.retroBlue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            HStack {
                                Image(systemName: "archivebox")
                                    .foregroundColor(.retroPurple)
                                Text("Save States:")
                                    .foregroundColor(.white)
                                Text("\(records.saveStates)")
                                    .foregroundColor(.retroPurple)
                                    .bold()
                                Spacer()
                                if syncingDomains.contains("Save States") {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .retroPurple))
                                        .scaleEffect(0.7)
                                } else {
                                    Button(action: { forceSyncDomain("Save States") }) {
                                        Image(systemName: "arrow.clockwise.circle")
                                            .foregroundColor(.retroPurple)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundColor(.retroPink)
                                Text("BIOS:")
                                    .foregroundColor(.white)
                                Text("\(records.bios)")
                                    .foregroundColor(.retroPink)
                                    .bold()
                                Spacer()
                                if syncingDomains.contains("BIOS") {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                                        .scaleEffect(0.7)
                                } else {
                                    Button(action: { forceSyncDomain("BIOS") }) {
                                        Image(systemName: "arrow.clockwise.circle")
                                            .foregroundColor(.retroPink)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }

                        Divider()
                            .background(Color.retroPurple)
                            .padding(.vertical, 4)

                        // Non-database files
                        Group {
                            HStack {
                                Image(systemName: "battery.100")
                                    .foregroundColor(.retroBlue)
                                Text("Battery States:")
                                    .foregroundColor(.white)
                                Text("\(records.batteryStates)")
                                    .foregroundColor(.retroBlue)
                                    .bold()
                                Spacer()
                                if syncingDomains.contains("Battery States") {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .retroBlue))
                                        .scaleEffect(0.7)
                                } else {
                                    Button(action: { forceSyncDomain("Battery States") }) {
                                        Image(systemName: "arrow.clockwise.circle")
                                            .foregroundColor(.retroBlue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            HStack {
                                Image(systemName: "photo")
                                    .foregroundColor(.retroPurple)
                                Text("Screenshots:")
                                    .foregroundColor(.white)
                                Text("\(records.screenshots)")
                                    .foregroundColor(.retroPurple)
                                    .bold()
                                Spacer()
                                if syncingDomains.contains("Screenshots") {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .retroPurple))
                                        .scaleEffect(0.7)
                                } else {
                                    Button(action: { forceSyncDomain("Screenshots") }) {
                                        Image(systemName: "arrow.clockwise.circle")
                                            .foregroundColor(.retroPurple)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }

                            HStack {
                                Image(systemName: "paintpalette")
                                    .foregroundColor(.retroPink)
                                Text("Delta Skins:")
                                    .foregroundColor(.white)
                                Text("\(records.deltaSkins)")
                                    .foregroundColor(.retroPink)
                                    .bold()
                                Spacer()
                                if syncingDomains.contains("DeltaSkins") {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .retroPink))
                                        .scaleEffect(0.7)
                                } else {
                                    Button(action: { forceSyncDomain("DeltaSkins") }) {
                                        Image(systemName: "arrow.clockwise.circle")
                                            .foregroundColor(.retroPink)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }

                        Divider()
                            .background(Color.retroPurple)
                            .padding(.vertical, 4)

                        HStack {
                            Image(systemName: "number.circle")
                                .foregroundColor(.retroGreen)
                            Text("Total:")
                                .foregroundColor(.white)
                            Text("\(records.total)")
                                .foregroundColor(.retroGreen)
                                .bold()
                        }
                    }

                    Spacer()

                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20))
                            .foregroundColor(.retroBlue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(10)
                .background(Color.retroBlack.opacity(0.7))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }

    /// Fetch CloudKit record counts
    private func fetchCloudKitRecordCounts() {
        Task {
            do {
                DLOG("Starting CloudKit record count fetch")

                // Set loading state
                await MainActor.run {
                    isLoadingCloudKitRecords = true
                }

                // Check if we have any active syncers
                let activeSyncers = CloudKitSyncerStore.shared.activeSyncers
                DLOG("Total active syncers: \(activeSyncers.count)")

                // Get ROM syncer record count
                var romCount = 0
                let romSyncers = CloudKitSyncerStore.shared.romSyncers
                DLOG("Found \(romSyncers.count) ROM syncers")

                if let cloudKitRomSyncers = romSyncers as? [CloudKitRomsSyncer] {
                    DLOG("Found \(cloudKitRomSyncers.count) CloudKit ROM syncers")
                    for (index, syncer) in cloudKitRomSyncers.enumerated() {
                        DLOG("Fetching record count for ROM syncer \(index + 1)")
                        let count = await syncer.getRecordCount()
                        DLOG("ROM syncer \(index + 1) has \(count) records")
                        romCount += count
                    }
                } else {
                    DLOG("No CloudKit ROM syncers found")
                }

                // Get save state syncer record count
                var saveStateCount = 0
                let saveStateSyncers = CloudKitSyncerStore.shared.saveStateSyncers
                DLOG("Found \(saveStateSyncers.count) save state syncers")

                var biosCount = 0
                var batteryStateCount = 0
                var screenshotCount = 0
                var deltaSkinCount = 0

                // Get ROM count
                if let romSyncer = activeSyncers.first(where: { $0 is CloudKitRomsSyncer }) as? CloudKitRomsSyncer {
                    romCount = await romSyncer.getRecordCount()
                    DLOG("Found \(romCount) ROM records in CloudKit")
                } else {
                    DLOG("No CloudKit ROM syncers found")
                }

                // Get save state count
                if let saveStateSyncer = activeSyncers.first(where: { $0 is CloudKitSaveStatesSyncer }) as? CloudKitSaveStatesSyncer {
                    saveStateCount = await saveStateSyncer.getRecordCount()
                    DLOG("Found \(saveStateCount) save state records in CloudKit")
                } else {
                    DLOG("No CloudKit save state syncers found")
                }

                // Get BIOS count
                if let biosSyncer = activeSyncers.first(where: { $0 is CloudKitBIOSSyncer }) as? CloudKitBIOSSyncer {
                    biosCount = await biosSyncer.getRecordCount()
                    DLOG("Found \(biosCount) BIOS records in CloudKit")
                } else {
                    DLOG("No CloudKit BIOS syncers found")
                }

                // Get non-database file counts
                if let nonDatabaseSyncer = activeSyncers.first(where: { $0 is CloudKitNonDatabaseSyncer }) as? CloudKitNonDatabaseSyncer {
                    // For non-database syncers, we need to filter the records by directory
                    // Get all records first
                    let allRecords = await nonDatabaseSyncer.getAllRecords()

                    // Filter by directory
                    batteryStateCount = allRecords.filter { record in
                        (record["directory"] as? String) == "Battery States"
                    }.count
                    DLOG("Found \(batteryStateCount) battery state records in CloudKit")

                    screenshotCount = allRecords.filter { record in
                        (record["directory"] as? String) == "Screenshots"
                    }.count
                    DLOG("Found \(screenshotCount) screenshot records in CloudKit")

                    deltaSkinCount = allRecords.filter { record in
                        (record["directory"] as? String) == "DeltaSkins"
                    }.count
                    DLOG("Found \(deltaSkinCount) delta skin records in CloudKit")
                } else {
                    DLOG("No CloudKit non-database syncer found")
                }

                DLOG("CloudKit record counts - ROMs: \(romCount), Save States: \(saveStateCount), BIOS: \(biosCount), Battery States: \(batteryStateCount), Screenshots: \(screenshotCount), Delta Skins: \(deltaSkinCount)")

                // Update UI on main thread
                await MainActor.run {
                    cloudKitRecords = CloudKitRecordCounts(
                        roms: romCount,
                        saveStates: saveStateCount,
                        bios: biosCount,
                        batteryStates: batteryStateCount,
                        screenshots: screenshotCount,
                        deltaSkins: deltaSkinCount
                    )
                    isLoadingCloudKitRecords = false
                    DLOG("Updated UI with CloudKit record counts")
                }
            } catch {
                ELOG("Error fetching CloudKit record counts: \(error.localizedDescription)")
                await MainActor.run {
                    isLoadingCloudKitRecords = false
                }
            }
        }
    }
}
// MARK: - Supporting Types

/// Structure to hold CloudKit record counts
struct CloudKitRecordCounts {
    let roms: Int
    let saveStates: Int
    let bios: Int
    let batteryStates: Int
    let screenshots: Int
    let deltaSkins: Int

    var total: Int {
        return roms + saveStates + bios + batteryStates + screenshots + deltaSkins
    }
}

/// Represents a difference between local and iCloud files
struct SyncDifference: Identifiable {
    let id: String
    let directory: String
    let filename: String
    let localURL: URL?
    let iCloudURL: URL?
    let type: SyncDifferenceType
}

/// Types of sync differences
enum SyncDifferenceType {
    case missingInCloud
    case missingLocally
    case newerLocally
    case newerInCloud

    var description: String {
        switch self {
        case .missingInCloud:
            return "File exists locally but not in iCloud"
        case .missingLocally:
            return "File exists in iCloud but not locally"
        case .newerLocally:
            return "Local file is newer than iCloud version"
        case .newerInCloud:
            return "iCloud file is newer than local version"
        }
    }

    var iconName: String {
        switch self {
        case .missingInCloud:
            return "arrow.up.to.line"
        case .missingLocally:
            return "arrow.down.to.line"
        case .newerLocally:
            return "arrow.up.circle"
        case .newerInCloud:
            return "arrow.down.circle"
        }
    }

    var color: Color {
        switch self {
        case .missingInCloud, .newerLocally:
            return .retroPink
        case .missingLocally, .newerInCloud:
            return .retroBlue
        }
    }
}

// MARK: - Preview
struct iCloudSyncStatusView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            iCloudSyncStatusView()
        }
    }
}
