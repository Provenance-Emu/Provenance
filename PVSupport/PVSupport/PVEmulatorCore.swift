//
//  PVEmulatorCore.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 3/8/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import UIKit

// MARK: - Shared Protocolcs
@objc public protocol DiscSwappable {
    var currentGameSupportsMultipleDiscs: Bool {get}
    var numberOfDiscs: UInt {get}
    func swapDisc(number: UInt)
}

public struct CoreActionOption {
	public let title : String
	public let selected : Bool

	public init(title: String, selected: Bool = false) {
		self.title = title
		self.selected = selected
	}
}

public struct CoreAction {
	public let title : String
	public let requiresReset : Bool
	public let options : [CoreActionOption]?

	public init(title: String, requiresReset: Bool = false, options: [CoreActionOption]? = nil) {
		self.title = title
		self.requiresReset = requiresReset
		self.options = options
	}
}

public protocol CoreActions {
	var coreActions : [CoreAction]? { get }
	func selected(action : CoreAction)
}

@objc public protocol ResponderClient: class {

}

@objc public protocol ButtonResponder {
    func didPush(_ button: Int, forPlayer player: Int)
    func didRelease(_ button: Int, forPlayer player: Int)
}

@objc public protocol JoystickResponder {
    func didMoveJoystick(_ button: Int, withValue value: CGFloat, forPlayer player: Int)
}

@objc extension PVEmulatorCore: ResponderClient {}

// MARK: - Sega 32X
@objc public enum PVSega32XButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case c
    case x
    case y
    case z
    case start
    case mode
    case count
}

@objc public protocol PVSega32XSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushSega32XButton:forPlayer:)
    func didPush(_ button: PVSega32XButton, forPlayer player: Int)
    @objc(didReleaseSega32XButton:forPlayer:)
    func didRelease(_ button: PVSega32XButton, forPlayer player: Int)
}

// MARK: - N64
@objc public enum PVN64Button: Int {
    // D-Pad
    case dPadUp
    case dPadDown
    case dPadLeft
    case dPadRight
    // C buttons
    case cUp
    case cDown
    case cLeft
    case cRight
    case a
    case b
    // Shoulder buttons
    case l
    case r
    case z
    case start
    case analogUp
    case analogDown
    case analogLeft
    case analogRight
    case count
}

// FIXME: analog stick (x,y), memory pack, rumble pack
@objc public protocol PVN64SystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didMoveN64JoystickDirection:withValue:forPlayer:)
    func didMoveJoystick(_ button: PVN64Button, withValue value: CGFloat, forPlayer player: Int)
    @objc(didPushN64Button:forPlayer:)
    func didPush(_ button: PVN64Button, forPlayer player: Int)
    @objc(didReleaseN64Button:forPlayer:)
    func didRelease(_ button: PVN64Button, forPlayer player: Int)
}

// MARK: - Atari 2600
@objc public enum PV2600Button: Int {
    case up
    case down
    case left
    case right
    case fire1
    case leftDiffA
    case leftDiffB
    case rightDiffA
    case rightDiffB
    case reset
    case select
    case count
}

@objc public protocol PV2600SystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPV2600Button:forPlayer:)
    func didPush(_ button: PV2600Button, forPlayer player: Int)
    @objc(didReleasePV2600Button:forPlayer:)
    func didRelease(_ button: PV2600Button, forPlayer player: Int)
}

// MARK: - NES
@objc public enum PVNESButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case start
    case select
    case count
}

@objc public protocol PVNESSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushNESButton:forPlayer:)
    func didPush(_ button: PVNESButton, forPlayer player: Int)
    @objc(didReleaseNESButton:forPlayer:)
    func didRelease(_ button: PVNESButton, forPlayer player: Int)
}

// MARK: - Game Boy
@objc public enum PVGBButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case start
    case select
    case count
}

@objc public protocol PVGBSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushGBButton:forPlayer:)
    func didPush(_ button: PVGBButton, forPlayer player: Int)
    @objc(didReleaseGBButton:forPlayer:)
    func didRelease(_ button: PVGBButton, forPlayer player: Int)
}

// MARK: - Pokemon Mini
@objc public enum PVPMButton: Int {
    case menu
    case a
    case b
    case c
    case up
    case down
    case left
    case right
    case power
    case shake
}

@objc public protocol PVPokeMiniSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPMButton:forPlayer:)
    func didPush(_ button: PVPMButton, forPlayer player: Int)
    @objc(didReleasePMButton:forPlayer:)
    func didRelease(_ button: PVPMButton, forPlayer player: Int)
}

// MARK: - SNES
@objc public enum PVSNESButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case x
    case y
    case triggerLeft
    case triggerRight
    case start
    case select
    case count
}

@objc public protocol PVSNESSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushSNESButton:forPlayer:)
    func didPush(_ button: PVSNESButton, forPlayer player: Int)
    @objc(didReleaseSNESButton:forPlayer:)
    func didRelease(_ button: PVSNESButton, forPlayer player: Int)
}

// MARK: - Atari 7800
@objc public enum PV7800Button: Int {
    case up
    case down
    case left
    case right
    case fire1
    case fire2
    case select
    case pause
    case reset
    case leftDiff
    case rightDiff
    case count
}

@objc public protocol PV7800SystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPush7800Button:forPlayer:)
    func didPush(_ button: PV7800Button, forPlayer player: Int)
    @objc(didRelease7800Button:forPlayer:)
    func didRelease(_ button: PV7800Button, forPlayer player: Int)

    func mouseMoved(at point: CGPoint)
    func leftMouseDown(at point: CGPoint)
    func leftMouseUp()
}

// MARK: - Genesis
@objc public enum PVGenesisButton: Int {
    case b = 0
    case a
    case mode
    case start
    case up
    case down
    case left
    case right
    case c
    case y
    case x
    case z
    case count
}

@objc public protocol PVGenesisSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushGenesisButton:forPlayer:)
    func didPush(_ button: PVGenesisButton, forPlayer player: Int)
    @objc(didReleaseGenesisButton:forPlayer:)
    func didRelease(_ button: PVGenesisButton, forPlayer player: Int)
}

// MARK: - Master System
@objc public enum PVMasterSystemButton: Int {
    case b = 0
    case c
    case start
    case up
    case down
    case left
    case right
    case count
}

@objc public protocol PVMasterSystemSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushMasterSystemButton:forPlayer:)
    func didPush(_ button: PVMasterSystemButton, forPlayer player: Int)
    @objc(didReleaseMasterSystemButton:forPlayer:)
    func didRelease(_ button: PVMasterSystemButton, forPlayer player: Int)
}

// MARK: - SG1000
@objc public enum PVSG1000Button: Int {
    case b = 0
    case c
    case start
    case up
    case down
    case left
    case right
    case count
}

@objc public protocol PVSG1000SystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushSG1000Button:forPlayer:)
    func didPush(_ button: PVSG1000Button, forPlayer player: Int)
    @objc(didReleaseSG1000Button:forPlayer:)
    func didRelease(_ button: PVSG1000Button, forPlayer player: Int)
}

// MARK: - Game Boy Advanced
@objc public enum PVGBAButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case l
    case r
    case start
    case select
    case count
}

@objc public protocol PVGBASystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushGBAButton:forPlayer:)
    func didPush(_ button: PVGBAButton, forPlayer player: Int)
    @objc(didReleaseGBAButton:forPlayer:)
    func didRelease(_ button: PVGBAButton, forPlayer player: Int)
}

// MARK: - Atari 5200
@objc public enum PV5200Button: Int {
    case up
    case down
    case left
    case right
    case fire1
    case fire2
    case start
    case pause
    case reset
    case number1
    case number2
    case number3
    case number4
    case number5
    case number6
    case number7
    case number8
    case number9
    case number0
    case asterisk
    case pound
    case count
}

@objc public protocol PV5200SystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPush5200Button:forPlayer:)
    func didPush(_ button: PV5200Button, forPlayer player: Int)
    @objc(didRelease5200Button:forPlayer:)
    func didRelease(_ button: PV5200Button, forPlayer player: Int)
}

@objc public enum PVA8Button: Int {
    case up
    case down
    case left
    case right
    case fire
    case count
}

@objc public protocol PVA8SystemResponderClient: ResponderClient, ButtonResponder {
    func mouseMoved(at point: CGPoint)
    func leftMouseDown(at point: CGPoint)
    func leftMouseUp()
    func rightMouseDown(at point: CGPoint)
    func rightMouseUp()
    @objc(didPushA8Button:forPlayer:)
    func didPush(_ button: PVA8Button, forPlayer player: Int)
    @objc(didReleaseA8Button:forPlayer:)
    func didRelease(_ button: PVA8Button, forPlayer player: Int)
}

// MARK: - PSX

@objc public enum PVPSXButton: Int {
    case up
    case down
    case left
    case right
    case triangle
    case circle
    case cross
    case square
    case l1
    case l2
    case l3
    case r1
    case r2
    case r3
    case start
    case select
    case analogMode
    case leftAnalogUp
    case leftAnalogDown
    case leftAnalogLeft
    case leftAnalogRight
    case rightAnalogUp
    case rightAnalogDown
    case rightAnalogLeft
    case rightAnalogRight
    case count
}

@objc public protocol PVPSXSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPushPSXButton:forPlayer:)
    func didPush(_ button: PVPSXButton, forPlayer player: Int)

    @objc(didReleasePSXButton:forPlayer:)
    func didRelease(_ button: PVPSXButton, forPlayer player: Int)

    @objc(didMovePSXJoystickDirection:withValue:forPlayer:)
    func didMoveJoystick(_ button: PVPSXButton, withValue value: CGFloat, forPlayer player: Int)
}

// MARK: - WonderSwan

@objc public enum PVWSButton: Int {
    case x1
    // Up
    case x3
    // Down
    case x4
    // Left
    case x2
    // Right
    case y1
    case y3
    case y4
    case y2
    case a
    case b
    case start
    case sound
    case count
}

@objc public protocol PVWonderSwanSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushWSButton:forPlayer:)
    func didPush(_ button: PVWSButton, forPlayer player: Int)
    @objc(didReleaseWSButton:forPlayer:)
    func didRelease(_ button: PVWSButton, forPlayer player: Int)
}

// MARK: - VirtualBoy

@objc public enum PVVBButton: Int {
    case leftUp
    case leftDown
    case leftLeft
    case leftRight
    case rightUp
    case rightDown
    case rightLeft
    case rightRight
    case l
    case r
    case a
    case b
    case start
    case select
    case count
}

@objc public protocol PVVirtualBoySystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushVBButton:forPlayer:)
    func didPush(_ button: PVVBButton, forPlayer player: Int)
    @objc(didReleaseVBButton:forPlayer:)
    func didRelease(_ button: PVVBButton, forPlayer player: Int)
}

// MARK: - PCE
@objc public enum PVPCEButton: Int {
    case up
    case down
    case left
    case right
    case button1
    case button2
    case button3
    case button4
    case button5
    case button6
    case run
    case select
    case mode
    case count
}

@objc public protocol PVPCESystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPCEButton:forPlayer:)
    func didPush(_ button: PVPCEButton, forPlayer player: Int)
    @objc(didReleasePCEButton:forPlayer:)
    func didRelease(_ button: PVPCEButton, forPlayer player: Int)
}

// MARK: - PCE FX
@objc public enum PVPCFXButton: Int {
    case up
    case down
    case left
    case right
    case button1
    case button2
    case button3
    case button4
    case button5
    case button6
    case run
    case select
	case mode
    case count
}

@objc public protocol PVPCFXSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPCFXButton:forPlayer:)
    func didPush(_ button: PVPCFXButton, forPlayer player: Int)
    @objc(didReleasePCFXButton:forPlayer:)
    func didRelease(_ button: PVPCFXButton, forPlayer player: Int)
}

// MARK: - PCE CD
@objc public enum PVPCECDButton: Int {
    case up
    case down
    case left
    case right
    case button1
    case button2
    case button3
    case button4
    case button5
    case button6
    case run
    case select
    case mode
    case count
}

@objc public protocol PVPCECDSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushPCECDButton:forPlayer:)
    func didPush(_ button: PVPCECDButton, forPlayer player: Int)
    @objc(didReleasePCECDButton:forPlayer:)
    func didRelease(_ button: PVPCECDButton, forPlayer player: Int)
}

// MARK: - Atari Lynx
@objc public enum PVLynxButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case option1
    case option2
    case count
}

@objc public protocol PVLynxSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushLynxButton:forPlayer:)
    func didPush(_ button: PVLynxButton, forPlayer player: Int)
    @objc(didReleaseLynxButton:forPlayer:)
    func didRelease(_ button: PVLynxButton, forPlayer player: Int)
}

// MARK: - Neo Geo Pocket + Color
@objc public enum PVNGPButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case option
    case count
}
@objc public protocol PVNeoGeoPocketSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushNGPButton:forPlayer:)
    func didPush(_ button: PVNGPButton, forPlayer player: Int)
    @objc(didReleaseNGPButton:forPlayer:)
    func didRelease(_ button: PVNGPButton, forPlayer player: Int)
}
