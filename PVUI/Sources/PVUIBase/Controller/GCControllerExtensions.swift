//
//  GCControllerExtensions.swift
//  Provenance
//
//  Created by Sev Gerk on 1/27/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

import GameController
import PVLogging

// MARK: - Controller Notifications

public extension Notification.Name {
    /// Posted when the DualSense microphone button is pressed and the user action is "muteAudio".
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
    /// Configure controller to fire `onPause` when the user presses the pause/menu button.
    ///
    /// **tvOS** (PVEmulatorViewController is a GCEventViewController):
    /// - `buttonHome` (PS/Xbox/Guide) is system-reserved for Control Center on tvOS.
    ///   We do NOT bind a handler on it because it races with Control Center's
    ///   presentation and corrupts the VC's modal state. Instead, the app lifecycle code
    ///   (`shouldShowPauseMenuOnNextActive` in `appWillResignActive`/`appDidBecomeActive`)
    ///   cleanly shows the pause menu when the user returns from Control Center.
    /// - `buttonMenu` (Options on PS / Menu on Xbox) is mapped to Start in emulator cores.
    ///   `controllerPausedHandler` fires for the same physical button. Neither can be used
    ///   for pause menu on modern controllers without conflicting with Start.
    /// - **L3 + R3** (both thumbstick buttons) is the primary reliable trigger for modern
    ///   controllers. No emulated system uses clickable thumbsticks, so there is no conflict.
    ///   Not system-intercepted. Available on PS, Xbox, and Switch Pro controllers.
    /// - Legacy MFi controllers (Nimbus etc.) have no thumbstick buttons or Home button.
    ///   For these, `controllerPausedHandler` fires for their single Menu button.
    /// - Siri remote: `controllerPausedHandler` fires for its Menu button via GCController
    ///   framework when `controllerUserInteractionEnabled = false` on GCEventViewController.
    ///
    /// **iOS**: Both `buttonHome` and `buttonMenu` handlers are bound (no system
    /// interception). `controllerPausedHandler` is set as fallback for legacy controllers.
    func setupPauseHandler(onPause: @escaping () -> Void) {
        let name = vendorName ?? "unknown"
        #if os(tvOS)
        var hasHandler = false

        /// L3 + R3 combo — primary reliable pause trigger on tvOS for modern controllers.
        /// When either thumbstick button is pressed, check if the other is already held.
        if let gamepad = extendedGamepad,
           let l3 = gamepad.leftThumbstickButton,
           let r3 = gamepad.rightThumbstickButton {
            ILOG("setupPauseHandler[\(name)]: binding L3+R3 combo")
            l3.pressedChangedHandler = { [weak gamepad] _, _, isPressed in
                if isPressed, gamepad?.rightThumbstickButton?.isPressed == true {
                    ILOG("setupPauseHandler[\(name)]: L3+R3 combo detected — firing pause")
                    onPause()
                }
            }
            r3.pressedChangedHandler = { [weak gamepad] _, _, isPressed in
                if isPressed, gamepad?.leftThumbstickButton?.isPressed == true {
                    ILOG("setupPauseHandler[\(name)]: R3+L3 combo detected — firing pause")
                    onPause()
                }
            }
            hasHandler = true
        }

        if !hasHandler {
            /// Legacy MFi / Siri remote without thumbstick buttons.
            /// controllerPausedHandler fires for their Menu button.
            ILOG("setupPauseHandler[\(name)]: no thumbsticks — using controllerPausedHandler")
            controllerPausedHandler = { _ in
                ILOG("setupPauseHandler[\(name)]: controllerPausedHandler fired — firing pause")
                onPause()
            }
        }
        #else
        var hasHandler = false
        if let buttonHome = buttonHome {
            buttonHome.pressedChangedHandler = { _, _, isPressed in
                if isPressed {
                    onPause()
                }
            }
            hasHandler = true
        }
        if let buttonMenu = buttonMenu {
            buttonMenu.pressedChangedHandler = { _, _, isPressed in
                if isPressed {
                    onPause()
                }
            }
            hasHandler = true
        }
        if !hasHandler {
            controllerPausedHandler = { _ in
                onPause()
            }
        }
        #endif
    }

    func clearPauseHandler() {
        controllerPausedHandler = nil
        #if os(tvOS)
        if let gamepad = extendedGamepad {
            gamepad.leftThumbstickButton?.pressedChangedHandler = nil
            gamepad.rightThumbstickButton?.pressedChangedHandler = nil
        }
        #else
        buttonHome?.pressedChangedHandler = nil
        buttonMenu?.pressedChangedHandler = nil
        #endif
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
