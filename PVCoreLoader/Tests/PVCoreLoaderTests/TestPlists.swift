import XCTest
import PVCoreBridge
@testable import PVCoreLoader

#if canImport(PVAtari800)
@_exported import PVAtari800
#endif
#if canImport(PVPicoDrive)
@_exported import PVPicoDrive
#endif
#if canImport(PVPokeMini)
@_exported import PVPokeMini
#endif
#if canImport(PVStella)
@_exported import PVStella
#endif
#if canImport(PVTGBDUal)
@_exported import PVTGBDUal
#endif
#if canImport(PVVirtualJaguar)
@_exported import PVVirtualJaguar
@_exported import PVVirtualJaguarC
@_exported import PVVirtualJaguarSwift
#endif

final class PVCoreLoaderTests: XCTestCase {

    func testVirtualJaguar() throws {
        let jaguarPlist = PVVirtualJaguarSwift.PVJaguarGameCore.corePlist

        XCTAssertNotNil(jaguarPlist)
    }

    func testGetCorePlists() async {
        let corePlists: [EmulatorCoreInfoPlist] = CoreLoader.shared.getCorePlists()

        // Check that the returned array is not empty
        XCTAssertFalse(corePlists.isEmpty, "The corePlists array should not be empty")

        let debugInfo = corePlists.map {
            "\($0.identifier) impliments \($0.supportedSystems.joined(separator: ","))"
        }
        print(debugInfo)
    }

    // MARK: - Thread-safety tests for OSAllocatedUnfairLock migration

    /// Verifies that concurrent reads of getCorePlists() return a consistent result and
    /// do not deadlock — the key regression test for the NSLock early-return bug.
    func testGetCorePlistsConcurrentAccess() {
        CoreLoader.clearCoreListCache()

        let iterations = 50
        var results: [[EmulatorCoreInfoPlist]] = Array(repeating: [], count: iterations)
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            let plists = CoreLoader.getCorePlists()
            lock.withLock { results[index] = plists }
        }

        // All concurrent readers must get the same count
        let firstCount = results[0].count
        for (index, result) in results.enumerated() {
            XCTAssertEqual(
                result.count, firstCount,
                "Concurrent call \(index) returned \(result.count) plists, expected \(firstCount)"
            )
        }
    }

    /// Verifies clearCoreListCache() + getCorePlists() round-trip works correctly
    /// and doesn't leave the lock in a broken state.
    func testClearAndReloadCacheIsIdempotent() {
        let first = CoreLoader.getCorePlists()
        CoreLoader.clearCoreListCache()
        let second = CoreLoader.getCorePlists()

        XCTAssertEqual(
            first.count, second.count,
            "Reloading after cache clear should return the same number of plists"
        )
    }

    /// Stress-tests interleaved clear + read operations from concurrent threads.
    /// If the lock implementation has a deadlock or data-race bug this will hang or crash.
    func testConcurrentClearAndRead() {
        let expectation = self.expectation(description: "concurrent clear and read")
        expectation.expectedFulfillmentCount = 2

        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<20 {
                CoreLoader.clearCoreListCache()
            }
            expectation.fulfill()
        }

        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<20 {
                _ = CoreLoader.getCorePlists()
            }
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10)
    }
}
