//
//  MockGameImporter.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/27/24.
//

import PVSwiftUI
import SwiftUI
import Combine
import PVPrimitives

class MockGameImporter: GameImporting, ObservableObject {
    @Published private(set) var importStatus: String = "Ready"
    @Published var importQueue: [ImportQueueItem] = [
        {
            let item = ImportQueueItem(url: .init(fileURLWithPath: "test.bin"), fileType: .unknown)
            item.systems = [
                PVSystem(identifier: "com.provenance.jaguar", name: "Jaguar", shortName: "Jag", manufacturer: "Atari", screenType: .crt),
                PVSystem(identifier: "com.provenance.jaguarcd", name: "Jaguar CD", shortName: "JagCD", manufacturer: "Atari", screenType: .crt)
            ]
            return item
        }(),
        ImportQueueItem(url: .init(fileURLWithPath: "test.jpg"), fileType: .artwork),
        ImportQueueItem(url: .init(fileURLWithPath: "bios.bin"), fileType: .bios),
        ImportQueueItem(url: .init(fileURLWithPath: "test.cue"), fileType: .cdRom),
        ImportQueueItem(url: .init(fileURLWithPath: "test.jag"), fileType: .game)
    ]
    @Published private(set) var processingState: ProcessingState = .idle

    func initSystems() async {
        // Mock implementation - no real systems to initialize
        importStatus = "Systems initialized"
    }

    func addImport(_ item: ImportQueueItem) {
        if !importQueueContainsDuplicate(importQueue, ofItem: item) {
            importQueue.append(item)
            importStatus = "Added \(item.url.lastPathComponent) to queue"
        }
    }
    
    func addImports(forPaths paths: [URL], targetSystem: AnySystem) {
        for path in paths {
            let item = ImportQueueItem(url: path, fileType: .unknown)
            item.userChosenSystem = targetSystem as? PVSystem // TODO: change when generic system types supported
            addImport(item)
        }
        importStatus = "Added \(paths.count) items to queue"
    }


    func addImports(forPaths paths: [URL]) {
        for path in paths {
            let item = ImportQueueItem(url: path, fileType: .unknown)
            addImport(item)
        }
        importStatus = "Added \(paths.count) items to queue"
    }
    
    func removeImports(at offsets: IndexSet) {
        importQueue.remove(atOffsets: offsets)
        importStatus = "Removed \(offsets.count) items from queue"
    }

    func startProcessing() {
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

    func sortImportQueueItems(_ importQueueItems: [ImportQueueItem]) -> [ImportQueueItem] {
        importQueueItems.sorted(by: { $0.url.lastPathComponent < $1.url.lastPathComponent })
    }

    func importQueueContainsDuplicate(_ queue: [ImportQueueItem], ofItem queueItem: ImportQueueItem) -> Bool {
        queue.contains(where: { $0.url == queueItem.url })
    }
    
    var importStartedHandler: GameImporterImportStartedHandler? = nil
    /// Closure called when import completes
    var completionHandler: GameImporterCompletionHandler? = nil
    /// Closure called when a game finishes importing
    var finishedImportHandler: GameImporterFinishedImportingGameHandler? = nil
    /// Closure called when artwork finishes downloading
    var finishedArtworkHandler: GameImporterFinishedGettingArtworkHandler? = nil
    
    /// Spotlight Handerls
    /// Closure called when spotlight completes
    var spotlightCompletionHandler: GameImporterCompletionHandler? = nil
    /// Closure called when a game finishes importing
    var spotlightFinishedImportHandler: GameImporterFinishedImportingGameHandler? = nil
    
}
