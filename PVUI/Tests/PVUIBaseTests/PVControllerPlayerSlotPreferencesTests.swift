import Testing
import GameController
@testable import PVUIBase
@testable import PVSettings

// MARK: - Controller Player-Slot Preference Tests
//
// These tests validate the player-slot preference logic in PVControllerManager.
// They run entirely without hardware and only call the preference read/write helpers.
//
// NOTE: PVControllerManager is a @MainActor singleton; the tests run the
// relevant logic on the main actor via Swift structured concurrency.

@Suite("PVControllerManager — Player-Slot Preferences")
struct PVControllerPlayerSlotPreferencesTests {

    // MARK: Helpers

    @MainActor
    private func freshController() -> GCController {
        let c = GCController.withExtendedGamepad()
        PVControllerManager.shared.clearSlotMode(for: c)
        return c
    }

    /// Returns a closure that restores `Defaults[.controllerSlotModes]` to the
    /// state at call time. Use with `defer` so cleanup runs even on test failure:
    ///
    ///     let restore = snapshotSlotModes()
    ///     defer { restore() }
    @MainActor
    private func snapshotSlotModes() -> @MainActor () -> Void {
        let snapshot = Defaults[.controllerSlotModes]
        return { Defaults[.controllerSlotModes] = snapshot }
    }

    // MARK: - preferredPlayer / setPreferredPlayer (convenience API)

    @Test("preferredPlayer returns nil when no preference stored")
    @MainActor
    func preferredPlayerReturnsNilWhenNotSet() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller = freshController()

        let result = manager.preferredPlayer(for: controller)
        #expect(result == nil)
    }

    @Test("setPreferredPlayer persists and preferredPlayer reads it back")
    @MainActor
    func roundtripPreferredPlayer() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller = freshController()

        manager.setPreferredPlayer(2, for: controller)
        let result = manager.preferredPlayer(for: controller)
        #expect(result == 2)
    }

    @Test("setPreferredPlayer with nil clears an existing preference")
    @MainActor
    func clearingPreference() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller = freshController()

        manager.setPreferredPlayer(3, for: controller)
        manager.setPreferredPlayer(nil, for: controller)

        #expect(manager.preferredPlayer(for: controller) == nil)
    }

    @Test("setPreferredPlayer rejects out-of-range values (0 and 9)")
    @MainActor
    func outOfRangeValuesAreIgnored() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller = freshController()

        manager.setPreferredPlayer(0, for: controller)
        #expect(manager.preferredPlayer(for: controller) == nil, "0 should be rejected")

        manager.setPreferredPlayer(9, for: controller)
        #expect(manager.preferredPlayer(for: controller) == nil, "9 should be rejected")
    }

    @Test("controllerIdentifier uses vendorName when available")
    @MainActor
    func controllerIdentifierPrefersVendorName() async throws {
        let manager = PVControllerManager.shared
        let controller = GCController.withExtendedGamepad()
        let identifier = manager.controllerIdentifier(for: controller)
        // A synthetic controller always has a vendorName or falls back to productCategory;
        // either way the result must be non-empty.
        #expect(!identifier.isEmpty)
    }

    // MARK: - ControllerSlotMode API

    @Test("slotMode returns .auto when nothing is stored")
    @MainActor
    func slotModeDefaultsToAuto() async throws {
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller = freshController()
        let mode = PVControllerManager.shared.slotMode(for: controller)
        #expect(mode == .auto)
    }

    @Test("setSlotMode(.preferred) round-trips correctly")
    @MainActor
    func slotModePreferredRoundtrip() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller = freshController()

        manager.setSlotMode(.preferred(4), for: controller)
        #expect(manager.slotMode(for: controller) == .preferred(4))
        #expect(manager.preferredPlayer(for: controller) == 4)
    }

    @Test("setSlotMode(.always) round-trips correctly")
    @MainActor
    func slotModeAlwaysRoundtrip() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller = freshController()

        manager.setSlotMode(.always(1), for: controller)
        #expect(manager.slotMode(for: controller) == .always(1))
        #expect(manager.preferredPlayer(for: controller) == 1)
    }

    @Test("clearSlotMode resets to .auto")
    @MainActor
    func clearSlotModeResetsToAuto() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller = freshController()

        manager.setSlotMode(.always(2), for: controller)
        manager.clearSlotMode(for: controller)

        #expect(manager.slotMode(for: controller) == .auto)
        #expect(manager.preferredPlayer(for: controller) == nil)
    }

    @Test("setSlotMode(.auto) is equivalent to clearSlotMode")
    @MainActor
    func setSlotModeAutoClears() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller = freshController()

        manager.setSlotMode(.preferred(3), for: controller)
        manager.setSlotMode(.auto, for: controller)

        #expect(manager.slotMode(for: controller) == .auto)
    }

    // MARK: - ControllerSlotMode serialisation

    @Test("ControllerSlotMode bridge round-trips .auto")
    func bridgeAuto() throws {
        let bridge = ControllerSlotMode.Bridge()
        let serialized = bridge.serialize(.auto)
        let deserialized = bridge.deserialize(serialized)
        #expect(deserialized == .auto)
    }

    @Test("ControllerSlotMode bridge round-trips .preferred(5)")
    func bridgePreferred() throws {
        let bridge = ControllerSlotMode.Bridge()
        let serialized = bridge.serialize(.preferred(5))
        let deserialized = bridge.deserialize(serialized)
        #expect(deserialized == .preferred(5))
    }

    @Test("ControllerSlotMode bridge round-trips .always(1)")
    func bridgeAlways() throws {
        let bridge = ControllerSlotMode.Bridge()
        let serialized = bridge.serialize(.always(1))
        let deserialized = bridge.deserialize(serialized)
        #expect(deserialized == .always(1))
    }

    @Test("ControllerSlotMode bridge returns nil for unknown strings")
    func bridgeUnknownString() throws {
        let bridge = ControllerSlotMode.Bridge()
        #expect(bridge.deserialize(nil) == nil)
        #expect(bridge.deserialize("bogus") == nil)
        #expect(bridge.deserialize("unknown:3") == nil)
    }

    // MARK: - ID-based slot mode API

    @Test("slotMode(forId:) returns .auto for unknown ID")
    @MainActor
    func slotModeForIdDefaultsToAuto() async throws {
        let mode = PVControllerManager.shared.slotMode(forId: "NonExistentController-\(UUID().uuidString)")
        #expect(mode == .auto)
    }

    @Test("setSlotMode(_:forId:) round-trips via slotMode(forId:)")
    @MainActor
    func slotModeForIdRoundtrip() async throws {
        let manager = PVControllerManager.shared
        let fakeId = "TestController-\(UUID().uuidString)"
        let restore = snapshotSlotModes()
        defer { restore() }

        manager.setSlotMode(.preferred(3), forId: fakeId)
        #expect(manager.slotMode(forId: fakeId) == .preferred(3))
        #expect(manager.storedControllerIds.contains(fakeId))

        manager.clearSlotMode(forId: fakeId)
        #expect(manager.slotMode(forId: fakeId) == .auto)
        #expect(!manager.storedControllerIds.contains(fakeId))
    }

    @Test("storedControllerIds only contains IDs with non-auto modes")
    @MainActor
    func storedControllerIdsExcludesAuto() async throws {
        let manager = PVControllerManager.shared
        let fakeId = "TestController-\(UUID().uuidString)"
        let restore = snapshotSlotModes()
        defer { restore() }

        manager.setSlotMode(.auto, forId: fakeId)
        #expect(!manager.storedControllerIds.contains(fakeId))

        manager.setSlotMode(.always(2), forId: fakeId)
        #expect(manager.storedControllerIds.contains(fakeId))
    }

    // MARK: - assign(_:) / reapplyPreferences() behavior

    @Test("assign - .preferred(n) claims a free slot and auto fills remaining")
    @MainActor
    func assignPreferredClaimsFreeSlot() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller1 = freshController()
        let controller2 = freshController()

        manager.setSlotMode(.preferred(1), for: controller1)
        manager.setSlotMode(.auto, for: controller2)

        manager.assign([controller1, controller2])

        let player1Controller = manager.controller(forPlayer: 1)
        let player2Controller = manager.controller(forPlayer: 2)

        #expect(player1Controller === controller1)
        #expect(player2Controller === controller2)
    }

    @Test("assign - .preferred(n) falls back to auto when slot already occupied")
    @MainActor
    func assignPreferredFallsBackWhenOccupied() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller1 = freshController()
        let controller2 = freshController()

        // First controller uses auto and should occupy player 1.
        manager.setSlotMode(.auto, for: controller1)
        // Second controller prefers player 1, but that slot is already taken.
        manager.setSlotMode(.preferred(1), for: controller2)

        manager.assign([controller1, controller2])

        let player1Controller = manager.controller(forPlayer: 1)
        let player2Controller = manager.controller(forPlayer: 2)

        // Auto-assigned controller stays on player 1, preferred controller falls back to next free slot.
        #expect(player1Controller === controller1)
        #expect(player2Controller === controller2)
    }

    @Test("assign/reapplyPreferences - .always(n) evicts occupant to next free slot")
    @MainActor
    func alwaysEvictsOccupantToNextFreeSlot() async throws {
        let manager = PVControllerManager.shared
        let restore = snapshotSlotModes()
        defer { restore() }
        let controller1 = freshController()
        let controller2 = freshController()

        // Start with a single auto-assigned controller on player 1.
        manager.setSlotMode(.auto, for: controller1)
        manager.assign([controller1])

        // Connect a second controller that must always occupy player 1.
        manager.setSlotMode(.always(1), for: controller2)
        manager.assign([controller1, controller2])
        manager.reapplyPreferences()

        let player1Controller = manager.controller(forPlayer: 1)
        let player2Controller = manager.controller(forPlayer: 2)

        // The .always(1) controller should occupy player 1 and evict the previous
        // occupant to the next available slot.
        #expect(player1Controller === controller2)
        #expect(player2Controller === controller1)
    }
}
