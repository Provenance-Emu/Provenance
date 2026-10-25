import Foundation
import XCTest
@testable import PVLibrary

final class ImportQueueClaimTests: XCTestCase {
    func testQueuedCancellationPreventsWorkerClaim() {
        let claim = ImportQueueClaim()
        XCTAssertTrue(claim.cancelPending())
        XCTAssertFalse(claim.claim())
        XCTAssertFalse(claim.cancelPending())
    }

    func testStartedImportCannotBeCancelledOrClaimedTwice() {
        let claim = ImportQueueClaim()
        XCTAssertTrue(claim.claim())
        XCTAssertFalse(claim.cancelPending())
        XCTAssertFalse(claim.claim())
    }

    func testExplicitRetryResetsFinishedItemWithoutResettingActiveImport() {
        let claim = ImportQueueClaim()
        XCTAssertTrue(claim.claim())
        claim.resetForRetry()
        XCTAssertFalse(claim.claim())
        claim.finish()
        XCTAssertFalse(claim.claim())
        claim.resetForRetry()
        XCTAssertTrue(claim.claim())
    }

    func testCancellationAndProcessingRaceHasExactlyOneWinner() {
        final class Results: @unchecked Sendable {
            let lock = NSLock()
            var claimed = false
            var cancelled = false
            func setClaimed(_ value: Bool) { lock.withLock { claimed = value } }
            func setCancelled(_ value: Bool) { lock.withLock { cancelled = value } }
        }
        for _ in 0..<100 {
            let claim = ImportQueueClaim()
            let results = Results()
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global().async { results.setClaimed(claim.claim()); group.leave() }
            group.enter()
            DispatchQueue.global().async { results.setCancelled(claim.cancelPending()); group.leave() }
            group.wait()
            XCTAssertNotEqual(results.claimed, results.cancelled)
            XCTAssertFalse(claim.claim())
        }
    }
}
