//
//  CoreDeadzone.swift
//  PVCoreBridge
//
//  Created by Provenance Emu on 2026-03-13.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation

// MARK: - CoreDeadzoneMode

/// Determines how the universal analog deadzone is applied when a core
/// also has its own per-core deadzone option.
@objc public enum CoreDeadzoneMode: Int, Codable, CaseIterable {
    /// Auto-detect: if the core declares its own deadzone option,
    /// skip the universal deadzone; otherwise apply it.
    case auto = 0
    /// Always apply the universal deadzone regardless of per-core settings.
    case universal = 1
    /// Never apply the universal deadzone; let each core manage its own.
    case coreManaged = 2
}

extension CoreDeadzoneMode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .auto:       return "Auto"
        case .universal:  return "Universal"
        case .coreManaged: return "Core-Managed"
        }
    }
}

// MARK: - CoreDeadzoneCapable

/// A protocol that emulator cores can conform to in order to declare
/// that they handle deadzone internally.  When a core conforms to this
/// protocol and returns `true`, the shared input path will skip applying
/// the universal deadzone setting so values are not processed twice.
@objc public protocol CoreDeadzoneCapable: AnyObject {
    /// Return `true` if this core applies its own analog-stick deadzone
    /// and the universal deadzone should be bypassed.
    @objc var coreHandlesDeadzone: Bool { get }
}

// MARK: - Auto-detection helpers

/// Well-known CoreOption key fragments that signal a core declares its own deadzone.
private let knownDeadzoneOptionKeyFragments: [String] = [
    "deadzone",
    "dead_zone",
]

public extension CoreOptional {
    /// Scans `options` recursively for any option whose key or display name
    /// contains a known deadzone keyword.  Returns `true` if found.
    static var declaresOwnDeadzone: Bool {
        return optionsContainDeadzone(options)
    }

    private static func optionsContainDeadzone(_ opts: [CoreOption]) -> Bool {
        for option in opts {
            let display: CoreOptionValueDisplay
            switch option {
            case .bool(let d, _, _):             display = d
            case .range(let d, _, _, _):         display = d
            case .multi(let d, _, _):            display = d
            case .enumeration(let d, _, _, _):   display = d
            case .string(let d, _, _):           display = d
            case .group(let d, let subOptions):
                display = d
                if optionsContainDeadzone(subOptions) { return true }
            }
            let key = display.title.lowercased()
            let desc = (display.description ?? "").lowercased()
            if knownDeadzoneOptionKeyFragments.contains(where: { key.contains($0) || desc.contains($0) }) {
                return true
            }
        }
        return false
    }
}

// MARK: - Analog Value Deadzone Application

public extension Float {
    /// Apply a symmetric deadzone to a normalized analog axis value in [-1, 1].
    ///
    /// Values inside `[-deadzone, deadzone]` are snapped to 0.
    /// Values outside are rescaled so the output still spans [-1, 1].
    ///
    /// - Parameter deadzone: Fraction of the axis range to treat as dead,
    ///   clamped to [0, 0.95].
    func applyingDeadzone(_ deadzone: Float) -> Float {
        let dz = deadzone.clamped(to: 0...0.95)
        guard dz > 0 else { return self }
        let abs = Swift.abs(self)
        guard abs > dz else { return 0 }
        let sign: Float = self >= 0 ? 1 : -1
        return sign * (abs - dz) / (1 - dz)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
