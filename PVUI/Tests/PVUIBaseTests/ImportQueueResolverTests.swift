//
//  ImportQueueResolverTests.swift
//  PVUIBaseTests
//

import Foundation
import Testing
import PVLibrary
import PVSystems
@testable import PVUIBase

// MARK: - ImportQueueResolver Tests

@Suite("ImportQueueResolver")
struct ImportQueueResolverTests {

    private struct Stuck: Error {}

    private func item(_ name: String, type: ImportQueueItem.FileType = .game) -> ImportQueueItem {
        ImportQueueItem(url: URL(fileURLWithPath: "/tmp/\(name)"), fileType: type)
    }

    @Test("Items the importer could not place can be given a system")
    func stuckItemsOfferASystem() {
        #expect(ImportQueueResolver.canChooseSystem(status: .failure(error: Stuck()), fileType: .game))
        #expect(ImportQueueResolver.canChooseSystem(status: .failure(error: Stuck()), fileType: .unknown))
        #expect(ImportQueueResolver.canChooseSystem(status: .conflict, fileType: .cdRom))
        #expect(ImportQueueResolver.canChooseSystem(status: .partial(expectedFiles: ["Track02.bin"]), fileType: .cdRom))
    }

    @Test("Items that are queued, running or done offer no system")
    func activeItemsOfferNoSystem() {
        #expect(!ImportQueueResolver.canChooseSystem(status: .queued, fileType: .game))
        #expect(!ImportQueueResolver.canChooseSystem(status: .processing, fileType: .game))
        #expect(!ImportQueueResolver.canChooseSystem(status: .extracting, fileType: .zip))
        #expect(!ImportQueueResolver.canChooseSystem(status: .success, fileType: .game))
    }

    @Test("Files that never belong to one system offer none even when stuck")
    func nonGameFilesOfferNoSystem() {
        for type in [ImportQueueItem.FileType.bios, .artwork, .skin, .patch, .folder] {
            #expect(!ImportQueueResolver.canChooseSystem(status: .conflict, fileType: type))
            #expect(!ImportQueueResolver.canChooseSystem(status: .failure(error: Stuck()), fileType: type))
        }
    }

    @Test("A conflict lists its own candidates, sorted")
    func conflictListsItsCandidates() {
        let offered = ImportQueueResolver.offeredSystems(candidates: [.AtariJaguarCD, .AtariJaguar], fallback: [.DOS])
        #expect(offered == [SystemIdentifier.AtariJaguarCD, .AtariJaguar].sorted())
        #expect(!offered.contains(.DOS))
    }

    @Test("An item with no candidates falls back to every system rather than an empty list")
    func unidentifiedItemFallsBackToAllSystems() {
        let offered = ImportQueueResolver.offeredSystems(candidates: [], fallback: [.N64, .DOS, .N64])
        #expect(offered == [SystemIdentifier.N64, .DOS].sorted())
    }

    @Test("Offsets come from the item's id, not its position in a stale snapshot")
    func offsetsFollowTheItem() {
        let first = item("a.bin")
        let second = item("b.bin")
        let third = item("c.bin")
        let queue = [first, second, third]

        #expect(ImportQueueResolver.offsets(ofItemWithID: third.id, in: queue) == IndexSet(integer: 2))
        #expect(ImportQueueResolver.offsets(ofItemWithID: first.id, in: queue) == IndexSet(integer: 0))
        #expect(ImportQueueResolver.offsets(ofItemWithID: first.id, in: [second, third]) == nil)
        #expect(ImportQueueResolver.offsets(ofItemWithID: UUID(), in: queue) == nil)
    }
}
