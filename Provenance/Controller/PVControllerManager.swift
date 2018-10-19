//  Converted to Swift 4 by Swiftify v4.1.6640 - https://objectivec2swift.com/
//
//  PVControllerManager.swift
//  Provenance
//
//  Created by James Addyman on 19/09/2015.
//  Copyright © 2015 James Addyman. All rights reserved.
//

import Foundation
import GameController
import VirtualGameController

import PVLibrary
import PVSupport

extension Notification.Name {
    static let PVControllerManagerControllerReassigned = Notification.Name("PVControllerManagerControllerReassignedNotification")
}

#if (arch(i386) || arch(x86_64))
let isSimulator = true
#else
let isSimulator = false
#endif

class PVControllerManager: NSObject {

    var allLiveControllers: [Int: VgcController] {
        var allLiveControllers = [Int:VgcController]()
        if let player1 = player1 {
            allLiveControllers[1] = player1
        }
        if let player2 = player2 {
            allLiveControllers[2] = player2
        }
        if let player3 = player3 {
            allLiveControllers[3] = player3
        }
        if let player4 = player4 {
            allLiveControllers[4] = player4
        }

        return allLiveControllers
    }

    private(set) var player1: VgcController? {
        didSet {
            if player1 != oldValue {
                setController(player1, toPlayer: 1)
            }
        }
    }
    private(set) var player2: VgcController? {
        didSet {
            if player2 != oldValue {
                setController(player2, toPlayer: 2)
            }
        }
    }
    private(set) var player3: VgcController? {
        didSet {
            if player3 != oldValue {
                setController(player3, toPlayer: 3)
            }
        }
    }
    private(set) var player4: VgcController? {
        didSet {
            if player4 != oldValue {
                setController(player4, toPlayer: 4)
            }
        }
    }

    var hasControllers: Bool {
        return player1 != nil || player2 != nil || player3 != nil || player4 != nil
    }

    static let shared: PVControllerManager = PVControllerManager()

    override init() {
        super.init()

        //
        if isSimulator {
            return
        }

		VgcController.enableIcadeController()
		VgcController.startWirelessControllerDiscoveryWithCompletionHandler { () -> Void in

			vgcLogDebug("SAMPLE: Discovery completion handler executed")
			ILOG("Controller connected")
		}

		NotificationCenter.default.addObserver(self, selector: #selector(self.handleControllerDidConnect(_:)), name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)
				NotificationCenter.default.addObserver(self, selector: #selector(self.handleControllerDidDisconnect(_:)), name: NSNotification.Name(rawValue: VgcControllerDidDisconnectNotification), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleControllerDidConnect(_:)), name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PVControllerManager.handleControllerDidDisconnect(_:)), name: .GCControllerDidDisconnect, object: nil)
        UserDefaults.standard.addObserver(self as NSObject, forKeyPath: "kICadeControllerSettingKey", options: .new, context: nil)
        // automatically assign the first connected controller to player 1
        // prefer gamepad or extendedGamepad over a microGamepad
        assignControllers()
    }

	func isAssigned(_ controller : VgcController) -> Bool {
		return allLiveControllers.contains(where: { (index, existingController) -> Bool in
			return controller == existingController
		})
	}

	func index(forController controller : VgcController) -> Int? {
		if let (index, _) = allLiveControllers.first(where: { (index, existingController) -> Bool in
			controller == existingController
		}) {
			return index
		} else {
			return nil
		}
	}

    @objc func handleControllerDidConnect(_ note: Notification?) {
        guard let controller = note?.object as? VgcController else {
            ELOG("Object wasn't a VgcController")
            return
        }

        ILOG("Controller connected: \(controller.vendorName)")
        assign(controller)
    }

    @objc func handleControllerDidDisconnect(_ note: Notification?) {
        guard let controller = note?.object as? VgcController else {
            ELOG("Object wasn't a VgcController")
            return
        }

        ILOG("Controller disconnected: \(controller.vendorName)")

        if controller == player1 {
            player1 = nil
        } else if controller == player2 {
            player2 = nil
        } else if controller == player3 {
            player3 = nil
        } else if controller == player4 {
            player4 = nil
        }

        let assigned = assignControllers()

        if !assigned {
            NotificationCenter.default.post(name: NSNotification.Name.PVControllerManagerControllerReassigned, object: self)
        }
    }

// MARK: - Controllers assignment
    func setController(_ controller: VgcController?, toPlayer player: Int) {
		if let controller = controller, let currentIndex = index(forController: controller), currentIndex != player {
			setController(nil, toPlayer: currentIndex)
		}

		controller?.playerIndex = GCControllerPlayerIndex(rawValue: player - 1)!
        // TODO: keep an array of players/controllers we support more than 2 players
        if player == 1 {
            player1 = controller
        } else if player == 2 {
            player2 = controller
        } else if player == 3 {
            player3 = controller
        } else if player == 4 {
            player4 = controller
        }

        if let controller = controller {
            ILOG("Controller [\(controller.vendorName ?? "No Vendor")] assigned to player \(player)")
        }
    }

    func controller(forPlayer player: Int) -> VgcController? {
        return allLiveControllers[player]
    }

    @discardableResult
    func assignControllers() -> Bool {
        var controllers = VgcController.controllers()

        var assigned = false
        controllers.forEach { controller in
            if !allLiveControllers.contains(where: { (number, existingController) -> Bool in
                return controller == existingController
            }) {
                assigned = assigned || assign(controller)
            }
        }

        return assigned
    }

    @discardableResult
    func assign(_ controller: VgcController) -> Bool {

		if isAssigned(controller) {
			return false
		}

		ILOG("Assign controller \(controller.vendorName)")
        // Assign the controller to the first player without a controller assigned, or
        // if this is an extended controller, replace the first controller which is not extended (the Siri remote on tvOS).
        for i in 1...4 {

            let previouslyAssignedController: VgcController? = self.controller(forPlayer: i)
            let newGamepadNotRemote = controller.gamepad != nil || controller.extendedGamepad != nil
            let previousGamepadNotRemote = previouslyAssignedController?.gamepad != nil || previouslyAssignedController?.extendedGamepad != nil

			// Skip making duplicate
			if let previouslyAssignedController = previouslyAssignedController, previouslyAssignedController == controller {
				continue
			}

            if previouslyAssignedController == nil || (newGamepadNotRemote && !previousGamepadNotRemote) {
                setController(controller, toPlayer: i)
                // Move the previously assigned controller to another player
                if let previouslyAssignedController = previouslyAssignedController {
					ILOG("Controller #\(i) \(previouslyAssignedController.vendorName) being reassigned")
                    assign(previouslyAssignedController)
                }
                NotificationCenter.default.post(name: NSNotification.Name.PVControllerManagerControllerReassigned, object: self)
                return true
            }
        }
        return false
    }
}
