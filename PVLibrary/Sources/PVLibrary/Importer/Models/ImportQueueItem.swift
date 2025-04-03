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
        case bios, artwork, game, cdRom, unknown, skin
    }


    // Enum to define the possible statuses of each import
    public enum ImportStatus: Int, CustomStringConvertible, CaseIterable, Equatable {
        case conflict  // Indicates additional action needed by user after successful import

        case partial //indicates the item is waiting for associated files before it could be processed
        case processing

        case queued

        case failure

        case success

        public var description: String {
            switch self {
                case .queued: return "Queued"
                case .processing: return "Processing"
                case .success: return "Completed"
                case .failure: return "Failed"
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
    }

    public let id = UUID()
    public var url: URL
    public var fileType: FileType
    public var systems: [SystemIdentifier] = [] // Can be set to the specific system type
    public var userChosenSystem: (SystemIdentifier)? = nil {
        didSet {
            if userChosenSystem != nil && status != .processing {
                // Reset status to queued if it was in conflict or failure state
                if status == .conflict || status == .failure {
                    status = .queued
                }
            }
        }
    }
    public var destinationUrl: URL?
    public var errorValue: String?

    //this is used when a single import has child items - e.g., m3u, cue, directory
    public var childQueueItems: [ImportQueueItem]

    // Observable status for individual imports
    public var status: ImportStatus = .queued {
        didSet {
            if status == .failure {
                updateSystems()
            }
        }
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
            if current == .partial {
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
