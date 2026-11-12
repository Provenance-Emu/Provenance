//
//  ControllerPointerRole.swift
//  PVCoreBridge
//
//  What a controller's touchpad or gyro points at in the running game, and what its clicks do.
//

import Foundation
import PVSystems

/// What the controller's pointer input drives in the running game.
public enum ControllerPointerRole: String, Codable, Sendable, CaseIterable {
    /// Nothing: the touchpad is free, and its click opens the pause menu.
    case none
    /// The emulated mouse.
    case mouse
    /// The Wii Remote's pointer.
    case wiiPointer
    /// A light gun's aim.
    case lightGun
}

/// The player's choice of role.
public enum ControllerPointerMode: String, Codable, Sendable, CaseIterable {
    /// Decide from what the running game supports.
    case automatic
    /// Never use the controller as a pointer.
    case off
    case mouse
    case wiiPointer
    case lightGun
}

/// What the role decision depends on.
public struct ControllerPointerContext: Equatable, Sendable {
    public var system: SystemIdentifier?
    /// The running game takes a mouse (`MouseResponder.gameSupportsMouse`).
    public var gameSupportsMouse: Bool
    /// The running game is a light-gun game (`LightGunResponder.gameSupportsLightGun`).
    public var gameSupportsLightGun: Bool
    /// The core takes an absolute pointer (`PointerResponder.gameSupportsPointer`).
    public var coreSupportsPointer: Bool
    /// A connected pad has a touchpad or motion sensors.
    public var padHasPointerInput: Bool

    public init(system: SystemIdentifier?, gameSupportsMouse: Bool = false, gameSupportsLightGun: Bool = false,
                coreSupportsPointer: Bool = false, padHasPointerInput: Bool = true) {
        self.system = system
        self.gameSupportsMouse = gameSupportsMouse
        self.gameSupportsLightGun = gameSupportsLightGun
        self.coreSupportsPointer = coreSupportsPointer
        self.padHasPointerInput = padHasPointerInput
    }
}

/// Chooses the pointer role for a game.
public enum ControllerPointerPolicy {

    /// Systems whose touch screen is driven another way; the pad is never their pointer.
    static let excludedSystems: Set<SystemIdentifier> = [.DS]

    public static func role(for context: ControllerPointerContext, mode: ControllerPointerMode) -> ControllerPointerRole {
        guard context.padHasPointerInput, mode != .off else { return .none }
        if let system = context.system, excludedSystems.contains(system) { return .none }

        let canAimGun = context.gameSupportsLightGun
        let canMouse = context.gameSupportsMouse
        let canPoint = context.system == .Wii && context.coreSupportsPointer

        switch mode {
        case .off:
            return .none
        case .lightGun:
            return canAimGun ? .lightGun : .none
        case .mouse:
            return canMouse ? .mouse : .none
        case .wiiPointer:
            return canPoint ? .wiiPointer : .none
        case .automatic:
            if canAimGun { return .lightGun }
            if canMouse { return .mouse }
            if canPoint { return .wiiPointer }
            return .none
        }
    }
}

/// What a press of the touchpad does.
public enum PointerAction: String, Codable, Sendable, CaseIterable {
    case leftButton
    case rightButton
    case trigger
    case reload
    case auxA
    case auxB
    case gunStart
    case wiiA
    case wiiB
    /// Opens the pause menu. Fires on the press only.
    case pauseMenu
    case none
}

/// The action for each place the touchpad can be pressed.
public struct PointerClickBindings: Codable, Equatable, Sendable {
    public var left: PointerAction
    public var right: PointerAction
    public var twoFinger: PointerAction

    public init(left: PointerAction, right: PointerAction, twoFinger: PointerAction) {
        self.left = left
        self.right = right
        self.twoFinger = twoFinger
    }

    public subscript(zone: TouchpadClickZone) -> PointerAction {
        get {
            switch zone {
            case .left: return left
            case .right: return right
            case .twoFinger: return twoFinger
            }
        }
        set {
            switch zone {
            case .left: left = newValue
            case .right: right = newValue
            case .twoFinger: twoFinger = newValue
            }
        }
    }

    public static func defaults(for role: ControllerPointerRole) -> PointerClickBindings {
        switch role {
        case .none:
            return PointerClickBindings(left: .none, right: .none, twoFinger: .none)
        case .mouse:
            return PointerClickBindings(left: .leftButton, right: .leftButton, twoFinger: .rightButton)
        case .wiiPointer:
            /// The two-finger click opens the pause menu: with the touchpad taken, a PlayStation
            /// pad has no other single free button in Wii games, which use both Minus and Plus.
            return PointerClickBindings(left: .wiiA, right: .wiiB, twoFinger: .pauseMenu)
        case .lightGun:
            return PointerClickBindings(left: .trigger, right: .reload, twoFinger: .pauseMenu)
        }
    }
}
