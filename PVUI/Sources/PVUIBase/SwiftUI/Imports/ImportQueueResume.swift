//
//  ImportQueueResume.swift
//  PVUIBase
//

import Foundation
import PVLibrary

/// What the import queue does once the user has picked a system for a stuck item.
public enum ImportSystemSelectionResume: Equatable {
    /// The importer is idle: start it so the item is picked up.
    case startProcessing
    /// The importer is paused: process just the item the user resolved.
    case processItem
    /// The importer is already running and will reach the item itself.
    case nothing

    public init(processingState: ProcessingState) {
        switch processingState {
        case .idle: self = .startProcessing
        case .paused: self = .processItem
        case .processing: self = .nothing
        }
    }
}

public extension GameImporting {
    /// Continues the import after the user chose a system for `item`. Used where no
    /// `ImportStatusDelegate` is available (the tvOS media UI presents the queue without one).
    func resumeAfterSystemSelection(for item: ImportQueueItem) {
        switch ImportSystemSelectionResume(processingState: processingState) {
        case .startProcessing:
            startProcessing()
        case .processItem:
            guard let importer = self as? GameImporter else { return }
            Task { await importer.processItem(item) }
        case .nothing:
            break
        }
    }

    /// Requeues every failed or stalled item and starts processing ("BEGIN").
    func requeueAndStartProcessing() async {
        let queue = await importQueue
        queue.filter { $0.status.canBeRequeued }.forEach { _ = $0.requeue() }
        startProcessing()
    }
}
