//
//  CoreOptions.swift
//  PVProSystem
//
//  Created by Joseph Mattiello on 9/19/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation
import PVCoreBridge
import PVCoreObjCBridge
import PVEmulatorCore

// MARK: - Option catalog

internal final class PVProSystemCoreOptions: CoreOptions, Sendable {

    // MARK: Console difficulty switches

    /// Left difficulty switch. true = A (Advanced), false = B (Beginner).
    /// Atari 7800 default: B (Beginner) — left position.
    nonisolated(unsafe) static let leftDifficultyOption: CoreOption = .bool(
        .init(
            title: "Left Difficulty Switch",
            description: "Position of the left console difficulty switch. A = Advanced, B = Beginner.",
            requiresRestart: false
        ),
        defaultValue: false   // false = B (Beginner) — hardware default
    )

    /// Right difficulty switch. true = A (Advanced), false = B (Beginner).
    /// Atari 7800 default: A (Advanced) — fixes Tower Toppler and similar games.
    nonisolated(unsafe) static let rightDifficultyOption: CoreOption = .bool(
        .init(
            title: "Right Difficulty Switch",
            description: "Position of the right console difficulty switch. A = Advanced, B = Beginner.",
            requiresRestart: false
        ),
        defaultValue: true    // true = A (Advanced) — hardware default for Provenance
    )

    // MARK: Option catalog

    public static var options: [CoreOption] {
        [CoreOption.group(
            .init(title: "Console",
                  description: "Atari 7800 console switch settings."),
            subOptions: [leftDifficultyOption, rightDifficultyOption]
        )]
    }
}

// MARK: - CoreOptional conformance

extension PVProSystemCore: CoreOptional {
    public static var options: [CoreOption] {
        PVProSystemCoreOptions.options
    }
}

// MARK: - ObjC-accessible option accessors

@objc
public extension PVProSystemCore {

    /// Whether the left difficulty switch should be in the A (Advanced) position.
    @objc var prosystem_leftDifficultyAdvanced: Bool {
        PVProSystemCore.valueForOption(PVProSystemCoreOptions.leftDifficultyOption).asBool
    }

    /// Whether the right difficulty switch should be in the A (Advanced) position.
    @objc var prosystem_rightDifficultyAdvanced: Bool {
        PVProSystemCore.valueForOption(PVProSystemCoreOptions.rightDifficultyOption).asBool
    }

}
