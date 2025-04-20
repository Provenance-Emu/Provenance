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

/// View for monitoring iCloud sync status and comparing local vs iCloud files
struct iCloudSyncStatusView: View {
    // MARK: - Properties
    
    // iCloud sync status
    @Default(.iCloudSync) private var iCloudSyncEnabled
    @State private var iCloudAvailable = false
    
    // File comparison states
    @State private var isLoading = true
    @State private var localFiles: [String: [URL]] = [:]
    @State private var iCloudFiles: [String: [URL]] = [:]
    @State private var syncDifferences: [SyncDifference] = []
    
    // Directories to monitor
    private let monitoredDirectories = ["roms", "Saves", "BIOS"]
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Retrowave background
            Color.retroDarkBlue.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with status
                    statusHeader
                    
                    // Sync differences
                    if !isLoading {
                        syncDifferencesSection
                    } else {
                        loadingView
                    }
                }
                .padding()
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
    }
    
    // MARK: - UI Components
    
    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("iCloud Status")
                .font(.title)
                .foregroundColor(.retroPink)
            
            HStack {
                Image(systemName: iCloudSyncEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(iCloudSyncEnabled ? .retroBlue : .retroPink)
                Text("iCloud Sync: \(iCloudSyncEnabled ? "Enabled" : "Disabled")")
                    .foregroundColor(.white)
            }
            
            HStack {
                Image(systemName: iCloudAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(iCloudAvailable ? .retroBlue : .retroPink)
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
    
    private func checkiCloudAvailability() {
        iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
    }
    
    private func refreshData() {
        isLoading = true
        
        // Clear previous data
        localFiles = [:]
        iCloudFiles = [:]
        syncDifferences = []
        
        // Create a dispatch group to wait for all scans to complete
        let group = DispatchGroup()
        
        // Scan local directories
        for directory in monitoredDirectories {
            group.enter()
            scanLocalDirectory(directory) { files in
                self.localFiles[directory] = files
                group.leave()
            }
            
            // Only scan iCloud if enabled and available
            if iCloudSyncEnabled && iCloudAvailable {
                group.enter()
                scanCloudDirectory(directory) { files in
                    self.iCloudFiles[directory] = files
                    group.leave()
                }
            } else {
                iCloudFiles[directory] = []
            }
        }
        
        // When all scans complete, compare files
        group.notify(queue: .main) {
            self.compareFiles()
            self.isLoading = false
        }
    }
    
    private func scanLocalDirectory(_ directory: String, completion: @escaping ([URL]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let documentsPath = URL.documentsDirectory
            let directoryPath = documentsPath.appendingPathComponent(directory)
            
            do {
                // Check if directory exists
                if !FileManager.default.fileExists(atPath: directoryPath.path) {
                    DLOG("Local directory doesn't exist: \(directoryPath.path)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }
                
                // Get all files recursively
                let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                
                // Filter out directories
                let files = fileURLs.filter { url in
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    return !isDirectory.boolValue
                }
                
                DispatchQueue.main.async {
                    completion(files)
                }
            } catch {
                ELOG("Error scanning local directory \(directory): \(error)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    private func scanCloudDirectory(_ directory: String, completion: @escaping ([URL]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let iCloudDocsURL = URL.iCloudDocumentsDirectory else {
                ELOG("iCloud Documents URL is nil")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            let directoryPath = iCloudDocsURL.appendingPathComponent(directory)
            
            do {
                // Check if directory exists
                if !FileManager.default.fileExists(atPath: directoryPath.path) {
                    DLOG("iCloud directory doesn't exist: \(directoryPath.path)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                    return
                }
                
                // Get all files recursively
                let fileURLs = try FileManager.default.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                
                // Filter out directories and .icloud placeholder files
                let files = fileURLs.filter { url in
                    var isDirectory: ObjCBool = false
                    FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    return !isDirectory.boolValue && !url.lastPathComponent.hasSuffix(".icloud")
                }
                
                DispatchQueue.main.async {
                    completion(files)
                }
            } catch {
                ELOG("Error scanning iCloud directory \(directory): \(error)")
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
}

// MARK: - Supporting Types

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
