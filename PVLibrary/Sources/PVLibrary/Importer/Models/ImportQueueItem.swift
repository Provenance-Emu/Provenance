//
//  ImportStatus.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//

import SwiftUI
import PVPrimitives
import Perception
import PVSystems
import PVHashing


// ImportItem model to hold each file's metadata and progress
@Perceptible
public class ImportQueueItem: Identifiable, ObservableObject {
    // Enum to track processing state
    public enum ProcessingState {
        case idle
        case processing
    }

    // Enum to define file types for each import
    public enum FileType {
        case bios, artwork, game, cdRom, unknown, skin, zip, folder
    }

    /// Optional explicit MD5 override for this item.
    ///
    /// This is particularly important for `.folder` imports (e.g., MAME),
    /// where hashing the underlying path via `FileHandle(forReadingFrom:)`
    /// will fail because the URL points to a directory rather than a file.
    ///
    /// Higher-level import logic can set this to a stable identifier such as
    /// `systemIdentifier + "/" + folderName`, and MD5-based duplicate checks
    /// should prefer this value when present instead of attempting to hash
    /// the filesystem entry.
    public var md5Override: String?
    // Enum to define the possible statuses of each import
    public enum ImportStatus: CustomStringConvertible {
        case conflict  // Indicates additional action needed by user after successful import

        case partial(expectedFiles: [String]) //indicates the item is waiting for associated files before it could be processed
        case processing
        case extracting  // Indicates archive is being extracted/unarchived

        case queued

        case failure(error: Error)

        case success

        public var description: String {
            switch self {
                case .queued: return "Queued"
                case .processing: return "Processing"
                case .extracting: return "Extracting"
                case .success: return "Completed"
                case .failure(let error): return "Failed: \(error.localizedDescription)"
                case .conflict: return "Conflict"
                case .partial: return "Partial"
            }
        }

        public var color: Color {
            switch self {
                case .queued: return .gray
                case .processing: return .blue
                case .extracting: return .orange
                case .success: return .green
                case .failure: return .red
                case .conflict: return .yellow
                case .partial: return .yellow
            }
        }

        public var isFailure: Bool {
            if case .failure = self {
                return true
            }
            return false
        }

        public var isSuccess: Bool {
            if case .success = self {
                return true
            }
            return false
        }

        public var isPartial: Bool {
            if case .partial = self {
                return true
            }
            return false
        }

        /// Indicates whether items in this state should block duplicate entries in the queue
        public var blocksDuplicateProcessing: Bool {
            switch self {
            case .queued, .processing, .extracting, .partial:
                return true
            case .success, .failure, .conflict:
                return false
            }
        }

        public var isIdle: Bool {
            switch self {
            case .queued, .processing, .extracting, .success, .conflict, .partial: return true
            default: return false
            }
        }

        public var canBeRequeued: Bool {
            switch self {
            case .failure, .conflict, .partial: return true
            default: return false
            }
        }
    }

    public let id = UUID()
    public var url: URL {
        didSet {
            cachedFileSize = nil
        }
    }
    public var fileType: FileType
    public var systems: [SystemIdentifier] = [] // Can be set to the specific system type
    /// Last system selected by the user, persisted for display even after import completes
    public var resolvedSystem: SystemIdentifier?

    public var userChosenSystem: (SystemIdentifier)? = nil {
        didSet {
            if userChosenSystem != nil {
                // .processing currently has no associated value, so `status != .processing` is fine with Equatable.
                if status != .processing {
                    // Reset status to queued if it was in conflict, failure, or partial state
                    switch status {
                    case .conflict, .failure: // .failure has an associated value, .conflict does not
                        self.status = .queued // Explicit self for clarity within switch
                    case .partial(let expectedFiles):
                        // When user selects a system for a partial item, change to queued
                        // The import process will check if files are resolved and handle accordingly
                        self.status = .queued
                        // Trigger processing restart for newly queued item
                        Task {
                            NotificationCenter.default.post(name: .GameImporterQueueItemRequeued, object: self)
                        }
                    default:
                        // Do nothing for other statuses like .success, .queued, .processing
                        break
                    }
                }

                if let selectedSystem = userChosenSystem {
                    resolvedSystem = selectedSystem
                }
            }
        }
    }
    public var destinationUrl: URL?
    public var errorValue: String?

    /// Filenames (e.g., "Track02.wav") expected to be associated with this import item, often parsed from a manifest like a .cue sheet.
    public var expectedAssociatedFileNames: [String]? = nil
    /// URLs of associated files that have been successfully located and confirmed for this import item.
    public var resolvedAssociatedFileURLs: [URL] = []

    /// The database ID (e.g., PVGame.id) of the game once it has been successfully imported and created.
    public var gameDatabaseID: String? = nil

    //this is used when a single import has child items - e.g., m3u, cue, directory
    public var childQueueItems: [ImportQueueItem]

    // Observable status for individual imports
    public var status: ImportStatus = .queued {
        didSet {
            if case .failure = status {
                updateSystems()
            }
        }
    }

    private var cachedFileSize: Int64?

    public func requeue() -> ImportQueueItem {
        self.status = .queued
        return self
    }

    private func updateSystems() {
        Task { @MainActor in
            systems = PVEmulatorConfiguration.availableSystemIdentifiers
        }
    }

    private let md5Provider: MD5Provider

    public init(url: URL, fileType: FileType = .unknown, md5Provider: MD5Provider = FileManager.default) {
        self.url = url
        self.fileType = fileType
        self.childQueueItems = []
        self.resolvedSystem = nil
        self.md5Provider = md5Provider
        self.expectedAssociatedFileNames = nil // Explicitly set, though default would work
        self.resolvedAssociatedFileURLs = []   // Explicitly set, though default would work
        self.gameDatabaseID = nil            // Explicitly set
    }

    public var md5: String? {
        if let cached = cache.md5 {
            return cached
        } else {
            let computed = md5Provider.md5ForFile(at: url, fromOffset: 0)
            cache.md5 = computed
            return computed
        }
    }

    /// Non-blocking async variant that computes MD5 off the main thread
    public func md5Async() async -> String? {
        if let cached = cache.md5 {
            return cached
        }
        let computed = try? await md5Provider.md5ForFileAsync(at: url, fromOffset: 0)
        cache.md5 = computed
        return computed
    }

    // Store a cache in a nested class.
    // The struct only contains a reference to the class, not the class itself,
    // so the struct cannot prevent the class from mutating.
    private final class Cache: Codable {
        var md5: String?
    }

//    @MainActor
    public func targetSystem() -> SystemIdentifier? {
        guard !systems.isEmpty else {
            return nil
        }

        if (systems.count == 1) {
            return systems.first!
        }

        if let chosenSystem = userChosenSystem {

            var target:SystemIdentifier? = systems.first { systemIdentifier in
                chosenSystem == systemIdentifier
            }

            return target
        }

        return nil
    }

    private var cache = Cache()

    public func fileSize() -> Int64? {
        if let cachedFileSize {
            return cachedFileSize
        }

        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            cachedFileSize = size
            return size
        }

        return nil
    }

    public func invalidateFileSizeCache() {
        cachedFileSize = nil
    }

    public func getStatusForItem() -> ImportStatus {
        guard self.childQueueItems.count > 0 else {
            //if there's no children, just return the status for this item
            return self.status
        }

        var current:ImportStatus = .queued

        for child in self.childQueueItems {
            current = child.getStatusForItem()
            if case .partial = current {
                break
            }
        }

        return current
    }
}

extension ImportQueueItem: Equatable {
    public static func == (lhs: ImportQueueItem, rhs: ImportQueueItem) -> Bool {
        return lhs.url == rhs.url
    }
}

extension ImportQueueItem: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

extension ImportQueueItem.ImportStatus: Equatable {
    public static func == (lhs: ImportQueueItem.ImportStatus, rhs: ImportQueueItem.ImportStatus) -> Bool {
        switch (lhs, rhs) {
        case (.conflict, .conflict):
            return true
        case (.partial, .partial):
            return true
        case (.processing, .processing):
            return true
        case (.extracting, .extracting):
            return true
        case (.queued, .queued):
            return true
        case (.failure(let lhsError), .failure(let rhsError)):
            // Comparing errors can be tricky. For now, let's compare their localized descriptions.
            // This might not be robust for all error types but is a common approach.
            return (lhsError as NSError).domain == (rhsError as NSError).domain && (lhsError as NSError).code == (rhsError as NSError).code && lhsError.localizedDescription == rhsError.localizedDescription
        case (.success, .success):
            return true
        default:
            return false
        }
    }
}
