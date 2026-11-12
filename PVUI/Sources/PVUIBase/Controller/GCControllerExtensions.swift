//
//  GCControllerExtensions.swift
//  Provenance
//
//  Created by Sev Gerk on 1/27/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

import Foundation
import GameController
import PVLogging
import PVSupport

// MARK: - Controller Notifications

public extension Notification.Name {
    /// Posted when the DualSense microphone button is pressed and the user action is `.muteAudio`.
    /// The `object` is the `GCController` that fired the event.
    static let PVControllerMicButtonToggleMute = Notification.Name("PVControllerMicButtonToggleMuteNotification")
}

// MARK: ThumbSticks
public extension GCController {
    var supportsThumbstickButtons: Bool {
        if let controller = self.extendedGamepad {
            return (controller.responds(to: #selector(getter: GCExtendedGamepad.leftThumbstickButton))) && controller.leftThumbstickButton != nil
        } else {
            // Fallback on earlier versions
        }
        return false
    }
}

// MARK: Pause/Home
public extension GCController {
    /// Binds the pause triggers that arrive through a handler the pad calls.
    ///
    /// An extended gamepad's own buttons (Options, Share, L3 + R3, Select + Start, Home)
    /// are not bound here: `PauseMenuTriggerMonitor` samples them while a game runs, so
    /// they neither replace a core's button handlers nor get replaced by them. What is
    /// left is `controllerPausedHandler`, for:
    /// - a Switch Online pad, whose wrapper fires it from its own trigger (Home, or
    ///   Select + Start on the SNES pad);
    /// - the Siri Remote and other pads with no extended profile;
    /// - a first-generation MFi pad whose one Menu button is all it has.
    ///
    /// `buttonMenu` is the emulated Start on every extended gamepad and `buttonHome`
    /// belongs to the system, so neither opens the menu on a pad that has an Options button.
    func setupPauseHandler(onPause: @escaping (PauseMenuTrigger) -> Void) {
        let name = vendorName ?? "unknown"
        /// The handler-driven triggers do not depend on the running system.
        let plan = PauseMenuBindingPolicy.plan(for: pauseMenuCapabilities, systemUsesSelect: true)
        guard let trigger = plan.triggers.first(where: { $0 == .profileTrigger || $0 == .legacyPause }) else {
            controllerPausedHandler = nil
            return
        }
        ILOG("setupPauseHandler[\(name)]: \(trigger.rawValue) through controllerPausedHandler")
        controllerPausedHandler = { _ in
            ILOG("setupPauseHandler[\(name)]: \(trigger.rawValue) fired")
            onPause(trigger)
        }
    }

    func clearPauseHandler() {
        controllerPausedHandler = nil
    }

    public var buttonMenu: GCControllerButtonInput? {
        return extendedGamepad?.buttonMenu ?? microGamepad?.buttonMenu
    }

    public var buttonOptions: GCControllerButtonInput? {
        return extendedGamepad?.buttonOptions
    }

    public var buttonHome: GCControllerButtonInput? {
        if #available(iOS 14.0, tvOS 14.0, *) {
            return extendedGamepad?.buttonHome
        }
        return nil
    }
}
