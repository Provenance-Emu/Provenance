import UIKit
import XCTest
@testable import PVUIBase

@MainActor
final class MissingROMRecoveryTests: XCTestCase {
    private final class StubRecoverer: MissingROMRecovering {
        var outcome: MissingROMRecoveryOutcome = .declined
        private(set) var requested: [String] = []

        func recover(
            gameMD5: String,
            status: @escaping @MainActor (String) -> Void,
            ask: @escaping @MainActor (MissingROMRecoveryPrompt) async -> MissingROMRecoveryAnswer
        ) async -> MissingROMRecoveryOutcome {
            requested.append(gameMD5)
            return outcome
        }
    }

    override func tearDown() async throws {
        await MainActor.run { MissingROMRecovery.recoverer = nil }
    }

    func testWithoutARecovererNothingIsRestored() async {
        MissingROMRecovery.recoverer = nil
        let restored = await MissingROMRecovery.run(gameMD5: "ABC", title: "Game", on: UIViewController())
        XCTAssertFalse(restored)
    }

    func testRestoredOutcomeLetsTheLaunchGoOn() async {
        let stub = StubRecoverer()
        stub.outcome = .restored
        MissingROMRecovery.recoverer = stub
        let restored = await MissingROMRecovery.run(gameMD5: "ABC", title: "Game", on: UIViewController())
        XCTAssertTrue(restored)
        XCTAssertEqual(stub.requested, ["ABC"])
    }

    func testDeclinedOutcomeEndsTheLaunchQuietly() async {
        let stub = StubRecoverer()
        MissingROMRecovery.recoverer = stub
        let restored = await MissingROMRecovery.run(gameMD5: "ABC", title: "Game", on: UIViewController())
        XCTAssertFalse(restored)
    }

    func testAGameWithoutAnMD5IsNeverAsked() async {
        let stub = StubRecoverer()
        stub.outcome = .restored
        MissingROMRecovery.recoverer = stub
        let restored = await MissingROMRecovery.run(gameMD5: "", title: "Game", on: UIViewController())
        XCTAssertFalse(restored)
        XCTAssertTrue(stub.requested.isEmpty)
    }

    func testNotFoundMessageListsEachGroup() {
        let message = MissingROMRecovery.notFoundMessage(
            asked: ["Mac"], unreachable: ["NAS"], needsSignIn: ["RomM"]
        )
        XCTAssertTrue(message.contains("Asked: Mac"))
        XCTAssertTrue(message.contains("Could not reach: NAS"))
        XCTAssertTrue(message.contains("Needs sign-in: RomM"))
    }

    func testNotFoundMessageSaysWhenNothingWasAvailable() {
        let message = MissingROMRecovery.notFoundMessage(asked: [], unreachable: [], needsSignIn: [])
        XCTAssertTrue(message.contains("No paired device or saved server was found"))
        XCTAssertFalse(message.contains("Asked:"))
    }
}
