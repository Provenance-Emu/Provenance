//
//  ImportQueueResolver.swift
//  PVUIBase
//

import Foundation
import PVLibrary
import PVLogging
import PVSystems

/// What a user can do with an import that got stuck, and how the choice reaches the importer.
/// Shared by the tvOS import queue screens so they cannot drift apart.
public enum ImportQueueResolver {

    /// Whether the user can name a system for an item in this state. Items the importer
    /// could not place (`.failure` when detection found no system, `.conflict` when it
    /// found several, `.partial` while a disc set waits for files) can be re-queued with
    /// a system; an item that is queued, running or done cannot.
    public static func canChooseSystem(status: ImportQueueItem.ImportStatus, fileType: ImportQueueItem.FileType) -> Bool {
        switch fileType {
        case .artwork, .bios, .skin, .patch, .folder:
            return false
        case .game, .cdRom, .unknown, .zip:
            return status.canBeRequeued
        }
    }

    public static func canChooseSystem(for item: ImportQueueItem) -> Bool {
        canChooseSystem(status: item.status, fileType: item.fileType)
    }

    /// The systems to list. A conflict knows its candidates; an item detection could not
    /// place has none, and an empty list would leave the user nothing to pick.
    public static func offeredSystems(candidates: [SystemIdentifier], fallback: [SystemIdentifier]) -> [SystemIdentifier] {
        let source = candidates.isEmpty ? fallback : candidates
        return Array(Set(source)).sorted()
    }

    /// Where `id` sits in `queue`, as the offsets `GameImporting.removeImports(at:)` takes.
    public static func offsets(ofItemWithID id: UUID, in queue: [ImportQueueItem]) -> IndexSet? {
        queue.firstIndex(where: { $0.id == id }).map { IndexSet(integer: $0) }
    }

    /// Removes one item from the importer's queue. The offsets come from the importer's own
    /// queue at the moment of removal, not from a UI snapshot that may have gone stale.
    public static func remove(itemWithID id: UUID, from importer: any GameImporting) async {
        let queue = await importer.importQueue
        guard let offsets = offsets(ofItemWithID: id, in: queue) else {
            WLOG("ImportQueueResolver: item \(id) is no longer in the import queue")
            return
        }
        await importer.removeImports(at: offsets)
    }
}
