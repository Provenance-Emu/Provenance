//
//  ControllerMappingStoreTests.swift
//  PVCoreBridgeTests
//

@testable import PVCoreBridge
import XCTest

final class ControllerMappingStoreTests: XCTestCase {
    private static let vendor = "Test Pad"

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var store: ControllerMappingStore!

    override func setUp() {
        super.setUp()
        suiteName = "ControllerMappingStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = ControllerMappingStore(defaults: defaults)
    }

    override func tearDown() {
        store = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testAMappingIsSavedAndReadBack() {
        store.setMapping(source: .buttonA, destination: .buttonB, forVendor: Self.vendor)

        XCTAssertEqual(store.destination(forSource: .buttonA, vendor: Self.vendor), .buttonB)
        XCTAssertTrue(store.hasActiveRemaps(forVendor: Self.vendor))
        // A second store reads what the first one saved.
        XCTAssertEqual(ControllerMappingStore(defaults: defaults).destination(forSource: .buttonA, vendor: Self.vendor), .buttonB)
    }

    /// The cached table is dropped when the defaults change underneath it (iCloud, another store).
    func testAChangeMadeElsewhereReplacesTheCachedTable() {
        store.setMapping(source: .buttonA, destination: .buttonB, forVendor: Self.vendor)
        XCTAssertEqual(store.destination(forSource: .buttonA, vendor: Self.vendor), .buttonB)

        ControllerMappingStore(defaults: defaults).clearAll(forVendor: Self.vendor)

        XCTAssertEqual(store.destination(forSource: .buttonA, vendor: Self.vendor), .buttonA)
        XCTAssertFalse(store.hasActiveRemaps(forVendor: Self.vendor))
    }

    /// The emulation thread resolves buttons while the settings screen edits the table.
    func testReadsAndWritesFromManyThreads() {
        let store: ControllerMappingStore = self.store
        let destinations: [ButtonIdentifier] = [.buttonA, .buttonB, .buttonX, .buttonY]

        DispatchQueue.concurrentPerform(iterations: 1_000) { iteration in
            if iteration.isMultiple(of: 5) {
                store.setMappings([.buttonA: ButtonMapping(source: .buttonA, destination: destinations[iteration % destinations.count])],
                                  forVendor: Self.vendor)
            } else {
                XCTAssertTrue(destinations.contains(store.destination(forSource: .buttonA, vendor: Self.vendor)))
            }
        }

        // Once the writes have stopped, the cache and the saved table agree.
        let saved = ControllerMappingStore(defaults: defaults).mappings(forVendor: Self.vendor)
        XCTAssertEqual(store.mappings(forVendor: Self.vendor), saved)
    }
}
