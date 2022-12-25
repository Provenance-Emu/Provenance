//
//  GCControllerExtensions.swift
//  Provenance
//
//  Created by Sev Gerk on 1/27/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

import GameController

// MARK: ThumbSticks
extension GCController {
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
extension GCController {
    func setupPauseHandler(onPause: @escaping () -> Void) {
        // Use buttonHome for iOS/tvOS14 and later
        if let buttonHome = buttonHome {
            buttonHome.pressedChangedHandler = { _, _, isPressed in
                if isPressed {
                    onPause()
                }
            }
        }
        // Using buttonMenu is the recommended way for iOS/tvOS13 and later
        else if let buttonMenu = buttonMenu {
            buttonMenu.pressedChangedHandler = { _, _, isPressed in
                if isPressed {
                    onPause()
                }
            }
        } else {
            // Fallback to the old method
            controllerPausedHandler = { _ in
                onPause()
            }
        }
    }

	func clearPauseHandler() {
		// Use buttonHome for iOS/tvOS14 and later
		if let buttonHome = buttonHome {
			buttonHome.pressedChangedHandler = nil
		}
		// Using buttonMenu is the recommended way for iOS/tvOS13 and later
		if let buttonMenu = buttonMenu {
			buttonMenu.pressedChangedHandler = nil
		} else {
			// Fallback to the old method
			controllerPausedHandler = nil
		}
	}

    private var buttonMenu: GCControllerButtonInput? {
        return extendedGamepad?.buttonMenu ?? microGamepad?.buttonMenu
    }

    private var buttonOptions: GCControllerButtonInput? {
        return extendedGamepad?.buttonOptions
    }

    private var buttonHome: GCControllerButtonInput? {
        if #available(iOS 14.0, tvOS 14.0, *) {
            return extendedGamepad?.buttonHome
        }
        return nil
    }
}
