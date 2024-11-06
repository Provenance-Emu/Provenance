//
//  ImportStatus.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//

import SwiftUI
import PVPrimitives

// Enum to define the possible statuses of each import
public enum ImportStatus: String {
    case queued
    case processing
    case success
    case failure
    case conflict  // Indicates additional action needed by user after successful import
    
    public var description: String {
        switch self {
            case .queued: return "Queued"
            case .processing: return "Processing"
            case .success: return "Completed"
            case .failure: return "Failed"
            case .conflict: return "Conflict"
        }
    }
        
    public var color: Color {
        switch self {
            case .queued: return .gray
            case .processing: return .blue
            case .success: return .green
            case .failure: return .red
            case .conflict: return .yellow
        }
    }
}

// Enum to define file types for each import
public enum FileType {
    case bios, artwork, game, cdRom, unknown
}

// Enum to track processing state
public enum ProcessingState {
    case idle
    case processing
}

// ImportItem model to hold each file's metadata and progress
@Observable
public class ImportQueueItem: Identifiable, ObservableObject {
    public let id = UUID()
    public let url: URL
    public var fileType: FileType
    public var systems: [PVSystem]  // Can be set to the specific system type
    public var userChosenSystem: System?
    public var destinationUrl: URL?
    
    // Observable status for individual imports
    public var status: ImportStatus = .queued
    
    public init(url: URL, fileType: FileType = .unknown) {
        self.url = url
        self.fileType = fileType
        self.systems = []
        self.userChosenSystem = nil
    }
    
    public var md5: String? {
        if let cached = cache.md5 {
            return cached
        } else {
            let computed = FileManager.default.md5ForFile(atPath: url.path, fromOffset: 0)
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
    
    public func targetSystem() -> PVSystem? {
        guard !systems.isEmpty else {
            return nil
        }
        
        if (systems.count == 1) {
            return systems.first!
        }
        
        if let chosenSystem = userChosenSystem {
            
            var target:PVSystem? = nil
            
            for system in systems {
                if (chosenSystem.identifier == system.identifier) {
                    target = system
                }
            }
            
            return target
        }
        
        return nil
    }

    private var cache = Cache()
}
