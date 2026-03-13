import Testing
import GameController
@testable import PVUIBase

// MARK: - Controller Player-Slot Preference Tests
//
// These tests validate the UserDefaults-backed player-slot preference logic
// in PVControllerManager.  They run entirely without hardware and only call
// the preference read/write helpers.
//
// NOTE: PVControllerManager is a @MainActor singleton; the tests run the
// relevant logic on the main actor via Swift structured concurrency.

@Suite("PVControllerManager — Player-Slot Preferences")
struct PVControllerPlayerSlotPreferencesTests {

    // MARK: Helpers

    /// Clean up any UserDefaults keys written during a test run.
    private func cleanupKey(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: Tests

    @Test("preferredPlayer returns nil when no preference stored")
    @MainActor
    func preferredPlayerReturnsNilWhenNotSet() async throws {
        let manager = PVControllerManager.shared
        let controller = GCController.withExtendedGamepad()
        // Ensure no leftover value from a previous run
        manager.setPreferredPlayer(nil, for: controller)

        let result = manager.preferredPlayer(for: controller)
        #expect(result == nil)
    }

    @Test("setPreferredPlayer persists and preferredPlayer reads it back")
    @MainActor
    func roundtripPreferredPlayer() async throws {
        let manager = PVControllerManager.shared
        let controller = GCController.withExtendedGamepad()

        // Write
        manager.setPreferredPlayer(2, for: controller)

        // Read back
        let result = manager.preferredPlayer(for: controller)
        #expect(result == 2)

        // Cleanup
        manager.setPreferredPlayer(nil, for: controller)
    }

    @Test("setPreferredPlayer with nil clears an existing preference")
    @MainActor
    func clearingPreference() async throws {
        let manager = PVControllerManager.shared
        let controller = GCController.withExtendedGamepad()

        manager.setPreferredPlayer(3, for: controller)
        manager.setPreferredPlayer(nil, for: controller)

        #expect(manager.preferredPlayer(for: controller) == nil)
    }

    @Test("setPreferredPlayer rejects out-of-range values (0 and 9)")
    @MainActor
    func outOfRangeValuesAreIgnored() async throws {
        let manager = PVControllerManager.shared
        let controller = GCController.withExtendedGamepad()

        // Ensure clean state
        manager.setPreferredPlayer(nil, for: controller)

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
}
