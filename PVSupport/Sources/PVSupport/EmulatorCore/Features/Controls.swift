//
//  Controls.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 12/27/18.
//  Copyright © 2018 Provenance Emu. All rights reserved.
//

import Foundation

@objc public protocol ResponderClient: AnyObject {}

@objc public protocol ButtonResponder {
	var valueChangedHandler: GCExtendedGamepadValueChangedHandler? { get }

    func didPush(_ button: Int, forPlayer player: Int)
    func didRelease(_ button: Int, forPlayer player: Int)
}

@objc public protocol JoystickResponder {
    func didMoveJoystick(_ button: Int, withValue value: CGFloat, forPlayer player: Int)
}

@objc public protocol KeyboardResponder {
	var gameSupportsKeyboard: Bool { get }
	var requiresKeyboard: Bool { get }

	var keyChangedHandler: GCKeyboardValueChangedHandler? { get }

    @available(iOS 14.0, tvOS 14.0, *)
	func keyDown(_ key: GCKeyCode)
//	func keyDown(_ key: GCKeyCode, chararacters: String, charactersIgnoringModifiers: String)

    @available(iOS 14.0, tvOS 14.0, *)
    func keyUp(_ key: GCKeyCode)
//	func keyUp(_ key: GCKeyCode, chararacters: String, charactersIgnoringModifiers: String)
}

@objc public enum MouseButton: Int {
	case left
	case right
	case middle
	case auxiliary
}

@objc public protocol MouseResponder {
	var gameSupportsMouse: Bool { get }
	var requiresMouse: Bool { get }

    @available(iOS 14.0, tvOS 14.0, *)
    func didScroll(_ cursor: GCDeviceCursor)

	var mouseMovedHandler: GCMouseMoved? { get }
	func mouseMoved(atPoint point: CGPoint)

	func leftMouseDown(atPoint point: CGPoint)
	func leftMouseUp()

	func rightMouseDown(atPoint point: CGPoint)
	func rightMouseUp()
}

@objc public enum Touchpad: Int {
	case primary
	case secondary
}

@objc public protocol TouchPadResponder {
	var touchedChangedHandler: GCControllerButtonTouchedChangedHandler? { get }
	var pressedChangedHandler: GCControllerButtonValueChangedHandler? { get }
	var valueChangedHandler: GCControllerButtonValueChangedHandler? { get }

	var gameSupportsTouchpad: Bool { get }
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

// MARK: - GameCube

@objc public enum PVGameCubeButton: Int {
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
@objc public protocol PVGameCubeSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
	@objc(didMoveGameCubeJoystickDirection:withValue:forPlayer:)
	func didMoveJoystick(_ button: PVGameCubeButton, withValue value: CGFloat, forPlayer player: Int)
	@objc(didPushGameCubeButton:forPlayer:)
	func didPush(_ button: PVGameCubeButton, forPlayer player: Int)
	@objc(didReleaseGameCubeButton:forPlayer:)
	func didRelease(_ button: PVGameCubeButton, forPlayer player: Int)
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

// MARK: - Deamcast

@objc public enum PVDreamcastButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case x
    case y
    case l
    case r
    case start
    // Joystick
    case analogUp
    case analogDown
    case analogLeft
    case analogRight
    case count
}

@objc public protocol PVDreamcastSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPushDreamcastButton:forPlayer:)
    func didPush(_ button: PVDreamcastButton, forPlayer player: Int)
    @objc(didReleaseDreamcastButton:forPlayer:)
    func didRelease(_ button: PVDreamcastButton, forPlayer player: Int)

    @objc(didMoveDreamcastJoystickDirection:withValue:forPlayer:)
    func didMoveJoystick(_ button: PVDreamcastButton, withValue value: CGFloat, forPlayer player: Int)
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

// MARK: - Game Boy DS

@objc public enum PVDSButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case x
    case y
    case l
    case r
    case start
    case select
    case count
}

@objc public protocol PVDSSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushDSButton:forPlayer:)
    func didPush(_ button: PVDSButton, forPlayer player: Int)
    @objc(didReleaseDSButton:forPlayer:)
    func didRelease(_ button: PVDSButton, forPlayer player: Int)
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

@objc public protocol PV5200SystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPush5200Button:forPlayer:)
    func didPush(_ button: PV5200Button, forPlayer player: Int)
    @objc(didRelease5200Button:forPlayer:)
    func didRelease(_ button: PV5200Button, forPlayer player: Int)
    
    @objc(didMove5200JoystickDirection:withValue:forPlayer:)
    func didMoveJoystick(_ button: PV5200Button, withValue value: CGFloat, forPlayer player: Int)
}

@objc public enum PVA8Button: Int {
    case up
    case down
    case left
    case right
    case fire
    case count
}

@objc public protocol PVA8SystemResponderClient: ResponderClient, ButtonResponder, KeyboardResponder, MouseResponder {
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

// MARK: - PS2

@objc public enum PVPS2Button: Int {
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

@objc public protocol PVPS2SystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPushPS2Button:forPlayer:)
    func didPush(_ button: PVPS2Button, forPlayer player: Int)

    @objc(didReleasePS2Button:forPlayer:)
    func didRelease(_ button: PVPS2Button, forPlayer player: Int)

    @objc(didMovePS2JoystickDirection:withValue:forPlayer:)
    func didMoveJoystick(_ button: PVPS2Button, withValue value: CGFloat, forPlayer player: Int)
}

// MARK: - PSP

@objc public enum PVPSPButton: Int {
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
    case count
}

@objc public protocol PVPSPSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didPushPSPButton:forPlayer:)
    func didPush(_ button: PVPSPButton, forPlayer player: Int)

    @objc(didReleasePSPButton:forPlayer:)
    func didRelease(_ button: PVPSPButton, forPlayer player: Int)

    @objc(didMovePSPJoystickDirection:withValue:forPlayer:)
    func didMoveJoystick(_ button: PVPSPButton, withValue value: CGFloat, forPlayer player: Int)
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

// MARK: - Atari Jaguar

@objc public enum PVJaguarButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case c
    case pause
    case option
    @objc(PVJaguarButton1)
    case button1
    @objc(PVJaguarButton2)
    case button2
    @objc(PVJaguarButton3)
    case button3
    @objc(PVJaguarButton4)
    case button4
    @objc(PVJaguarButton5)
    case button5
    @objc(PVJaguarButton6)
    case button6
    @objc(PVJaguarButton7)
    case button7
    @objc(PVJaguarButton8)
    case button8
    @objc(PVJaguarButton9)
    case button9
    @objc(PVJaguarButton0)
    case button0
    case asterisk
    case pound
    case count
}

@objc public protocol PVJaguarSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushJaguarButton:forPlayer:)
    func didPush(_ button: PVJaguarButton, forPlayer player: Int)
    @objc(didReleaseJaguarButton:forPlayer:)
    func didRelease(_ button: PVJaguarButton, forPlayer player: Int)
}

// MARK: - Sega Saturn

@objc public enum PVSaturnButton: Int {
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
    case l
    case r
    case start
    case count
}

@objc public protocol PVSaturnSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushSSButton:forPlayer:)
    func didPush(_ button: PVSaturnButton, forPlayer player: Int)
    @objc(didReleaseSSButton:forPlayer:)
    func didRelease(_ button: PVSaturnButton, forPlayer player: Int)
}

// MARK: - Magnavox Odyssey2/Videopac+

@objc public enum PVOdyssey2Button: Int {
    case up
    case down
    case left
    case right
    case action
    case count
}

@objc public protocol PVOdyssey2SystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushOdyssey2Button:forPlayer:)
    func didPush(_ button: PVOdyssey2Button, forPlayer player: Int)
    @objc(didReleaseOdyssey2Button:forPlayer:)
    func didRelease(_ button: PVOdyssey2Button, forPlayer player: Int)
}

// MARK: - Vectrex

@objc public enum PVVectrexButton: Int {
    @objc(PVVectrexAnalogUp)
    case analogUp
    @objc(PVVectrexAnalogDown)
    case analogDown
    @objc(PVVectrexAnalogLeft)
    case analogLeft
    @objc(PVVectrexAnalogRight)
    case analogRight
    @objc(PVVectrexButton1)
    case button1
    @objc(PVVectrexButton2)
    case button2
    @objc(PVVectrexButton3)
    case button3
    @objc(PVVectrexButton4)
    case button4
    case count
}

@objc public protocol PVVectrexSystemResponderClient: ResponderClient, ButtonResponder, JoystickResponder {
    @objc(didMoveVectrexJoystickDirection:withValue:forPlayer:)
    func didMoveJoystick(_ button: PVVectrexButton, withValue value: CGFloat, forPlayer player: Int)
    @objc(didPushVectrexButton:forPlayer:)
    func didPush(_ button: PVVectrexButton, forPlayer player: Int)
    @objc(didReleaseVectrexButton:forPlayer:)
    func didRelease(_ button: PVVectrexButton, forPlayer player: Int)
}

// MARK: - 3DO

@objc public enum PV3DOButton: Int {
    case up
    case down
    case left
    case right
    case a
    case b
    case c
    case L
    case R
    case P
    case X
    case count
}

@objc public protocol PV3DOSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPush3DOButton:forPlayer:)
    func didPush(_ button: PV3DOButton, forPlayer player: Int)
    @objc(didRelease3DOButton:forPlayer:)
    func didRelease(_ button: PV3DOButton, forPlayer player: Int)
}

// MARK: - ColecoVision

@objc public enum PVColecoVisionButton: Int {
    case up
    case down
    case left
    case right
    case leftAction
    case rightAction
    @objc(PVColecoVisionButton1)
    case button1
    @objc(PVColecoVisionButton2)
    case button2
    @objc(PVColecoVisionButton3)
    case button3
    @objc(PVColecoVisionButton4)
    case button4
    @objc(PVColecoVisionButton5)
    case button5
    @objc(PVColecoVisionButton6)
    case button6
    @objc(PVColecoVisionButton7)
    case button7
    @objc(PVColecoVisionButton8)
    case button8
    @objc(PVColecoVisionButton9)
    case button9
    @objc(PVColecoVisionButton0)
    case button0
    case asterisk
    case pound
    case count
}

@objc public protocol PVColecoVisionSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushColecoVisionButton:forPlayer:)
    func didPush(_ button: PVColecoVisionButton, forPlayer player: Int)
    @objc(didReleaseColecoVisionButton:forPlayer:)
    func didRelease(_ button: PVColecoVisionButton, forPlayer player: Int)
}

// MARK: - Intellivision

@objc public enum PVIntellivisionButton: Int {
    case up
    case down
    case left
    case right
    case topAction
    case bottomLeftAction
    case bottomRightAction
    @objc(PVIntellivisionButton1)
    case button1
    @objc(PVIntellivisionButton2)
    case button2
    @objc(PVIntellivisionButton3)
    case button3
    @objc(PVIntellivisionButton4)
    case button4
    @objc(PVIntellivisionButton5)
    case button5
    @objc(PVIntellivisionButton6)
    case button6
    @objc(PVIntellivisionButton7)
    case button7
    @objc(PVIntellivisionButton8)
    case button8
    @objc(PVIntellivisionButton9)
    case button9
    @objc(PVIntellivisionButton0)
    case button0
    case clear
    case enter
    case count
}

@objc public protocol PVIntellivisionSystemResponderClient: ResponderClient, ButtonResponder {
    @objc(didPushIntellivisionButton:forPlayer:)
    func didPush(_ button: PVIntellivisionButton, forPlayer player: Int)
    @objc(didReleaseIntellivisionButton:forPlayer:)
    func didRelease(_ button: PVIntellivisionButton, forPlayer player: Int)
}

// MARK: - PC DOS

@objc public enum PVDOSButton: Int {
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

@objc public protocol PVDOSSystemResponderClient: ResponderClient, ButtonResponder, KeyboardResponder, MouseResponder {
    @objc(didPushDOSButton:forPlayer:)
    func didPush(_ button: PVDOSButton, forPlayer player: Int)
    @objc(didReleaseDOSButton:forPlayer:)
    func didRelease(_ button: PVDOSButton, forPlayer player: Int)

    func mouseMoved(at point: CGPoint)
    func leftMouseDown(at point: CGPoint)
    func leftMouseUp()
}


// MARK: - EP128
 @objc public enum PVEP128Button: Int {
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

 @objc public protocol PVEP128SystemResponderClient: ResponderClient, ButtonResponder, KeyboardResponder, MouseResponder {
	 @objc(didPushEP128Button:forPlayer:)
	 func didPush(_ button: PVEP128Button, forPlayer player: Int)
	 @objc(didReleaseEP128Button:forPlayer:)
	 func didRelease(_ button: PVEP128Button, forPlayer player: Int)

	 func mouseMoved(at point: CGPoint)
	 func leftMouseDown(at point: CGPoint)
	 func leftMouseUp()
 }
