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

    // MARK: - preferredPlayer / setPreferredPlayer (convenience API)

    @Test("preferredPlayer returns nil when no preference stored")
    @MainActor
    func preferredPlayerReturnsNilWhenNotSet() async throws {
        let manager = PVControllerManager.shared
        let controller = freshController()

        let result = manager.preferredPlayer(for: controller)
        #expect(result == nil)
    }

    @Test("setPreferredPlayer persists and preferredPlayer reads it back")
    @MainActor
    func roundtripPreferredPlayer() async throws {
        let manager = PVControllerManager.shared
        let controller = freshController()

        manager.setPreferredPlayer(2, for: controller)
        let result = manager.preferredPlayer(for: controller)
        #expect(result == 2)

        // Cleanup
        manager.setPreferredPlayer(nil, for: controller)
    }

    @Test("setPreferredPlayer with nil clears an existing preference")
    @MainActor
    func clearingPreference() async throws {
        let manager = PVControllerManager.shared
        let controller = freshController()

        manager.setPreferredPlayer(3, for: controller)
        manager.setPreferredPlayer(nil, for: controller)

        #expect(manager.preferredPlayer(for: controller) == nil)
    }

    @Test("setPreferredPlayer rejects out-of-range values (0 and 9)")
    @MainActor
    func outOfRangeValuesAreIgnored() async throws {
        let manager = PVControllerManager.shared
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
        let controller = freshController()
        let mode = PVControllerManager.shared.slotMode(for: controller)
        #expect(mode == .auto)
    }

    @Test("setSlotMode(.preferred) round-trips correctly")
    @MainActor
    func slotModePreferredRoundtrip() async throws {
        let manager = PVControllerManager.shared
        let controller = freshController()

        manager.setSlotMode(.preferred(4), for: controller)
        #expect(manager.slotMode(for: controller) == .preferred(4))
        #expect(manager.preferredPlayer(for: controller) == 4)

        manager.clearSlotMode(for: controller)
    }

    @Test("setSlotMode(.always) round-trips correctly")
    @MainActor
    func slotModeAlwaysRoundtrip() async throws {
        let manager = PVControllerManager.shared
        let controller = freshController()

        manager.setSlotMode(.always(1), for: controller)
        #expect(manager.slotMode(for: controller) == .always(1))
        #expect(manager.preferredPlayer(for: controller) == 1)

        manager.clearSlotMode(for: controller)
    }

    @Test("clearSlotMode resets to .auto")
    @MainActor
    func clearSlotModeResetsToAuto() async throws {
        let manager = PVControllerManager.shared
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
}
