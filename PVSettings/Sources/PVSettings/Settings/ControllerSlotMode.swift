//
//  ControllerSlotMode.swift
//  PVSettings
//
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import Defaults

/// The player-slot assignment mode for a controller.
///
/// Stored per-controller (keyed by vendor name) in UserDefaults via the
/// `Defaults` library.  `PVControllerManager` reads this value on every
/// `GCController` connect / reconnect notification and applies the
/// appropriate assignment strategy.
///
/// | Mode | Behaviour |
/// |------|-----------|
/// | `.auto` | Assign to the first available slot (no preference). Default. |
/// | `.preferred(n)` | Assign to slot *n* if it is currently free; otherwise use the first available slot. |
/// | `.always(n)` | Always claim slot *n*, bumping the current occupant (if any) to the next free slot.  When two controllers both have `.always(n)` for the same slot, the last-connected controller wins and a warning is logged. |
public enum ControllerSlotMode: Equatable, Defaults.Serializable {

    /// No preference — use the first available slot.
    case auto
    /// Claim slot `n` if free; otherwise fall back to the first available slot.
    case preferred(Int)
    /// Always claim slot `n`, displacing whoever is currently there.
    case always(Int)

    // MARK: Defaults.Bridge (serialises to a plain String for UserDefaults compatibility)

    public struct Bridge: Defaults.Bridge, Sendable {
        public typealias Value = ControllerSlotMode
        public typealias Serializable = String

        public func serialize(_ value: ControllerSlotMode?) -> String? {
            guard let value else { return nil }
            switch value {
            case .auto:             return "auto"
            case .preferred(let n): return "preferred:\(n)"
            case .always(let n):    return "always:\(n)"
            }
        }

        public func deserialize(_ object: String?) -> ControllerSlotMode? {
            guard let string = object else { return nil }
            if string == "auto" { return .auto }
            let parts = string.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, let slot = Int(parts[1]), (1...8).contains(slot) else {
                return nil
            }
            switch String(parts[0]) {
            case "preferred": return .preferred(slot)
            case "always":    return .always(slot)
            default:          return nil
            }
        }
    }

    public static let bridge = Bridge()

    // MARK: Convenience

    /// The preferred slot number embedded in this mode, or `nil` for `.auto`.
    public var preferredSlot: Int? {
        switch self {
        case .auto:             return nil
        case .preferred(let n): return n
        case .always(let n):    return n
        }
    }
}

// MARK: - Defaults.Keys

public extension Defaults.Keys {
    /// Per-controller slot-mode preferences, keyed by controller identifier
    /// (typically `GCController.vendorName`).
    static let controllerSlotModes = Key<[String: ControllerSlotMode]>(
        "PVControllerSlotModes",
        default: [:]
    )
}
