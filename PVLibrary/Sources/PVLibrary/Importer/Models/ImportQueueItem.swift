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
        case bios, artwork, game, cdRom, unknown, skin, zip
    }

    // Enum to define the possible statuses of each import
    public enum ImportStatus: CustomStringConvertible {
        case conflict  // Indicates additional action needed by user after successful import

        case partial(expectedFiles: [String]) //indicates the item is waiting for associated files before it could be processed
        case processing

        case queued

        case failure(error: Error)

        case success

        public var description: String {
            switch self {
                case .queued: return "Queued"
                case .processing: return "Processing"
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
        
        public var isIdle: Bool {
            switch self {
            case .queued, .processing, .success, .conflict, .partial: return true
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
    public var url: URL
    public var fileType: FileType
    public var systems: [SystemIdentifier] = [] // Can be set to the specific system type
    public var userChosenSystem: (SystemIdentifier)? = nil {
        didSet {
            if userChosenSystem != nil {
                // .processing currently has no associated value, so `status != .processing` is fine with Equatable.
                if status != .processing {
                    // Reset status to queued if it was in conflict or failure state
                    // The previous `if case .conflict = status || case .failure = status` might be tricky for macros.
                    // A switch statement is more explicit.
                    switch status {
                    case .conflict, .failure: // .failure has an associated value, .conflict does not
                        self.status = .queued // Explicit self for clarity within switch
                    default:
                        // Do nothing for other statuses like .success, .queued, .partial, .processing
                        break
                    }
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
