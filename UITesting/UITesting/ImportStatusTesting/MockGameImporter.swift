//
//  MockGameImporter.swift
//  UITesting
//
//  Created by Joseph Mattiello on 11/27/24.
//

import PVSwiftUI
import SwiftUI

class MockGameImporter: GameImporting {
    func initSystems() async {
        
    }

    var importStatus: String {
        ""
    }

    var importQueue: [ImportQueueItem] = []

    var processingState: ProcessingState = .idle

    func addImport(_ item: ImportQueueItem) {
        
    }
    func addImports(forPaths paths: [URL]) {
        
    }
    
    func removeImports(at offsets: IndexSet) {
        
    }
    func startProcessing() {
        
    }

    func sortImportQueueItems(_ importQueueItems: [ImportQueueItem]) -> [ImportQueueItem] {
        importQueueItems.sorted(by: { $0.url.lastPathComponent < $1.url.lastPathComponent })
    }

    func importQueueContainsDuplicate(_ queue: [ImportQueueItem], ofItem queueItem: ImportQueueItem) -> Bool {
        queue.contains(where: { $0.url == queueItem.url })
    }
}
