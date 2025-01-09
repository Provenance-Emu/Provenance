//
//  MockGameImporter.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/27/24.
//

#if DEBUG
import PVSwiftUI
import SwiftUI
import Combine
import PVPrimitives
import PVSystems

public
class MockGameImporter: GameImporting, ObservableObject {
    @Published private(set) public var importStatus: String = "Ready"
    @Published public var importQueue: [ImportQueueItem] = []
    @Published private(set) public var processingState: ProcessingState = .idle

    @MainActor
    public init(importStatus: String = "", importQueue: [ImportQueueItem] = [], processingState: ProcessingState = .idle, importStartedHandler: GameImporterImportStartedHandler? = nil, completionHandler: GameImporterCompletionHandler? = nil, finishedImportHandler: GameImporterFinishedImportingGameHandler? = nil, finishedArtworkHandler: GameImporterFinishedGettingArtworkHandler? = nil, spotlightCompletionHandler: GameImporterCompletionHandler? = nil, spotlightFinishedImportHandler: GameImporterFinishedImportingGameHandler? = nil) {
        self.importStatus = importStatus
        self.importQueue = importQueue
        self.processingState = processingState
        self.importStartedHandler = importStartedHandler
        self.completionHandler = completionHandler
        self.finishedImportHandler = finishedImportHandler
        self.finishedArtworkHandler = finishedArtworkHandler
        self.spotlightCompletionHandler = spotlightCompletionHandler
        self.spotlightFinishedImportHandler = spotlightFinishedImportHandler
        
        if self.importQueue.isEmpty {
            self.importQueue = [{
                let item = ImportQueueItem(url: .init(fileURLWithPath: "test.bin"), fileType: .unknown)
                item.systems = [
                    .AtariJaguar, .AtariJaguarCD
                ]
                return item
            }(),
            ImportQueueItem(url: .init(fileURLWithPath: "test.jpg"), fileType: .artwork),
            ImportQueueItem(url: .init(fileURLWithPath: "bios.bin"), fileType: .bios),
            ImportQueueItem(url: .init(fileURLWithPath: "test.cue"), fileType: .cdRom),
            ImportQueueItem(url: .init(fileURLWithPath: "test.jag"), fileType: .game)
            ]
        }
    }
    
    public func initSystems() async {
        // Mock implementation - no real systems to initialize
        importStatus = "Systems initialized"
    }

    public func addImport(_ item: ImportQueueItem) {
        if !importQueueContainsDuplicate(importQueue, ofItem: item) {
            importQueue.append(item)
            importStatus = "Added \(item.url.lastPathComponent) to queue"
        }
    }
    
    @MainActor
    public func addImports(forPaths paths: [URL], targetSystem: SystemIdentifier) {
        for path in paths {
            let item = ImportQueueItem(url: path, fileType: .unknown)
            item.userChosenSystem = targetSystem // TODO: change when generic system types supported
            addImport(item)
        }
        importStatus = "Added \(paths.count) items to queue"
    }


    public func addImports(forPaths paths: [URL]) {
        for path in paths {
            let item = ImportQueueItem(url: path, fileType: .unknown)
            addImport(item)
        }
        importStatus = "Added \(paths.count) items to queue"
    }
    
    public func removeImports(at offsets: IndexSet) {
        importQueue.remove(atOffsets: offsets)
        importStatus = "Removed \(offsets.count) items from queue"
    }

    public func startProcessing() {
        guard !importQueue.isEmpty else {
            importStatus = "No items in queue"
            return
        }
        
        processingState = .processing
        
        // Simulate processing by marking all items as successful after a delay
        Task {
            importStatus = "Processing \(importQueue.count) items..."
            
            // Simulate some processing time
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            for index in importQueue.indices {
                importQueue[index].status = ImportStatus(rawValue: index % ImportStatus.allCases.count)!
            }
            
            processingState = .idle
            importStatus = "Completed processing \(importQueue.count) items"
        }
    }

    public func sortImportQueueItems(_ importQueueItems: [ImportQueueItem]) -> [ImportQueueItem] {
        importQueueItems.sorted(by: { $0.url.lastPathComponent < $1.url.lastPathComponent })
    }

    public func importQueueContainsDuplicate(_ queue: [ImportQueueItem], ofItem queueItem: ImportQueueItem) -> Bool {
        queue.contains(where: { $0.url == queueItem.url })
    }
    
    public var importStartedHandler: GameImporterImportStartedHandler? = nil
    /// Closure called when import completes
    public var completionHandler: GameImporterCompletionHandler? = nil
    /// Closure called when a game finishes importing
    public var finishedImportHandler: GameImporterFinishedImportingGameHandler? = nil
    /// Closure called when artwork finishes downloading
    public var finishedArtworkHandler: GameImporterFinishedGettingArtworkHandler? = nil
    
    /// Spotlight Handerls
    /// Closure called when spotlight completes
    public var spotlightCompletionHandler: GameImporterCompletionHandler? = nil
    /// Closure called when a game finishes importing
    public var spotlightFinishedImportHandler: GameImporterFinishedImportingGameHandler? = nil
    
    public func clearCompleted() {
        self.importQueue = self.importQueue.filter({
            switch $0.status {
            case .success: return false
            default: return true
            }
        })
    }
}
#endif
