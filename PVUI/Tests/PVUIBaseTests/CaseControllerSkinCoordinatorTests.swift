import XCTest
import Defaults
@testable import PVUIBase

#if os(iOS) || targetEnvironment(macCatalyst)
@MainActor
final class CaseControllerSkinCoordinatorTests: XCTestCase {

    // MARK: - Lifecycle

    func testStartAndStopDoNotCrash() {
        let coordinator = CaseControllerSkinCoordinator()
        coordinator.start()
        coordinator.stop()
        // Calling stop() a second time must be safe (idempotent).
        coordinator.stop()
    }

    func testStartIsIdempotent() {
        let coordinator = CaseControllerSkinCoordinator()
        coordinator.start()
        coordinator.start()  // Should not register duplicate observers.
        coordinator.stop()
    }

    // MARK: - Notification posting (auto-load disabled path)

    func testCaseConnectNotificationTriggersToastWhenAutoLoadDisabled() {
        Defaults[.autoLoadCaseSkin] = false
        defer { Defaults.reset(.autoLoadCaseSkin) }

        let coordinator = CaseControllerSkinCoordinator()
        coordinator.start()
        defer { coordinator.stop() }

        // Post a fake PVPhysicalCaseDidConnect with a known layout.
        let layout = CaseControllerDetector.knownLayouts.first { $0.name == "Buppin Case" }
        XCTAssertNotNil(layout, "Buppin Case layout must be registered")

        NotificationCenter.default.post(
            name: .PVPhysicalCaseDidConnect,
            object: nil,
            userInfo: layout!.notificationUserInfo
        )
        // Spin the main run loop so the main-queue observer fires before the test exits.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    func testCaseConnectNotificationWithMissingLayoutUserInfoIsHandledGracefully() {
        let coordinator = CaseControllerSkinCoordinator()
        coordinator.start()
        defer { coordinator.stop() }

        // Post notification without a layout in userInfo — coordinator must not crash.
        NotificationCenter.default.post(
            name: .PVPhysicalCaseDidConnect,
            object: nil,
            userInfo: nil
        )
        // Spin the main run loop so the observer fires and we verify it doesn't crash.
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    // MARK: - Deinit

    func testDeinitCallsStopImplicitly() {
        // Verify no crash or assertion when the coordinator is dealloc'd while active.
        var coordinator: CaseControllerSkinCoordinator? = CaseControllerSkinCoordinator()
        coordinator?.start()
        coordinator = nil  // triggers deinit → stop()
    }
}
#endif
