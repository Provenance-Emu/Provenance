//
//  ControllerPointerSettingsTests.swift
//  PVCoreBridgeTests
//

@testable import PVCoreBridge
import PVSystems
import XCTest

final class ControllerPointerSettingsTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var store: ControllerPointerSettingsStore!

    private let speedKey = ControllerPointerSettingsStore.speedKey.name
    private let inputSourceKey = ControllerPointerSettingsStore.inputSourceKey.name

    override func setUp() {
        super.setUp()
        suiteName = "ControllerPointerSettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = ControllerPointerSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        super.tearDown()
    }

    func testEmptyResolvesToDefaults() {
        let resolved = store.resolved(system: .SNES, gameMD5: "abc")
        XCTAssertEqual(resolved.mode, .automatic)
        XCTAssertEqual(resolved.curve, PointerSpeedCurve())
        for role in ControllerPointerRole.allCases {
            XCTAssertEqual(resolved.bindings(for: role), .defaults(for: role))
        }
    }

    func testGameBeatsSystemBeatsGlobal() {
        store.update(.global) { $0.speed = 2.0; $0.acceleration = 0.1 }
        store.update(.system(.SNES)) { $0.speed = 3.0; $0.mode = .mouse }
        store.update(.game(md5: "abc")) { $0.speed = 4.0 }

        let game = store.resolved(system: .SNES, gameMD5: "abc")
        XCTAssertEqual(game.curve.speed, 4.0)
        /// Fields the game does not set come from further out, one by one.
        XCTAssertEqual(game.mode, .mouse)
        XCTAssertEqual(game.curve.acceleration, 0.1, accuracy: 0.0001)

        let otherGame = store.resolved(system: .SNES, gameMD5: "other")
        XCTAssertEqual(otherGame.curve.speed, 3.0)

        let otherSystem = store.resolved(system: .DOS, gameMD5: "abc2")
        XCTAssertEqual(otherSystem.curve.speed, 2.0)
        XCTAssertEqual(otherSystem.mode, .automatic)
    }

    func testBindingsResolvePerRole() {
        var gunBindings = PointerClickBindings.defaults(for: .lightGun)
        gunBindings[.twoFinger] = .auxA
        store.update(.system(.NES)) { $0.bindings = [ControllerPointerRole.lightGun.rawValue: gunBindings] }

        let resolved = store.resolved(system: .NES, gameMD5: nil)
        XCTAssertEqual(resolved.bindings(for: .lightGun), gunBindings)
        XCTAssertEqual(resolved.bindings(for: .mouse), .defaults(for: .mouse))
    }

    func testShakeDefaultsOnAndResolvesPerScope() {
        XCTAssertTrue(store.resolved(system: .Wii, gameMD5: "abc").shakeEnabled)
        store.update(.system(.Wii)) { $0.shake = false }
        XCTAssertFalse(store.resolved(system: .Wii, gameMD5: "abc").shakeEnabled)
        store.update(.game(md5: "abc")) { $0.shake = true }
        XCTAssertTrue(store.resolved(system: .Wii, gameMD5: "abc").shakeEnabled)
        XCTAssertFalse(store.resolved(system: .Wii, gameMD5: "other").shakeEnabled)
    }

    func testGyroComesFromTheExistingSettings() {
        XCTAssertFalse(store.resolved(system: nil, gameMD5: nil).gyroEnabled)
        defaults.set(true, forKey: ControllerPointerSettingsStore.gyroEnabledKey.name)
        defaults.set(2.0, forKey: ControllerPointerSettingsStore.gyroSensitivityKey.name)
        defaults.set(0.2, forKey: ControllerPointerSettingsStore.gyroDeadZoneKey.name)
        let resolved = store.resolved(system: nil, gameMD5: nil)
        XCTAssertTrue(resolved.gyroEnabled)
        XCTAssertEqual(resolved.gyroFilter.sensitivity, 2.0)
        XCTAssertEqual(resolved.gyroFilter.deadZone, 0.2)
    }

    func testGameCanTurnGyroOnAndInvert() {
        store.update(.game(md5: "abc")) { $0.gyro = true; $0.gyroInvertY = true }
        let resolved = store.resolved(system: .NES, gameMD5: "abc")
        XCTAssertTrue(resolved.gyroEnabled)
        XCTAssertTrue(resolved.gyroFilter.invertY)
        XCTAssertFalse(resolved.gyroFilter.invertX)
        XCTAssertFalse(store.resolved(system: .NES, gameMD5: "other").gyroEnabled)
    }

    func testGlobalGyroIsWrittenToTheGyroSetting() {
        store.update(.global) { $0.gyro = true }
        XCTAssertTrue(defaults.bool(forKey: ControllerPointerSettingsStore.gyroEnabledKey.name))
        XCTAssertNil(defaults.data(forKey: ControllerPointerSettingsStore.storageKey))
    }

    func testUpdatePrunesEmptyEntries() {
        store.update(.game(md5: "abc")) { $0.speed = 2.0 }
        XCTAssertNotNil(defaults.data(forKey: ControllerPointerSettingsStore.storageKey))

        store.update(.game(md5: "abc")) { $0.speed = nil }
        XCTAssertNil(defaults.data(forKey: ControllerPointerSettingsStore.storageKey))
        XCTAssertTrue(store.settings(for: .game(md5: "abc")).isEmpty)
    }

    func testScopeKeys() {
        XCTAssertEqual(ControllerPointerScope.global.key, "global")
        XCTAssertEqual(ControllerPointerScope.system(.SNES).key, "system:\(SystemIdentifier.SNES.rawValue)")
        XCTAssertEqual(ControllerPointerScope.game(md5: "abc").key, "game:abc")
    }

    func testEmptyMD5HasNoGameScope() {
        store.update(.game(md5: "")) { $0.speed = 4.0 }
        XCTAssertEqual(store.resolved(system: nil, gameMD5: "").curve.speed, PointerSpeedCurve().speed)
    }

    // MARK: - The global scope and the existing settings

    func testGlobalSpeedComesFromMouseSensitivity() {
        defaults.set(2.5, forKey: speedKey)
        XCTAssertEqual(store.resolved(system: nil, gameMD5: nil).curve.speed, 2.5)
        XCTAssertEqual(store.settings(for: .global).speed, 2.5)
    }

    func testGlobalSpeedIsWrittenToMouseSensitivity() {
        store.update(.global) { $0.speed = 1.8 }
        XCTAssertEqual(defaults.double(forKey: speedKey), 1.8, accuracy: 0.0001)
        /// Nothing else was set, so the dictionary holds no global entry.
        XCTAssertNil(defaults.data(forKey: ControllerPointerSettingsStore.storageKey))
    }

    func testInputSourceTurnsThePadOff() {
        /// The stored raw values of `MouseInputSource` (pinned by PVSettings' own tests).
        for source in ["touchscreen", "physicalMouse"] {
            defaults.set(source, forKey: inputSourceKey)
            XCTAssertEqual(store.resolved(system: nil, gameMD5: nil).mode, .off, source)
        }
        for source in ["auto", "controllerTouchpad", "gyro"] {
            defaults.set(source, forKey: inputSourceKey)
            XCTAssertEqual(store.resolved(system: nil, gameMD5: nil).mode, .automatic, source)
        }
    }

    func testAGameCanTurnThePadBackOn() {
        defaults.set("touchscreen", forKey: inputSourceKey)
        store.update(.game(md5: "abc")) { $0.mode = .mouse }
        XCTAssertEqual(store.resolved(system: .SNES, gameMD5: "abc").mode, .mouse)
    }
    func testGameTiltAndGyroTuningInheritIndependently() {
        store.update(.system(.Wii)) {
            $0.wiiTilt = .sideways
            $0.gyroSensitivity = 2
        }
        store.update(.game(md5: "abc")) {
            $0.wiiTilt = WiiTiltMode.off
            $0.gyroDeadZone = 0.2
        }
        let game = store.resolved(system: .Wii, gameMD5: "abc")
        XCTAssertEqual(game.wiiTilt, .off)
        XCTAssertEqual(game.gyroFilter.sensitivity, 2)
        XCTAssertEqual(game.gyroFilter.deadZone, 0.2)
        store.update(.game(md5: "abc")) { $0.wiiTilt = nil }
        XCTAssertEqual(store.resolved(system: .Wii, gameMD5: "abc").wiiTilt, .sideways)
    }
}
