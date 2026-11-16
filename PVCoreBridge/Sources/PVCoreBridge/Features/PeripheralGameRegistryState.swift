//
//  PeripheralGameRegistryState.swift
//  PVCoreBridge
//

import Foundation
import PVSystems

/// The lists behind `MouseGameRegistry` and `LightGunGameRegistry`: which systems always use the
/// peripheral, which use it for some games only, and how those games are recognised.
///
/// Each registry keeps one of these inside its lock, so it is only read or changed while the
/// lock is held.
struct PeripheralGameRegistryState: Sendable {
    private(set) var alwaysSystems: Set<SystemIdentifier>
    private(set) var conditionalSystems: Set<SystemIdentifier>
    /// All lowercased.
    private(set) var knownMD5s: Set<String>
    /// All lowercased.
    private(set) var titlePatterns: [SystemIdentifier: Set<String>]

    init(alwaysSystems: Set<SystemIdentifier>, conditionalSystems: Set<SystemIdentifier>,
         knownMD5s: Set<String>, titlePatterns: [SystemIdentifier: [String]]) {
        self.alwaysSystems = alwaysSystems
        self.conditionalSystems = conditionalSystems
        self.knownMD5s = Set(knownMD5s.map { $0.lowercased() })
        self.titlePatterns = titlePatterns.mapValues { Set($0.map { $0.lowercased() }) }
    }

    /// Every game on `system` uses the peripheral.
    mutating func addAlwaysSystem(_ system: SystemIdentifier) {
        alwaysSystems.insert(system)
        conditionalSystems.remove(system)
    }

    /// Only listed games on `system` use the peripheral. No effect on an always system.
    mutating func addConditionalSystem(_ system: SystemIdentifier) {
        guard !alwaysSystems.contains(system) else { return }
        conditionalSystems.insert(system)
    }

    mutating func addMD5(_ md5: String) {
        knownMD5s.insert(md5.lowercased())
    }

    mutating func addTitlePattern(_ pattern: String, forSystem system: SystemIdentifier) {
        titlePatterns[system, default: []].insert(pattern.lowercased())
    }

    /// Adds a core's lists. The caller reads them from the core before taking its lock.
    mutating func add(alwaysSystems: Set<SystemIdentifier>, conditionalSystems: Set<SystemIdentifier>,
                      md5s: Set<String>, titlePatterns: [SystemIdentifier: [String]]) {
        alwaysSystems.forEach { addAlwaysSystem($0) }
        conditionalSystems.forEach { addConditionalSystem($0) }
        md5s.forEach { addMD5($0) }
        for (system, patterns) in titlePatterns {
            patterns.forEach { addTitlePattern($0, forSystem: system) }
        }
    }

    func hasAnySupport(_ system: SystemIdentifier) -> Bool {
        alwaysSystems.contains(system) || conditionalSystems.contains(system)
    }

    /// Whether a game uses the peripheral, before the user's own per-game choice is applied.
    func supports(systemIdentifier: SystemIdentifier, md5: String?, title: String?) -> Bool {
        // Always systems never need a game-level check.
        if alwaysSystems.contains(systemIdentifier) { return true }

        // Not a capable system at all.
        if !conditionalSystems.contains(systemIdentifier) { return false }

        if let md5, knownMD5s.contains(md5.lowercased()) { return true }

        if let title, let systemPatterns = titlePatterns[systemIdentifier] {
            let lowTitle = title.lowercased()
            if systemPatterns.contains(where: { lowTitle.contains($0) }) { return true }
        }

        // Unknown game on a conditional system: off by default.
        return false
    }
}
