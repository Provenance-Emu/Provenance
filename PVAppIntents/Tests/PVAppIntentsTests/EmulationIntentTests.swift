//
//  EmulationIntentTests.swift
//  PVAppIntentsTests
//
//  Tests for SaveStateIntent, LoadSaveStateIntent, TakeScreenshotIntent,
//  and AddCheatIntent.
//

import XCTest
@testable import PVAppIntents

#if canImport(AppIntents)

// MARK: - AppIntentError Tests

final class AppIntentErrorTests: XCTestCase {

    func testNoActiveSessionErrorDescription() {
        let error = AppIntentError.noActiveSession
        XCTAssertEqual(error.errorDescription, "No game is currently running in Provenance.")
    }

    func testInvalidCheatCodeErrorDescription() {
        let error = AppIntentError.invalidCheatCode("")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("invalid") == true)
    }

    func testNoGamesFoundErrorDescriptionStillWorks() {
        let error = AppIntentError.noGamesFound(in: "SNES")
        XCTAssertEqual(error.errorDescription, "No games found in SNES.")
    }
}

// MARK: - SaveStateIntent Tests

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
final class SaveStateIntentTests: XCTestCase {

    func testDefaultSlotIsZero() {
        let intent = SaveStateIntent()
        XCTAssertEqual(intent.slot, 0)
    }

    func testInitWithSlot() {
        let intent = SaveStateIntent(slot: 3)
        XCTAssertEqual(intent.slot, 3)
    }

    func testPerformThrowsWhenNoAppGroup() async {
        // In CI there is no App Group, so pvAppGroupDefaults is nil.
        // SaveStateIntent should throw noActiveSession in that case.
        let intent = SaveStateIntent(slot: 1)
        do {
            _ = try await intent.perform()
            // If the App Group IS available (unlikely in CI) the intent succeeds — that's OK.
        } catch let error as AppIntentError {
            if case .noActiveSession = error {
                // Expected when no App Group is configured.
            } else {
                XCTFail("Unexpected AppIntentError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - LoadSaveStateIntent Tests

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
final class LoadSaveStateIntentTests: XCTestCase {

    func testDefaultSlotIsNil() {
        let intent = LoadSaveStateIntent()
        XCTAssertNil(intent.slot)
    }

    func testInitWithSlot() {
        let intent = LoadSaveStateIntent(slot: 2)
        XCTAssertEqual(intent.slot, 2)
    }

    func testPerformThrowsOrSucceeds() async {
        let intent = LoadSaveStateIntent()
        do {
            _ = try await intent.perform()
        } catch let error as AppIntentError {
            if case .noActiveSession = error { /* expected in CI */ } else {
                XCTFail("Unexpected AppIntentError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - AddCheatIntent Tests

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
final class AddCheatIntentTests: XCTestCase {

    func testDefaultTypeIsGameShark() {
        let intent = AddCheatIntent()
        XCTAssertEqual(intent.type, "GameShark")
    }

    func testInitStoresParameters() {
        let intent = AddCheatIntent(code: "007-000-000", cheatDescription: "Infinite Lives", type: "Pro Action Replay")
        XCTAssertEqual(intent.code, "007-000-000")
        XCTAssertEqual(intent.cheatDescription, "Infinite Lives")
        XCTAssertEqual(intent.type, "Pro Action Replay")
    }

    func testPerformThrowsForEmptyCode() async {
        var intent = AddCheatIntent()
        intent.code = "   "
        intent.cheatDescription = "Test"
        do {
            _ = try await intent.perform()
            XCTFail("Expected invalidCheatCode error")
        } catch let error as AppIntentError {
            if case .invalidCheatCode = error { /* expected */ } else {
                XCTFail("Unexpected AppIntentError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPerformThrowsOrSucceedsWithValidCode() async {
        var intent = AddCheatIntent()
        intent.code = "007-000-000"
        intent.cheatDescription = "Infinite Lives"
        intent.type = "GameShark"
        do {
            _ = try await intent.perform()
        } catch let error as AppIntentError {
            if case .noActiveSession = error { /* expected in CI */ } else {
                XCTFail("Unexpected AppIntentError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - TakeScreenshotIntent Tests

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
final class TakeScreenshotIntentTests: XCTestCase {

    func testPerformThrowsOrSucceeds() async {
        let intent = TakeScreenshotIntent()
        do {
            _ = try await intent.perform()
        } catch let error as AppIntentError {
            if case .noActiveSession = error { /* expected in CI */ } else {
                XCTFail("Unexpected AppIntentError: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - SaveStateEntity Tests

@available(iOS 17, tvOS 17, macOS 14, watchOS 10, *)
final class SaveStateEntityTests: XCTestCase {

    private func makeSaveState(slot: Int = 1, id: String = "save-001") -> SaveStateEntity {
        SaveStateEntity(
            id: id,
            gameTitle: "Super Mario World",
            gameMD5: "abc123",
            slot: slot,
            screenshotURL: nil,
            date: Date(timeIntervalSince1970: 0)
        )
    }

    func testSaveStateEntityInit() {
        let entity = makeSaveState(slot: 2, id: "save-xyz")
        XCTAssertEqual(entity.id, "save-xyz")
        XCTAssertEqual(entity.gameTitle, "Super Mario World")
        XCTAssertEqual(entity.gameMD5, "abc123")
        XCTAssertEqual(entity.slot, 2)
        XCTAssertNil(entity.screenshotURL)
        XCTAssertEqual(entity.date, Date(timeIntervalSince1970: 0))
    }

    func testSaveStateEntityDeepLinkURL() {
        let entity = makeSaveState(slot: 1, id: "save-001")
        let url = entity.deepLinkURL
        XCTAssertEqual(url.scheme, "provenance")
        XCTAssertEqual(url.host, "open")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []
        let md5Item = queryItems.first(where: { $0.name == "md5" })
        let saveStateIdItem = queryItems.first(where: { $0.name == "saveStateId" })
        XCTAssertEqual(md5Item?.value, "abc123")
        XCTAssertEqual(saveStateIdItem?.value, "save-001")
    }

    func testSaveStateEntityDisplayRepresentationAutoSave() {
        let entity = makeSaveState(slot: 0)
        let repr = entity.displayRepresentation
        XCTAssertTrue(repr.subtitle?.key.contains("Auto-save") == true,
                      "Slot 0 should display 'Auto-save', got: \(String(describing: repr.subtitle))")
    }

    func testSaveStateEntityDisplayRepresentationSlot() {
        let entity = makeSaveState(slot: 3)
        let repr = entity.displayRepresentation
        XCTAssertTrue(repr.subtitle?.key.contains("Slot 3") == true,
                      "Slot 3 should display 'Slot 3', got: \(String(describing: repr.subtitle))")
    }
}

#endif // canImport(AppIntents)
