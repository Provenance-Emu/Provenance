import XCTest
@testable import PVLibrarySharing

private actor ReceiveProbe {
    var entered: [Int] = []
    var continuation: CheckedContinuation<Void, Never>?
    func block() async -> Int {
        entered.append(1)
        await withCheckedContinuation { continuation = $0 }
        return 1
    }
    func enter() -> Int { entered.append(2); return 2 }
    func release() { continuation?.resume(); continuation = nil }
}

final class LibraryReceiveSerialExecutorTests: XCTestCase {
    func testQueuedCancellationCompletesBeforeActiveDelegate() async throws {
        let executor = LibraryReceiveSerialExecutor()
        let probe = ReceiveProbe()
        let first = Task { try await executor.withPermit { await probe.block() } }
        for _ in 0..<10000 {
            if !(await probe.entered).isEmpty { break }
            await Task.yield()
        }
        let second = Task { try await executor.withPermit { await probe.enter() } }
        for _ in 0..<100 { await Task.yield() }
        second.cancel()
        do { _ = try await second.value; XCTFail("Queued cancellation returned success") } catch is CancellationError {}
        let entered = await probe.entered
        XCTAssertEqual(entered, [1])
        await probe.release()
        let result = try await first.value
        XCTAssertEqual(result, 1)
    }

    func testCancelledOwnerHoldsLeaseUntilDelegateReturns() async throws {
        let executor = LibraryReceiveSerialExecutor()
        let probe = ReceiveProbe()
        let first = Task { try await executor.withPermit { await probe.block() } }
        for _ in 0..<10000 {
            if !(await probe.entered).isEmpty { break }
            await Task.yield()
        }
        first.cancel()
        let second = Task { try await executor.withPermit { await probe.enter() } }
        for _ in 0..<100 { await Task.yield() }
        let before = await probe.entered
        XCTAssertEqual(before, [1])
        await probe.release()
        do { _ = try await first.value; XCTFail("Cancelled owner returned success") } catch is CancellationError {}
        let result = try await second.value
        XCTAssertEqual(result, 2)
    }
}
