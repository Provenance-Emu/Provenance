//
//  ControllerPointerSettings.swift
//  PVCoreBridge
//
//  The player's pointer settings, per game, per system and for everything.
//

import Defaults
import Foundation
import PVSettings
import PVSystems

/// Pointer settings at one scope. A nil field is inherited from the next scope out.
public struct ControllerPointerSettings: Codable, Equatable, Sendable {
    public var mode: ControllerPointerMode?
    public var speed: Double?
    public var acceleration: Double?
    /// Click bindings by role (`ControllerPointerRole.rawValue`).
    public var bindings: [String: PointerClickBindings]?
    /// Shaking a pad shakes the game's controller (the Wii Remote).
    public var shake: Bool?
    public var wiiTilt: WiiTiltMode?
    /// Turning the pad moves the pointer too.
    public var gyro: Bool?
    public var gyroSensitivity: Double?
    public var gyroDeadZone: Double?
    public var gyroInvertX: Bool?
    public var gyroInvertY: Bool?

    public init() {}

    public var isEmpty: Bool {
        mode == nil && speed == nil && acceleration == nil && (bindings?.isEmpty ?? true) && shake == nil
            && wiiTilt == nil && gyro == nil && gyroSensitivity == nil && gyroDeadZone == nil && gyroInvertX == nil && gyroInvertY == nil
    }
}

/// Where a set of pointer settings applies. The same scope keys as the shader library.
public enum ControllerPointerScope: Hashable, Sendable {
    case global
    case system(SystemIdentifier)
    case game(md5: String)

    public var key: String {
        switch self {
        case .global: return "global"
        case .system(let system): return "system:\(system.rawValue)"
        case .game(let md5): return "game:\(md5)"
        }
    }
}

/// Stores `ControllerPointerSettings` by scope and resolves them for a game.
///
/// The global speed is the existing "Mouse Sensitivity" setting and the global mode follows
/// "Input Source", so those two settings and this store never disagree. Everything else is
/// one dictionary on this device.
public final class ControllerPointerSettingsStore: @unchecked Sendable {

    public static let shared = ControllerPointerSettingsStore()

    /// Posted on the main queue after any scope changes.
    public static let didChangeNotification = Notification.Name("PVControllerPointerSettingsDidChange")

    static let storageKey = "controllerPointerSettings"
    /// The "Mouse Sensitivity" setting: the global pointer speed.
    static let speedKey = Defaults.Keys.mouseSensitivity
    /// The "Input Source" setting: decides the global mode.
    static let inputSourceKey = Defaults.Keys.mouseInputSource
    /// The existing gyro settings: on/off is the global gyro value, sensitivity and dead zone
    /// apply everywhere.
    static let gyroEnabledKey = Defaults.Keys.gyroMouseEnabled
    static let gyroSensitivityKey = Defaults.Keys.gyroMouseSensitivity
    static let gyroDeadZoneKey = Defaults.Keys.gyroMouseDeadZone

    /// What a game plays with, after the scopes are combined.
    public struct Resolved: Equatable, Sendable {
        public var mode: ControllerPointerMode
        public var curve: PointerSpeedCurve
        /// Shaking a pad shakes the game's controller. On unless the player turned it off.
        public var shakeEnabled: Bool
        public var wiiTilt: WiiTiltMode
        /// Turning the pad moves the pointer too.
        public var gyroEnabled: Bool
        public var gyroFilter: GyroPointerFilter
        var bindingOverrides: [ControllerPointerRole: PointerClickBindings]

        public func bindings(for role: ControllerPointerRole) -> PointerClickBindings {
            bindingOverrides[role] ?? .defaults(for: role)
        }
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Read

    public func settings(for scope: ControllerPointerScope) -> ControllerPointerSettings {
        var settings = lock.withLock { stored()[scope.key] } ?? ControllerPointerSettings()
        if scope == .global {
            settings.speed = globalSpeed
            settings.mode = settings.mode ?? globalMode
            settings.gyro = defaults.object(forKey: Self.gyroEnabledKey.name) as? Bool ?? Self.gyroEnabledKey.defaultValue
        }
        return settings
    }

    /// The settings a game plays with: each field from the game if it has one, else from
    /// its system, else the global value.
    public func resolved(system: SystemIdentifier?, gameMD5: String?) -> Resolved {
        var scopes: [ControllerPointerScope] = []
        if let gameMD5, !gameMD5.isEmpty { scopes.append(.game(md5: gameMD5)) }
        if let system { scopes.append(.system(system)) }
        scopes.append(.global)
        let layers = scopes.map(settings(for:))

        let defaultCurve = PointerSpeedCurve()
        let curve = PointerSpeedCurve(
            speed: layers.lazy.compactMap(\.speed).first ?? defaultCurve.speed,
            acceleration: layers.lazy.compactMap(\.acceleration).first ?? defaultCurve.acceleration)

        var overrides: [ControllerPointerRole: PointerClickBindings] = [:]
        for role in ControllerPointerRole.allCases {
            overrides[role] = layers.lazy.compactMap { $0.bindings?[role.rawValue] }.first
        }
        return Resolved(
            mode: layers.lazy.compactMap(\.mode).first ?? .automatic, curve: curve,
            shakeEnabled: layers.lazy.compactMap(\.shake).first ?? true,
            wiiTilt: layers.lazy.compactMap(\.wiiTilt).first ?? .off,
            gyroEnabled: layers.lazy.compactMap(\.gyro).first ?? false,
            gyroFilter: GyroPointerFilter(
                sensitivity: layers.lazy.compactMap(\.gyroSensitivity).first ?? double(Self.gyroSensitivityKey),
                deadZone: layers.lazy.compactMap(\.gyroDeadZone).first ?? double(Self.gyroDeadZoneKey),
                invertX: layers.lazy.compactMap(\.gyroInvertX).first ?? false,
                invertY: layers.lazy.compactMap(\.gyroInvertY).first ?? false),
            bindingOverrides: overrides)
    }

    // MARK: - Write

    /// Changes one scope. An entry left with nothing in it is removed.
    public func update(_ scope: ControllerPointerScope, _ change: (inout ControllerPointerSettings) -> Void) {
        lock.withLock {
            var all = stored()
            var settings = all[scope.key] ?? ControllerPointerSettings()
            if scope == .global {
                settings.speed = globalSpeed
                settings.gyro = defaults.object(forKey: Self.gyroEnabledKey.name) as? Bool ?? Self.gyroEnabledKey.defaultValue
            }
            change(&settings)
            if scope == .global {
                /// The global speed has one home: the Mouse Sensitivity setting.
                if let speed = settings.speed { defaults.set(speed, forKey: Self.speedKey.name) }
                settings.speed = nil
                /// And the global gyro switch has one home: the Enable Gyro Mouse setting.
                if let gyro = settings.gyro { defaults.set(gyro, forKey: Self.gyroEnabledKey.name) }
                settings.gyro = nil
            }
            all[scope.key] = settings.isEmpty ? nil : settings
            save(all)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    // MARK: - Storage

    private var globalSpeed: Double {
        double(Self.speedKey)
    }

    private func double(_ key: Defaults.Key<Double>) -> Double {
        defaults.object(forKey: key.name) as? Double ?? key.defaultValue
    }

    /// "Input Source" set to the touch screen or a hardware mouse means the pad is not the pointer.
    private var globalMode: ControllerPointerMode {
        let raw = defaults.string(forKey: Self.inputSourceKey.name)
        switch raw.flatMap(MouseInputSource.init(rawValue:)) ?? Self.inputSourceKey.defaultValue {
        case .touchscreen, .physicalMouse: return .off
        case .auto, .controllerTouchpad, .gyro: return .automatic
        }
    }

    private func stored() -> [String: ControllerPointerSettings] {
        guard let data = defaults.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([String: ControllerPointerSettings].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func save(_ all: [String: ControllerPointerSettings]) {
        if all.isEmpty {
            defaults.removeObject(forKey: Self.storageKey)
        } else if let data = try? JSONEncoder().encode(all) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
