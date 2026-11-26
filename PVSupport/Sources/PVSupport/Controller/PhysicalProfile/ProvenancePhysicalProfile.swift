//
//  ProvenancePhysicalProfile.swift
//  PVSupport
//
//  Provenance's side of GamepadKit (github.com/Provenance-Emu/GamepadKit, shared with
//  iFly and iCube). The package wraps a pad the system exposes without an extended
//  gamepad (the Nintendo Switch Online N64/SNES/Mega Drive controllers, and plain
//  USB/Bluetooth HID pads) and synthesizes one from its physical input profile, so
//  cores that only read `extendedGamepad` work. What is Provenance's own is here.
//

#if canImport(UIKit) && canImport(GameController)
import GameController
import GamepadKit
import PVLogging

public extension PhysicalProfileConfiguration {
    /// How Provenance wraps a pad:
    /// - RetroPad names, with the SNES and N64 pads' face buttons read as their printed
    ///   labels (testers found A/B and X/Y swapped, and N64 B dead, when read as positions).
    /// - A generic pad that also has a micro profile is wrapped only when it has a B or Y
    ///   button, so a remote with an unknown category stays a remote.
    /// - Pause is Home, else Select + Start; the trigger's buttons are held back from the
    ///   game until released, and it is delivered through `controllerPausedHandler`, which
    ///   `PauseMenuTriggerMonitor` listens to. Start alone always reaches the game.
    /// - Options and Home are reported only when the pad has them, so the pause binding
    ///   and the pause menu's "missing buttons" entries see the truth.
    static let provenance = PhysicalProfileConfiguration(
        mapping: PhysicalProfileMapping(table: .retroPad),
        wrapPolicy: .usablePadNotRemoteLike,
        pausePolicy: .homeOrSelectStart,
        legacyPausedHandler: .anyTrigger,
        log: { _, message in ILOG(message) }
    )
}

public extension PhysicalProfileController {
    /// True when `controller` needs a wrapper under Provenance's rules.
    static func isNeeded(for controller: GCController) -> Bool {
        isNeeded(for: controller, configuration: .provenance)
    }

    /// Wraps `controller` under Provenance's rules.
    convenience init(wrapping controller: GCController) {
        self.init(wrapping: controller, configuration: .provenance)
    }
}
#endif
