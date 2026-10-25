import XCTest
@testable import PVLibrarySharing

@MainActor private final class ReceiverEnvironment {
    var trusted: Set<String> = ["source"]
    var discovered: Set<String> = ["source"]
    var active = true
    var emulating = false
    var catalogs = ["source": ["disc1", "disc2"]]
    var checked: [String] = []
    var copied: [String] = []
    var present: Set<String> = []
    var cancelled = 0
    var pendingCopy: CheckedContinuation<Void, Never>?
    var blockCopy = false
    var failEntries: Set<String> = []
    var scheduled: (@MainActor () -> Void)?

    func make() -> AutomaticLibraryReceiver {
        AutomaticLibraryReceiver(
            catalog: { id in self.checked.append(id); return self.catalogs[id, default: []].map { .init(id: $0) } },
            receive: { _, entry in
                self.copied.append(entry.id)
                if self.failEntries.contains(entry.id) { throw LibrarySharingError.itemUnavailable }
                if self.blockCopy { await withCheckedContinuation { self.pendingCopy = $0 } }
                self.present.insert(entry.id)
            },
            cancel: { self.cancelled += 1 },
            isTrusted: { self.trusted.contains($0) },
            isDiscovered: { self.discovered.contains($0) },
            isActive: { self.active },
            isEmulating: { self.emulating },
            isPresent: { _, item in self.present.contains(item.id) },
            schedule: { _, callback in self.scheduled = callback; return { self.scheduled = nil } }
        )
    }
}

@MainActor final class AutomaticLibraryReceiverTests: XCTestCase {
    private func settle() async { for _ in 0..<100 { await Task.yield() } }

    func testOptInRequiresTrustAndDoesNotPairUnknownPeers() async {
        let environment = ReceiverEnvironment()
        let receiver = environment.make()
        receiver.setEnabled(true, for: "stranger")
        await settle()
        XCTAssertFalse(receiver.enabledPeerIDs.contains("stranger"))
        XCTAssertTrue(environment.checked.isEmpty)
    }

    func testEnabledPeerCopiesMissingEntriesAndSkipsVerifiedLocalEntries() async {
        let environment = ReceiverEnvironment()
        environment.present = ["disc1"]
        let receiver = environment.make()
        receiver.setEnabled(true, for: "source")
        await settle()
        XCTAssertEqual(environment.copied, ["disc2"])
        XCTAssertEqual(receiver.state, .upToDate)
        environment.scheduled?()
        await settle()
        XCTAssertEqual(environment.copied, ["disc2"])
    }

    func testBackgroundAndEmulationPreventWorkUntilForegroundLibraryReturns() async {
        let environment = ReceiverEnvironment()
        environment.active = false
        let receiver = environment.make()
        receiver.setEnabled(true, for: "source")
        await settle()
        XCTAssertTrue(environment.checked.isEmpty)
        environment.active = true
        environment.emulating = true
        receiver.environmentChanged()
        await settle()
        XCTAssertTrue(environment.checked.isEmpty)
        environment.emulating = false
        receiver.environmentChanged()
        await settle()
        XCTAssertEqual(environment.copied, ["disc1", "disc2"])
    }

    func testDisableCancelsWithoutStartingReplacementBeforeDelegateReturns() async {
        let environment = ReceiverEnvironment()
        environment.blockCopy = true
        let receiver = environment.make()
        receiver.setEnabled(true, for: "source")
        await settle()
        XCTAssertEqual(environment.copied, ["disc1"])
        receiver.setEnabled(false, for: "source")
        receiver.setEnabled(true, for: "source")
        await settle()
        XCTAssertEqual(environment.copied, ["disc1"])
        XCTAssertGreaterThan(environment.cancelled, 0)
        receiver.stop()
        environment.pendingCopy?.resume()
        environment.pendingCopy = nil
        await settle()
        XCTAssertEqual(receiver.state, .waiting)
    }

    func testBlockedEntryDoesNotPreventOtherGamesFromCopying() async {
        let environment = ReceiverEnvironment()
        environment.failEntries = ["disc1"]
        let receiver = environment.make()
        receiver.setEnabled(true, for: "source")
        await settle()
        XCTAssertEqual(environment.copied, ["disc1", "disc2"])
        XCTAssertEqual(environment.present, ["disc2"])
        guard case .failed = receiver.state else { return XCTFail("blocked entry must remain visible") }
    }

    func testRemovedRemoteEntryNeverRemovesLocalCopy() async {
        let environment = ReceiverEnvironment()
        let receiver = environment.make()
        receiver.setEnabled(true, for: "source")
        await settle()
        environment.catalogs["source"] = []
        environment.scheduled?()
        await settle()
        XCTAssertEqual(environment.present, ["disc1", "disc2"])
    }

    func testRevocationClearsOptInAndCancelsActiveWork() async {
        let environment = ReceiverEnvironment()
        environment.blockCopy = true
        let receiver = environment.make()
        receiver.setEnabled(true, for: "source")
        await settle()
        environment.trusted = []
        receiver.environmentChanged()
        XCTAssertFalse(receiver.enabledPeerIDs.contains("source"))
        XCTAssertGreaterThan(environment.cancelled, 0)
        environment.pendingCopy?.resume()
        environment.pendingCopy = nil
        await settle()
        XCTAssertEqual(receiver.state, .disabled)
    }
}
