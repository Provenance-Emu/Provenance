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
            case .rangef(let d, _, _, _):        display = d
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

// MARK: - Core Compatibility Catalog

/// Tracks which emulator cores have been updated to support coordinated deadzone handling.
///
/// This catalog is the authoritative record of adoption progress. As new cores gain
/// support, add an entry here so users and reviewers can see the rolling coverage.
/// The Settings UI surfaces this automatically — no changelog digging required.
public struct CoreDeadzoneCompatibilityCatalog: Sendable {

    /// How well a core integrates with the shared deadzone system.
    public enum SupportLevel: Int, Comparable, CaseIterable, Sendable {
        /// Core uses `PVApplyAnalogDeadzone()` on true-analog axes — full coordination.
        case native = 3
        /// Core uses `PVAnalogDigitalThreshold()` max-wins logic — no double-processing.
        case coordinated = 2
        /// Some inputs covered; others still need work.
        case partial = 1
        /// Gap is known; a fix is planned in a future PR.
        case pending = 0

        public static func < (lhs: SupportLevel, rhs: SupportLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var label: String {
            switch self {
            case .native:      return "Native"
            case .coordinated: return "Coordinated"
            case .partial:     return "Partial"
            case .pending:     return "Planned"
            }
        }

        /// SF Symbol name that best represents this level.
        public var symbolName: String {
            switch self {
            case .native:      return "checkmark.seal.fill"
            case .coordinated: return "checkmark.circle.fill"
            case .partial:     return "exclamationmark.circle"
            case .pending:     return "clock.badge.checkmark"
            }
        }
    }

    /// A single core's deadzone support record.
    public struct Entry: Identifiable, Sendable {
        public let id: String            // pvCoreIdentifier
        public let displayName: String
        public let systems: [String]     // human-readable system names
        public let level: SupportLevel
        public let notes: String?

        public init(id: String, displayName: String, systems: [String],
                    level: SupportLevel, notes: String? = nil) {
            self.id = id
            self.displayName = displayName
            self.systems = systems
            self.level = level
            self.notes = notes
        }
    }

    // MARK: Catalog entries
    // Keep sorted: supported first, pending last.
    public static let entries: [Entry] = [
        .init(id: "com.provenance.core.fceu",
              displayName: "FCEU",
              systems: ["NES", "FDS"],
              level: .coordinated,
              notes: "Max-wins digital threshold — user setting or 10% core default, whichever is larger."),
        .init(id: "com.provenance.core.mednafen",
              displayName: "Mednafen",
              systems: ["NES", "SNES", "PCE", "PSX", "WonderSwan", "GB/GBC", "GBA", "NGP", "Saturn"],
              level: .coordinated,
              notes: "Max-wins digital threshold via MednafenAnalogDigitalThreshold()."),
        .init(id: "com.provenance.core.flycast",
              displayName: "Flycast",
              systems: ["Dreamcast"],
              level: .native,
              notes: "PVApplyAnalogDeadzone() on left-thumbstick X/Y before s8 conversion."),
        .init(id: "com.provenance.core.mupen64plus",
              displayName: "Mupen64Plus",
              systems: ["N64"],
              level: .pending,
              notes: "Passes raw axis values — deadzone coordination planned for a future PR."),
        .init(id: "com.provenance.core.dolphin",
              displayName: "Dolphin",
              systems: ["GameCube", "Wii"],
              level: .pending,
              notes: "Motion-specific deadzone — requires separate handling; future PR."),
    ]

    // MARK: Computed helpers

    /// Cores whose deadzone is fully or partially coordinated.
    public static var supportedEntries: [Entry] {
        entries.filter { $0.level >= .coordinated }
    }

    /// Cores not yet coordinated.
    public static var pendingEntries: [Entry] {
        entries.filter { $0.level < .coordinated }
    }

    /// Quick summary string suitable for a settings footer (e.g. "3 of 5 cores coordinated").
    public static var progressSummary: String {
        let done = supportedEntries.count
        let total = entries.count
        return "\(done) of \(total) cores have native deadzone coordination"
    }
}
