//
//  ImportStatus.swift
//  PVLibrary
//
//  Created by David Proskin on 11/3/24.
//

import SwiftUI

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
    public var system: String  // Can be set to the specific system type
    
    // Observable status for individual imports
    public var status: ImportStatus = .queued
    
    public init(url: URL, fileType: FileType = .unknown, system: String = "") {
        self.url = url
        self.fileType = fileType
        self.system = system
    }
}
