//
//  PVThinLibretroCore+Controls.swift
//  PVCoreBridgeRetro
//
//  Created by Claude (Agent) on 2026-03-16.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Provides controller/responder protocol conformances for the thin libretro
//  wrapper. Each system-specific protocol maps its button enum to the standard
//  RETRO_DEVICE_ID_JOYPAD_* bitmask stored in PVThinLibretroFrontend.
//
//  The approach:
//  - `_bridge.setButton(retroId, pressed:, forPlayer:)` sets/clears a bit
//    in the per-player uint16_t joypad bitmask.
//  - `_bridge.setAnalogIndex(stickIdx, axis:, value:, forPlayer:)` sets analog
//    axis values that `thin_input_state` returns for RETRO_DEVICE_ANALOG queries.
//  - The static C callback `thin_input_state` reads these bitmasks each frame.
//

import Foundation
import PVCoreBridge
import PVLogging
import PVSystems
#if canImport(GameController)
import GameController
#endif

// MARK: - Per-system input capability flags (announced via core protocols)
// Keyboard and mouse support tables are private to this file (thin-libretro only).
// Light gun support is declared publicly on SystemIdentifier in PVCoreBridge so any
// core module can query it — see Controls+SystemIdentifier.swift.

private extension SystemIdentifier {

    // MARK: Keyboard

    /// Systems whose libretro cores accept keyboard input.
    var supportsKeyboard: Bool { Self.keyboardSystems.contains(self) }

    /// Systems that require a keyboard to be usable.
    var requiresKeyboard: Bool { Self.requiresKeyboardSystems.contains(self) }

    private static let keyboardSystems: Set<SystemIdentifier> = [
        ._3DO, .AppleII, .Atari8bit, .AtariST, .C64, .CDi, .ColecoVision,
        .DOOM, .DOS, .Dreamcast, .EP128, .Macintosh, .MAME, .MSX, .MSX2,
        .N64, .PalmOS, .PC98, .PSX, .Quake, .Quake2, .Saturn, .SNES, .TIC80, .Wolf3D, .ZXSpectrum,
    ]

    private static let requiresKeyboardSystems: Set<SystemIdentifier> = [
        .Atari8bit, .EP128, .TIC80, .ZXSpectrum,
    ]

    // MARK: Mouse

    /// Whether this system has *any* potential mouse support (always-on or game-specific).
    /// Consults the live registry state so dynamically registered systems are included.
    /// A `true` result does NOT mean the current game uses a mouse — call
    /// `MouseGameRegistry.shared.gameSupportsMouse(...)` for the definitive answer.
    var hasAnyMouseSupport: Bool {
        MouseGameRegistry.shared.systemHasAnyMouseSupport(self)
    }

}
// Note: supportsLightGun / requiresLightGun are public properties on SystemIdentifier
// defined in PVCoreBridge/Controls+SystemIdentifier.swift — no local override needed.

// MARK: - libretro joypad button IDs (mirrors libretro.h defines)
// These must match RETRO_DEVICE_ID_JOYPAD_* exactly.
private enum RetroJoypad: UInt32 {
    case b      = 0
    case y      = 1
    case select = 2
    case start  = 3
    case up     = 4
    case down   = 5
    case left   = 6
    case right  = 7
    case a      = 8
    case x      = 9
    case l      = 10
    case r      = 11
    case l2     = 12
    case r2     = 13
    case l3     = 14
    case r3     = 15
}

// MARK: - Analog constants
private let kAnalogLeftStick: UInt32  = 0
private let kAnalogRightStick: UInt32 = 1
private let kAnalogAxisX: UInt32      = 0
private let kAnalogAxisY: UInt32      = 1
private let kAnalogMax: Int16         = 0x7FFF

// MARK: - GCController polling for physical controllers

extension PVThinLibretroCore {

    /// Poll physical GCController state each frame and update the joypad bitmask.
    /// Called from the emulation thread via `thin_input_poll`.
    /// Without this, physical controllers have no effect in the thin wrapper
    /// (only DeltaSkin on-screen buttons would work via the responder protocols).
    @objc public func pollControllers() {
        for playerIndex in 0..<4 {
            let controller: GCController?
            switch playerIndex {
            case 0: controller = controller1
            case 1: controller = controller2
            case 2: controller = controller3
            case 3: controller = controller4
            default: controller = nil
            }
            guard let pad = controller?.extendedGamepad else { continue }

            let player = UInt32(playerIndex)
            // D-pad
            _bridge.setButton(RetroJoypad.up.rawValue, pressed: pad.dpad.up.isPressed || pad.leftThumbstick.up.value > 0.5, forPlayer: player)
            _bridge.setButton(RetroJoypad.down.rawValue, pressed: pad.dpad.down.isPressed || pad.leftThumbstick.down.value > 0.5, forPlayer: player)
            _bridge.setButton(RetroJoypad.left.rawValue, pressed: pad.dpad.left.isPressed || pad.leftThumbstick.left.value > 0.5, forPlayer: player)
            _bridge.setButton(RetroJoypad.right.rawValue, pressed: pad.dpad.right.isPressed || pad.leftThumbstick.right.value > 0.5, forPlayer: player)
            // Face buttons
            _bridge.setButton(RetroJoypad.b.rawValue, pressed: pad.buttonA.isPressed, forPlayer: player)
            _bridge.setButton(RetroJoypad.a.rawValue, pressed: pad.buttonB.isPressed, forPlayer: player)
            _bridge.setButton(RetroJoypad.y.rawValue, pressed: pad.buttonX.isPressed, forPlayer: player)
            _bridge.setButton(RetroJoypad.x.rawValue, pressed: pad.buttonY.isPressed, forPlayer: player)
            // Shoulders & triggers
            _bridge.setButton(RetroJoypad.l.rawValue, pressed: pad.leftShoulder.isPressed, forPlayer: player)
            _bridge.setButton(RetroJoypad.r.rawValue, pressed: pad.rightShoulder.isPressed, forPlayer: player)
            _bridge.setButton(RetroJoypad.l2.rawValue, pressed: pad.leftTrigger.isPressed, forPlayer: player)
            _bridge.setButton(RetroJoypad.r2.rawValue, pressed: pad.rightTrigger.isPressed, forPlayer: player)
            // Thumbstick clicks
            if let l3 = pad.leftThumbstickButton {
                _bridge.setButton(RetroJoypad.l3.rawValue, pressed: l3.isPressed, forPlayer: player)
            }
            if let r3 = pad.rightThumbstickButton {
                _bridge.setButton(RetroJoypad.r3.rawValue, pressed: r3.isPressed, forPlayer: player)
            }
            // Start / Select
            let menu = pad.buttonMenu
            _bridge.setButton(RetroJoypad.start.rawValue, pressed: menu.isPressed, forPlayer: player)
            
            if let options = pad.buttonOptions {
                _bridge.setButton(RetroJoypad.select.rawValue, pressed: options.isPressed, forPlayer: player)
            }
            // Analog sticks
            let lx = Int16(pad.leftThumbstick.xAxis.value * Float(kAnalogMax))
            let ly = Int16(-pad.leftThumbstick.yAxis.value * Float(kAnalogMax)) // Y inverted for libretro
            _bridge.setAnalogIndex(kAnalogLeftStick, axis: kAnalogAxisX, value: lx, forPlayer: player)
            _bridge.setAnalogIndex(kAnalogLeftStick, axis: kAnalogAxisY, value: ly, forPlayer: player)
            let rx = Int16(pad.rightThumbstick.xAxis.value * Float(kAnalogMax))
            let ry = Int16(-pad.rightThumbstick.yAxis.value * Float(kAnalogMax))
            _bridge.setAnalogIndex(kAnalogRightStick, axis: kAnalogAxisX, value: rx, forPlayer: player)
            _bridge.setAnalogIndex(kAnalogRightStick, axis: kAnalogAxisY, value: ry, forPlayer: player)
        }
    }
}

// MARK: - Helper extension on PVThinLibretroCore

extension PVThinLibretroCore {

    /// Press a libretro joypad button.
    fileprivate func pressButton(_ btn: RetroJoypad, forPlayer player: Int) {
        ILOG("ThinCore INPUT: pressButton \(btn) (id=\(btn.rawValue)) player=\(player) bridge=\(_bridge)")
        _bridge.setButton(btn.rawValue, pressed: true, forPlayer: UInt32(player))
    }

    /// Release a libretro joypad button.
    fileprivate func releaseButton(_ btn: RetroJoypad, forPlayer player: Int) {
        DLOG("ThinCore INPUT: releaseButton \(btn) (id=\(btn.rawValue)) player=\(player)")
        _bridge.setButton(btn.rawValue, pressed: false, forPlayer: UInt32(player))
    }

    /// Set analog stick axis value (CGFloat -1..1 range mapped to libretro int16).
    func setAnalog(stick: UInt32, axisX: CGFloat, axisY: CGFloat, forPlayer player: Int) {
        let x = Int16(max(-1.0, min(1.0, axisX)) * CGFloat(kAnalogMax))
        let y = Int16(max(-1.0, min(1.0, axisY)) * CGFloat(kAnalogMax))
        _bridge.setAnalogIndex(stick, axis: kAnalogAxisX, value: x, forPlayer: UInt32(player))
        _bridge.setAnalogIndex(stick, axis: kAnalogAxisY, value: y, forPlayer: UInt32(player))
    }

    /// Base JoystickResponder conformance (Int-typed button).
    /// System-specific overloads with typed enums take priority at call sites.
    @objc public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        // Default: treat button 0 as left stick, button 1 as right stick
        let stick: UInt32 = button == 1 ? kAnalogRightStick : kAnalogLeftStick
        setAnalog(stick: stick, axisX: xValue, axisY: yValue, forPlayer: player)
    }
}

// MARK: - NES

extension PVThinLibretroCore: PVNESSystemResponderClient {
    public func didPush(_ button: PVNESButton, forPlayer player: Int) {
        pressButton(nesMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVNESButton, forPlayer player: Int) {
        releaseButton(nesMap(button), forPlayer: player)
    }

    private func nesMap(_ button: PVNESButton) -> RetroJoypad {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .a:      return .a
        case .b:      return .b
        case .start:  return .start
        case .select: return .select
        case .count:  return .b
        @unknown default: return .b
        }
    }
}

// MARK: - SNES

extension PVThinLibretroCore: PVSNESSystemResponderClient {
    public func didPush(_ button: PVSNESButton, forPlayer player: Int) {
        pressButton(snesMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVSNESButton, forPlayer player: Int) {
        releaseButton(snesMap(button), forPlayer: player)
    }

    private func snesMap(_ button: PVSNESButton) -> RetroJoypad {
        switch button {
        case .up:           return .up
        case .down:         return .down
        case .left:         return .left
        case .right:        return .right
        case .a:            return .a
        case .b:            return .b
        case .x:            return .x
        case .y:            return .y
        case .triggerLeft:  return .l
        case .triggerRight: return .r
        case .start:        return .start
        case .select:       return .select
        case .count:        return .b
        @unknown default:   return .b
        }
    }
}

// MARK: - Game Boy

extension PVThinLibretroCore: PVGBSystemResponderClient {
    public func didPush(_ button: PVGBButton, forPlayer player: Int) {
        pressButton(gbMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVGBButton, forPlayer player: Int) {
        releaseButton(gbMap(button), forPlayer: player)
    }

    private func gbMap(_ button: PVGBButton) -> RetroJoypad {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .a:      return .a
        case .b:      return .b
        case .start:  return .start
        case .select: return .select
        case .count:  return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Game Boy Advance

extension PVThinLibretroCore: PVGBASystemResponderClient {
    public func didPush(_ button: PVGBAButton, forPlayer player: Int) {
        pressButton(gbaMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVGBAButton, forPlayer player: Int) {
        releaseButton(gbaMap(button), forPlayer: player)
    }

    private func gbaMap(_ button: PVGBAButton) -> RetroJoypad {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .a:      return .a
        case .b:      return .b
        case .l:      return .l
        case .r:      return .r
        case .start:  return .start
        case .select: return .select
        case .count:  return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Genesis / Mega Drive

extension PVThinLibretroCore: PVGenesisSystemResponderClient {
    public func didPush(_ button: PVGenesisButton, forPlayer player: Int) {
        pressButton(genesisMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVGenesisButton, forPlayer player: Int) {
        releaseButton(genesisMap(button), forPlayer: player)
    }

    private func genesisMap(_ button: PVGenesisButton) -> RetroJoypad {
        // Genesis 6-button: B/A map to Y/B, C maps to A, X/Y/Z to L/X/R
        switch button {
        case .up:    return .up
        case .down:  return .down
        case .left:  return .left
        case .right: return .right
        case .a:     return .y
        case .b:     return .b
        case .c:     return .a
        case .x:     return .l
        case .y:     return .x
        case .z:     return .r
        case .start: return .start
        case .mode:  return .select
        case .count: return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Atari 2600

extension PVThinLibretroCore: PV2600SystemResponderClient {
    public func didPush(_ button: PV2600Button, forPlayer player: Int) {
        pressButton(atari2600Map(button), forPlayer: player)
    }
    public func didRelease(_ button: PV2600Button, forPlayer player: Int) {
        releaseButton(atari2600Map(button), forPlayer: player)
    }

    private func atari2600Map(_ button: PV2600Button) -> RetroJoypad {
        switch button {
        case .up:         return .up
        case .down:       return .down
        case .left:       return .left
        case .right:      return .right
        case .fire1:      return .b
        case .leftDiffA:  return .l
        case .leftDiffB:  return .l2
        case .rightDiffA: return .r
        case .rightDiffB: return .r2
        case .reset:      return .start
        case .select:     return .select
        case .colorBW:    return .r3
        case .count:      return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Atari 7800

extension PVThinLibretroCore: PV7800SystemResponderClient {
    public func didPush(_ button: PV7800Button, forPlayer player: Int) {
        pressButton(atari7800Map(button), forPlayer: player)
    }
    public func didRelease(_ button: PV7800Button, forPlayer player: Int) {
        releaseButton(atari7800Map(button), forPlayer: player)
    }

    private func atari7800Map(_ button: PV7800Button) -> RetroJoypad {
        switch button {
        case .up:       return .up
        case .down:     return .down
        case .left:     return .left
        case .right:    return .right
        case .fire1:    return .b
        case .fire2:    return .a
        case .select:   return .select
        case .pause:    return .start
        case .reset:    return .l
        case .leftDiff: return .l2
        case .rightDiff: return .r2
        case .colorBW:  return .r3
        case .count:    return .b
        @unknown default: return .b
        }
    }
}

// MARK: - PCE / TurboGrafx-16

extension PVThinLibretroCore: PVPCESystemResponderClient {
    public func didPush(_ button: PVPCEButton, forPlayer player: Int) {
        pressButton(pceMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVPCEButton, forPlayer player: Int) {
        releaseButton(pceMap(button), forPlayer: player)
    }

    private func pceMap(_ button: PVPCEButton) -> RetroJoypad {
        switch button {
        case .up:      return .up
        case .down:    return .down
        case .left:    return .left
        case .right:   return .right
        case .button1: return .a
        case .button2: return .b
        case .button3: return .x
        case .button4: return .y
        case .button5: return .l
        case .button6: return .r
        case .run:     return .start
        case .select:  return .select
        case .mode:    return .l2
        case .turboI:  return .l3
        case .turboII: return .r3
        case .count:   return .b
        @unknown default: return .b
        }
    }
}

// MARK: - PCE-CD

extension PVThinLibretroCore: PVPCECDSystemResponderClient {
    public func didPush(_ button: PVPCECDButton, forPlayer player: Int) {
        pressButton(pceCDMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVPCECDButton, forPlayer player: Int) {
        releaseButton(pceCDMap(button), forPlayer: player)
    }

    private func pceCDMap(_ button: PVPCECDButton) -> RetroJoypad {
        switch button {
        case .up:      return .up
        case .down:    return .down
        case .left:    return .left
        case .right:   return .right
        case .button1: return .a
        case .button2: return .b
        case .button3: return .x
        case .button4: return .y
        case .button5: return .l
        case .button6: return .r
        case .run:     return .start
        case .select:  return .select
        case .mode:    return .l2
        case .turboI:  return .l3
        case .turboII: return .r3
        case .count:   return .b
        @unknown default: return .b
        }
    }
}

// MARK: - PSX

extension PVThinLibretroCore: PVPSXSystemResponderClient {
    public func didPush(_ button: PVPSXButton, forPlayer player: Int) {
        guard let mapped = psxMapDigital(button) else {
            WLOG("ThinCore PSX: unmapped button \(button) for push")
            return
        }
        ILOG("ThinCore PSX: didPush \(button) → \(mapped) player=\(player)")
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PVPSXButton, forPlayer player: Int) {
        guard let mapped = psxMapDigital(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVPSXButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        switch button {
        case .leftAnalog:
            setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
        case .rightAnalog:
            setAnalog(stick: kAnalogRightStick, axisX: xValue, axisY: yValue, forPlayer: player)
        default:
            break
        }
    }

    private func psxMapDigital(_ button: PVPSXButton) -> RetroJoypad? {
        switch button {
        case .up:       return .up
        case .down:     return .down
        case .left:     return .left
        case .right:    return .right
        case .triangle: return .x
        case .circle:   return .a
        case .cross:    return .b
        case .square:   return .y
        case .l1:       return .l
        case .l2:       return .l2
        case .l3:       return .l3
        case .r1:       return .r
        case .r2:       return .r2
        case .r3:       return .r3
        case .start:    return .start
        case .select:   return .select
        // Analog directions handled via didMoveJoystick or as digital dpad
        case .leftAnalogUp:    return .up
        case .leftAnalogDown:  return .down
        case .leftAnalogLeft:  return .left
        case .leftAnalogRight: return .right
        case .rightAnalogUp, .rightAnalogDown, .rightAnalogLeft, .rightAnalogRight:
            return nil
        case .analogMode, .leftAnalog, .rightAnalog, .count:
            return nil
        @unknown default:
            return nil
        }
    }
}

// MARK: - N64

extension PVThinLibretroCore: PVN64SystemResponderClient {
    public func didMoveJoystick(_ button: PVN64Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        if button == .leftAnalog {
            setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
        }
    }
    public func didPush(_ button: PVN64Button, forPlayer player: Int) {
        guard let mapped = n64MapDigital(button) else { return }
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PVN64Button, forPlayer player: Int) {
        guard let mapped = n64MapDigital(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }

    private func n64MapDigital(_ button: PVN64Button) -> RetroJoypad? {
        // Standard mupen64plus-libretro mapping:
        // C buttons map to right analog stick directions via the analog system,
        // but for digital fallback we use the right-side face buttons.
        switch button {
        case .dPadUp:    return .up
        case .dPadDown:  return .down
        case .dPadLeft:  return .left
        case .dPadRight: return .right
        case .a:         return .a
        case .b:         return .b
        case .cUp:       return .x
        case .cDown:     return .y
        case .cLeft:     return .l2
        case .cRight:    return .r2
        case .l:         return .l
        case .r:         return .r
        case .z:         return .l3      // Z trigger
        case .start:     return .start
        case .analogUp, .analogDown, .analogLeft, .analogRight, .leftAnalog:
            return nil // handled by didMoveJoystick
        case .count:
            return nil
        @unknown default:
            return nil
        }
    }
}

// MARK: - DS

extension PVThinLibretroCore: PVDSSystemResponderClient {
    @objc(didPushDSButton:forPlayer:)
    public func didPush(_ button: PVDSButton, forPlayer player: Int) {
        pressButton(dsMap(button), forPlayer: player)
    }
    @objc(didReleaseDSButton:forPlayer:)
    public func didRelease(_ button: PVDSButton, forPlayer player: Int) {
        releaseButton(dsMap(button), forPlayer: player)
    }

    /// Forward DS touchscreen tap to the libretro pointer device.
    @objc public func touchScreenAtPoint(_ point: CGPoint) {
        // DS touchscreen is 256×192; normalize to libretro pointer range (-0x7fff…0x7fff)
        let nx = Int16(clamping: Int(((point.x / 256.0) * 2.0 - 1.0) * 0x7fff))
        let ny = Int16(clamping: Int(((point.y / 192.0) * 2.0 - 1.0) * 0x7fff))
        _bridge.setPointerX(nx, y: ny, pressed: true)
    }

    /// Release DS touchscreen.
    @objc public func releaseScreenTouch() {
        _bridge.setPointerX(0, y: 0, pressed: false)
    }

    private func dsMap(_ button: PVDSButton) -> RetroJoypad {
        switch button {
        case .up:         return .up
        case .down:       return .down
        case .left:       return .left
        case .right:      return .right
        case .a:          return .a
        case .b:          return .b
        case .x:          return .x
        case .y:          return .y
        case .l:          return .l
        case .r:          return .r
        case .start:      return .start
        case .select:     return .select
        case .screenSwap: return .l3     // map screen swap to L3
        case .rotate:     return .r3     // map rotate to R3
        case .count:      return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Atari Lynx

extension PVThinLibretroCore: PVLynxSystemResponderClient {
    public func didPush(LynxButton button: PVLynxButton, forPlayer player: Int) {
        pressButton(lynxMap(button), forPlayer: player)
    }
    public func didRelease(LynxButton button: PVLynxButton, forPlayer player: Int) {
        releaseButton(lynxMap(button), forPlayer: player)
    }

    private func lynxMap(_ button: PVLynxButton) -> RetroJoypad {
        switch button {
        case .up:      return .up
        case .down:    return .down
        case .left:    return .left
        case .right:   return .right
        case .a:       return .a
        case .b:       return .b
        case .option1: return .start
        case .option2: return .select
        case .pause:   return .l
        case .count:   return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Supervision

extension PVThinLibretroCore: PVSupervisionSystemResponderClient {
    public func didPush(_ button: PVSupervisionButton, forPlayer player: Int) {
        pressButton(svMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVSupervisionButton, forPlayer player: Int) {
        releaseButton(svMap(button), forPlayer: player)
    }

    private func svMap(_ button: PVSupervisionButton) -> RetroJoypad {
        switch button {
        case .up:               return .up
        case .down:             return .down
        case .left:             return .left
        case .right:            return .right
        case .topAction:        return .a
        case .bottomLeftAction: return .b
        case .bottomRightAction: return .y
        case .button1:          return .x
        case .button2:          return .l
        case .button3:          return .r
        case .button4:          return .l2
        case .button5:          return .r2
        case .button6:          return .l3
        case .button7:          return .r3
        case .button8:          return .start
        case .button9:          return .select
        case .button0:          return .select
        case .clear:            return .select
        case .enter:            return .start
        case .count:            return .b
        @unknown default:       return .b
        }
    }
}

// MARK: - NeoGeo

extension PVThinLibretroCore: PVNeoGeoSystemResponderClient {
    public func didMoveJoystick(_ button: PVNeoGeoButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        switch button {
        case .leftAnalog:
            setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
        case .rightAnalog:
            setAnalog(stick: kAnalogRightStick, axisX: xValue, axisY: yValue, forPlayer: player)
        default:
            break
        }
    }
    public func didPush(_ button: PVNeoGeoButton, forPlayer player: Int) {
        guard let mapped = neoGeoMap(button) else { return }
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PVNeoGeoButton, forPlayer player: Int) {
        guard let mapped = neoGeoMap(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }

    private func neoGeoMap(_ button: PVNeoGeoButton) -> RetroJoypad? {
        switch button {
        case .up:       return .up
        case .down:     return .down
        case .left:     return .left
        case .right:    return .right
        case .triangle: return .x    // A button (NeoGeo A = triangle)
        case .circle:   return .a    // B button
        case .cross:    return .b    // C button
        case .square:   return .y    // D button
        case .l1:       return .l
        case .l2:       return .l2
        case .l3:       return .l3
        case .r1:       return .r
        case .r2:       return .r2
        case .r3:       return .r3
        case .start:    return .start
        case .select:   return .select
        case .analogMode, .leftAnalog, .rightAnalog,
             .leftAnalogUp, .leftAnalogDown, .leftAnalogLeft, .leftAnalogRight,
             .rightAnalogUp, .rightAnalogDown, .rightAnalogLeft, .rightAnalogRight:
            return nil
        case .count:    return nil
        @unknown default: return nil
        }
    }
}

// MARK: - Dreamcast

extension PVThinLibretroCore: PVDreamcastSystemResponderClient {
    public func didMoveJoystick(_ button: PVDreamcastButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        if button == .leftAnalog {
            setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
        }
    }
    public func didPush(_ button: PVDreamcastButton, forPlayer player: Int) {
        guard let mapped = dcMap(button) else { return }
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PVDreamcastButton, forPlayer player: Int) {
        guard let mapped = dcMap(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }

    private func dcMap(_ button: PVDreamcastButton) -> RetroJoypad? {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .a:      return .b
        case .b:      return .a
        case .x:      return .y
        case .y:      return .x
        case .l:      return .l2
        case .r:      return .r2
        case .start:  return .start
        case .analogUp, .analogDown, .analogLeft, .analogRight, .leftAnalog:
            return nil
        case .count:  return nil
        @unknown default: return nil
        }
    }
}

// MARK: - Saturn

extension PVThinLibretroCore: PVSaturnSystemResponderClient {
    public func didMoveJoystick(_ button: PVSaturnButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVSaturnButton, forPlayer player: Int) {
        pressButton(saturnMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVSaturnButton, forPlayer player: Int) {
        releaseButton(saturnMap(button), forPlayer: player)
    }

    private func saturnMap(_ button: PVSaturnButton) -> RetroJoypad {
        switch button {
        case .up:         return .up
        case .down:       return .down
        case .left:       return .left
        case .right:      return .right
        case .a:          return .y
        case .b:          return .b
        case .c:          return .a
        case .x:          return .l
        case .y:          return .x
        case .z:          return .r
        case .l:          return .l2
        case .r:          return .r2
        case .start:      return .start
        case .leftAnalog: return .start  // no direct mapping, fallback
        case .count:      return .b
        @unknown default: return .b
        }
    }
}

// MARK: - SG-1000

extension PVThinLibretroCore: PVSG1000SystemResponderClient {
    public func didPush(_ button: PVSG1000Button, forPlayer player: Int) {
        pressButton(sg1000Map(button), forPlayer: player)
    }
    public func didRelease(_ button: PVSG1000Button, forPlayer player: Int) {
        releaseButton(sg1000Map(button), forPlayer: player)
    }

    private func sg1000Map(_ button: PVSG1000Button) -> RetroJoypad {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .b:      return .b
        case .c:      return .a
        case .start:  return .start
        case .count:  return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Sega 32X

extension PVThinLibretroCore: PVSega32XSystemResponderClient {
    public func didPush(_ button: PVSega32XButton, forPlayer player: Int) {
        pressButton(sega32xMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVSega32XButton, forPlayer player: Int) {
        releaseButton(sega32xMap(button), forPlayer: player)
    }

    private func sega32xMap(_ button: PVSega32XButton) -> RetroJoypad {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .a:      return .y
        case .b:      return .b
        case .c:      return .a
        case .x:      return .l
        case .y:      return .x
        case .z:      return .r
        case .start:  return .start
        case .mode:   return .select
        case .count:  return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Virtual Boy

extension PVThinLibretroCore: PVVirtualBoySystemResponderClient {
    public func didPush(_ button: PVVBButton, forPlayer player: Int) {
        pressButton(vbMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVVBButton, forPlayer player: Int) {
        releaseButton(vbMap(button), forPlayer: player)
    }

    private func vbMap(_ button: PVVBButton) -> RetroJoypad {
        switch button {
        case .leftUp:     return .up
        case .leftDown:   return .down
        case .leftLeft:   return .left
        case .leftRight:  return .right
        case .rightUp:    return .x
        case .rightDown:  return .y
        case .rightLeft:  return .l
        case .rightRight: return .r
        case .a:          return .a
        case .b:          return .b
        case .l:          return .l2
        case .r:          return .r2
        case .start:      return .start
        case .select:     return .select
        case .count:      return .b
        @unknown default: return .b
        }
    }
}

// MARK: - ColecoVision

extension PVThinLibretroCore: PVColecoVisionSystemResponderClient {
    public func didPush(_ button: PVColecoVisionButton, forPlayer player: Int) {
        pressButton(cvMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVColecoVisionButton, forPlayer player: Int) {
        releaseButton(cvMap(button), forPlayer: player)
    }

    private func cvMap(_ button: PVColecoVisionButton) -> RetroJoypad {
        switch button {
        case .up:          return .up
        case .down:        return .down
        case .left:        return .left
        case .right:       return .right
        case .leftAction:  return .b
        case .rightAction: return .a
        case .button1:     return .x
        case .button2:     return .y
        case .button3:     return .l
        case .button4:     return .r
        case .button5:     return .l2
        case .button6:     return .r2
        case .button7:     return .l3
        case .button8:     return .r3
        case .button9:     return .start
        case .button0:     return .select
        case .asterisk:    return .select
        case .pound:       return .start
        case .count:       return .b
        @unknown default:  return .b
        }
    }
}

// MARK: - 3DO

extension PVThinLibretroCore: PV3DOSystemResponderClient {
    public func didPush(_ button: PV3DOButton, forPlayer player: Int) {
        pressButton(threeDOMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PV3DOButton, forPlayer player: Int) {
        releaseButton(threeDOMap(button), forPlayer: player)
    }

    private func threeDOMap(_ button: PV3DOButton) -> RetroJoypad {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .a:      return .b
        case .b:      return .a
        case .c:      return .y
        case .L:      return .l
        case .R:      return .r
        case .X:      return .start
        case .P:      return .select
        case .count:  return .b
        @unknown default: return .b
        }
    }
}

// MARK: - PSP

extension PVThinLibretroCore: PVPSPSystemResponderClient {
    public func didPush(_ button: PVPSPButton, forPlayer player: Int) {
        guard let mapped = pspMap(button) else { return }
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PVPSPButton, forPlayer player: Int) {
        guard let mapped = pspMap(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVPSPButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
    }

    private func pspMap(_ button: PVPSPButton) -> RetroJoypad? {
        switch button {
        case .up:       return .up
        case .down:     return .down
        case .left:     return .left
        case .right:    return .right
        case .triangle: return .x
        case .circle:   return .a
        case .cross:    return .b
        case .square:   return .y
        case .l1:       return .l
        case .l2:       return .l2
        case .l3:       return .l3
        case .r1:       return .r
        case .r2:       return .r2
        case .r3:       return .r3
        case .start:    return .start
        case .select:   return .select
        case .analogMode, .leftAnalogUp, .leftAnalogDown, .leftAnalogLeft, .leftAnalogRight, .leftAnalog:
            return nil
        case .count:    return nil
        @unknown default: return nil
        }
    }
}

// MARK: - PCFX

extension PVThinLibretroCore: PVPCFXSystemResponderClient {
    public func didPush(_ button: PVPCFXButton, forPlayer player: Int) {
        pressButton(pcfxMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVPCFXButton, forPlayer player: Int) {
        releaseButton(pcfxMap(button), forPlayer: player)
    }

    private func pcfxMap(_ button: PVPCFXButton) -> RetroJoypad {
        switch button {
        case .up:      return .up
        case .down:    return .down
        case .left:    return .left
        case .right:   return .right
        case .button1: return .a
        case .button2: return .b
        case .button3: return .x
        case .button4: return .y
        case .button5: return .l
        case .button6: return .r
        case .run:     return .start
        case .select:  return .select
        case .mode:    return .l2
        case .turboI:  return .l3
        case .turboII: return .r3
        case .count:   return .b
        @unknown default: return .b
        }
    }
}

// MARK: - KeyboardResponder

extension PVThinLibretroCore: KeyboardResponder {

    public var gameSupportsKeyboard: Bool {
        SystemIdentifier(rawValue: systemIdentifier ?? "")?.supportsKeyboard ?? false
    }
    public var requiresKeyboard: Bool {
        SystemIdentifier(rawValue: systemIdentifier ?? "")?.requiresKeyboard ?? false
    }

#if canImport(GameController)
    public var keyChangedHandler: GCKeyboardValueChangedHandler? { nil }

    @available(iOS 14.0, tvOS 14.0, *)
    public func keyDown(_ key: GCKeyCode) {
        let retroKey = Self.gcKeyCodeToRetroKey(key)
        guard retroKey != 0 else { return }
        _bridge.setKeyState(retroKey, pressed: true)
    }

    @available(iOS 14.0, tvOS 14.0, *)
    public func keyUp(_ key: GCKeyCode) {
        let retroKey = Self.gcKeyCodeToRetroKey(key)
        guard retroKey != 0 else { return }
        _bridge.setKeyState(retroKey, pressed: false)
    }
#endif

    /// Maps a GCKeyCode to a libretro retro_key value.
    /// Returns 0 (RETROK_UNKNOWN) for unmapped keys.
    @available(iOS 14.0, tvOS 14.0, *)
    nonisolated static func gcKeyCodeToRetroKey(_ key: GCKeyCode) -> UInt32 {
        switch key {
        // Letters
        case .keyA: return 97  // RETROK_a
        case .keyB: return 98
        case .keyC: return 99
        case .keyD: return 100
        case .keyE: return 101
        case .keyF: return 102
        case .keyG: return 103
        case .keyH: return 104
        case .keyI: return 105
        case .keyJ: return 106
        case .keyK: return 107
        case .keyL: return 108
        case .keyM: return 109
        case .keyN: return 110
        case .keyO: return 111
        case .keyP: return 112
        case .keyQ: return 113
        case .keyR: return 114
        case .keyS: return 115
        case .keyT: return 116
        case .keyU: return 117
        case .keyV: return 118
        case .keyW: return 119
        case .keyX: return 120
        case .keyY: return 121
        case .keyZ: return 122
        // Digits
        case .one:   return 49  // RETROK_1
        case .two:   return 50
        case .three: return 51
        case .four:  return 52
        case .five:  return 53
        case .six:   return 54
        case .seven: return 55
        case .eight: return 56
        case .nine:  return 57
        case .zero:  return 48  // RETROK_0
        // Function keys
        case .F1:  return 282  // RETROK_F1
        case .F2:  return 283
        case .F3:  return 284
        case .F4:  return 285
        case .F5:  return 286
        case .F6:  return 287
        case .F7:  return 288
        case .F8:  return 289
        case .F9:  return 290
        case .F10: return 291
        case .F11: return 292
        case .F12: return 293
        // Special keys
        case .returnOrEnter:     return 13   // RETROK_RETURN
        case .escape:            return 27   // RETROK_ESCAPE
        case .deleteOrBackspace: return 8    // RETROK_BACKSPACE
        case .tab:               return 9    // RETROK_TAB
        case .spacebar:          return 32   // RETROK_SPACE
        case .upArrow:           return 273  // RETROK_UP
        case .downArrow:         return 274  // RETROK_DOWN
        case .rightArrow:        return 275  // RETROK_RIGHT
        case .leftArrow:         return 276  // RETROK_LEFT
        case .insert:            return 277  // RETROK_INSERT
        case .home:              return 278  // RETROK_HOME
        case .end:               return 279  // RETROK_END
        case .pageUp:            return 280  // RETROK_PAGEUP
        case .pageDown:          return 281  // RETROK_PAGEDOWN
        case .deleteForward:     return 127  // RETROK_DELETE
        // Modifiers
        case .leftShift:    return 304  // RETROK_LSHIFT
        case .rightShift:   return 303  // RETROK_RSHIFT
        case .leftControl:  return 306  // RETROK_LCTRL
        case .rightControl: return 305  // RETROK_RCTRL
        case .leftAlt:      return 308  // RETROK_LALT
        case .rightAlt:     return 307  // RETROK_RALT
        case .capsLock:     return 301  // RETROK_CAPSLOCK
        // Punctuation
        case .hyphen:              return 45   // RETROK_MINUS
        case .equalSign:           return 61   // RETROK_EQUALS
        case .openBracket:         return 91   // RETROK_LEFTBRACKET
        case .closeBracket:        return 93   // RETROK_RIGHTBRACKET
        case .backslash:           return 92   // RETROK_BACKSLASH
        case .semicolon:           return 59   // RETROK_SEMICOLON
        case .quote:               return 39   // RETROK_QUOTE
        case .graveAccentAndTilde: return 96   // RETROK_BACKQUOTE
        case .comma:               return 44   // RETROK_COMMA
        case .period:              return 46   // RETROK_PERIOD
        case .slash:               return 47   // RETROK_SLASH
        // Keypad
        case .keypad0:         return 256  // RETROK_KP0
        case .keypad1:         return 257
        case .keypad2:         return 258
        case .keypad3:         return 259
        case .keypad4:         return 260
        case .keypad5:         return 261
        case .keypad6:         return 262
        case .keypad7:         return 263
        case .keypad8:         return 264
        case .keypad9:         return 265
        case .keypadPeriod:    return 266  // RETROK_KP_PERIOD
        case .keypadSlash:     return 267  // RETROK_KP_DIVIDE
        case .keypadAsterisk:  return 268  // RETROK_KP_MULTIPLY
        case .keypadHyphen:    return 269  // RETROK_KP_MINUS
        case .keypadPlus:      return 270  // RETROK_KP_PLUS
        case .keypadEnter:     return 271  // RETROK_KP_ENTER
        case .keypadEqualSign: return 272  // RETROK_KP_EQUALS
        default:
            return 0 // RETROK_UNKNOWN
        }
    }
}

// MARK: - MouseResponder

extension PVThinLibretroCore: MouseResponder {

    public var gameSupportsMouse: Bool {
        guard let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "") else { return false }
        // romName is not populated for thin-libretro cores; derive a title from
        // the ROM path so title-pattern matching in the registry can still work.
        let titleForLookup: String? = {
            if let name = romName, !name.isEmpty { return name }
            guard let path = _bridge.romPath else { return nil }
            let base = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
            return base.isEmpty ? nil : base
        }()
        // Delegate entirely to the registry so user overrides always take precedence,
        // even for systems not in the static always/conditional sets.
        return MouseGameRegistry.shared.gameSupportsMouse(
            systemIdentifier: sysID,
            md5: romMD5,
            title: titleForLookup
        )
    }

    public var requiresMouse: Bool { false }

#if canImport(GameController)
    @available(iOS 14.0, tvOS 14.0, *)
    public func didScroll(_ cursor: GCDeviceCursor) {
        // Scroll events could map to RETRO_DEVICE_ID_MOUSE_WHEELUP/WHEELDOWN
        // but GCDeviceCursor doesn't provide a simple delta — no-op for now.
    }

    public var mouseMovedHandler: GCMouseMoved? { nil }
#endif

    /// Forward mouse movement as relative deltas to the libretro core.
    public func mouseMoved(atPoint point: CGPoint) {
        _bridge.setMouseDeltaX(Int16(clamping: Int(point.x)), deltaY: Int16(clamping: Int(point.y)))
    }

    public func leftMouseDown(atPoint point: CGPoint) {
        _bridge.setMouseButton(2, pressed: true)  // RETRO_DEVICE_ID_MOUSE_LEFT = 2
    }

    public func leftMouseUp() {
        _bridge.setMouseButton(2, pressed: false)
    }

    public func rightMouseDown(atPoint point: CGPoint) {
        _bridge.setMouseButton(3, pressed: true)  // RETRO_DEVICE_ID_MOUSE_RIGHT = 3
    }

    public func rightMouseUp() {
        _bridge.setMouseButton(3, pressed: false)
    }
}

// MARK: - Mouse bridge helpers (at: → atPoint: adapters)
// Several protocols (Doom, Wolf3D, DOS, A8, MSX, EP128) define
// mouseMoved(at:) / leftMouseDown(at:) / rightMouseDown(at:) which
// delegate to the MouseResponder methods already implemented above.

extension PVThinLibretroCore {
    public func mouseMoved(at point: CGPoint) {
        mouseMoved(atPoint: point)
    }
    public func leftMouseDown(at point: CGPoint) {
        leftMouseDown(atPoint: point)
    }
    public func rightMouseDown(at point: CGPoint) {
        rightMouseDown(atPoint: point)
    }
}

// MARK: - Master System

extension PVThinLibretroCore: PVMasterSystemSystemResponderClient {
    public func didPush(_ button: PVMasterSystemButton, forPlayer player: Int) {
        pressButton(masterSystemMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVMasterSystemButton, forPlayer player: Int) {
        releaseButton(masterSystemMap(button), forPlayer: player)
    }

    private func masterSystemMap(_ button: PVMasterSystemButton) -> RetroJoypad {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .b:      return .b
        case .c:      return .a
        case .start:  return .start
        case .count:  return .b
        @unknown default: return .b
        }
    }
}

// MARK: - WonderSwan

extension PVThinLibretroCore: PVWonderSwanSystemResponderClient {
    public func didPush(_ button: PVWSButton, forPlayer player: Int) {
        pressButton(wsMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVWSButton, forPlayer player: Int) {
        releaseButton(wsMap(button), forPlayer: player)
    }

    private func wsMap(_ button: PVWSButton) -> RetroJoypad {
        switch button {
        case .x1:    return .up      // X pad up
        case .x3:    return .down    // X pad down
        case .x4:    return .left    // X pad left
        case .x2:    return .right   // X pad right
        case .y1:    return .l       // Y pad up
        case .y3:    return .l2      // Y pad down
        case .y4:    return .r       // Y pad left
        case .y2:    return .r2      // Y pad right
        case .a:     return .a
        case .b:     return .b
        case .start: return .start
        case .sound: return .select
        case .count: return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Neo Geo Pocket

extension PVThinLibretroCore: PVNeoGeoPocketSystemResponderClient {
    public func didPush(_ button: PVNGPButton, forPlayer player: Int) {
        pressButton(ngpMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVNGPButton, forPlayer player: Int) {
        releaseButton(ngpMap(button), forPlayer: player)
    }

    private func ngpMap(_ button: PVNGPButton) -> RetroJoypad {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .a:      return .a
        case .b:      return .b
        case .option: return .start
        case .count:  return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Atari Jaguar

extension PVThinLibretroCore: PVJaguarSystemResponderClient {
    public func didPush(jaguarButton button: PVJaguarButton, forPlayer player: Int) {
        pressButton(jaguarMap(button), forPlayer: player)
    }
    public func didRelease(jaguarButton button: PVJaguarButton, forPlayer player: Int) {
        releaseButton(jaguarMap(button), forPlayer: player)
    }

    private func jaguarMap(_ button: PVJaguarButton) -> RetroJoypad {
        switch button {
        case .up:       return .up
        case .down:     return .down
        case .left:     return .left
        case .right:    return .right
        case .a:        return .b
        case .b:        return .a
        case .c:        return .y
        case .pause:    return .start
        case .option:   return .select
        case .button1:  return .x
        case .button2:  return .l
        case .button3:  return .r
        case .button4:  return .l2
        case .button5:  return .r2
        case .button6:  return .l3
        case .button7:  return .r3
        case .button8:  return .select
        case .button9:  return .start
        case .button0:  return .select
        case .asterisk: return .select
        case .pound:    return .start
        case .count:    return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Doom

extension PVThinLibretroCore: PVDoomSystemResponderClient {
    public func didPush(_ button: PVDoomButton, forPlayer player: Int) {
        pressButton(doomMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVDoomButton, forPlayer player: Int) {
        releaseButton(doomMap(button), forPlayer: player)
    }
    private func doomMap(_ button: PVDoomButton) -> RetroJoypad {
        switch button {
        case .up:          return .up
        case .down:        return .down
        case .left:        return .left
        case .right:       return .right
        case .fire:        return .x       // Fire → JOYPAD_X (north)
        case .use:         return .b       // Use → JOYPAD_B (south)
        case .run:         return .y       // Run → JOYPAD_Y (west)
        case .strafeLeft:  return .l       // Strafe Left → JOYPAD_L
        case .strafeRight: return .r       // Strafe Right → JOYPAD_R
        case .weaponPrev:  return .l2      // Prev Weapon → JOYPAD_L2
        case .weaponNext:  return .r2      // Next Weapon → JOYPAD_R2
        case .map:         return .select  // Automap → JOYPAD_SELECT
        case .strafe:      return .a       // Strafe toggle → JOYPAD_A (east)
        case .pause:       return .start   // Pause → JOYPAD_START
        case .count:       return .b
        @unknown default:  return .b
        }
    }
}

// MARK: - Wolf3D

extension PVThinLibretroCore: PVWolf3DSystemResponderClient {
    public func didPush(_ button: PVWolf3DButton, forPlayer player: Int) {
        pressButton(wolf3dMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVWolf3DButton, forPlayer player: Int) {
        releaseButton(wolf3dMap(button), forPlayer: player)
    }

    private func wolf3dMap(_ button: PVWolf3DButton) -> RetroJoypad {
        switch button {
        case .up:          return .up
        case .down:        return .down
        case .left:        return .left
        case .right:       return .right
        case .fire:        return .b       // Fire → JOYPAD_B (south)
        case .open:        return .a       // Open → JOYPAD_A (east)
        case .strafeOn:    return .y       // Strafe On → JOYPAD_Y (west)
        case .run:         return .x       // Run → JOYPAD_X (north)
        case .strafeLeft:  return .l       // Strafe Left → JOYPAD_L
        case .strafeRight: return .r       // Strafe Right → JOYPAD_R
        case .weaponPrev:  return .l2      // Prev Weapon → JOYPAD_L2
        case .weaponNext:  return .r2      // Next Weapon → JOYPAD_R2
        case .map:         return .select  // Automap → JOYPAD_SELECT
        case .menu:        return .start   // Menu → JOYPAD_START
        case .count:       return .b
        @unknown default:  return .b
        }
    }
}

// MARK: - DOS

extension PVThinLibretroCore: PVDOSSystemResponderClient {
    public func didPush(_ button: PVDOSButton, forPlayer player: Int) {
        pressButton(dosMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVDOSButton, forPlayer player: Int) {
        releaseButton(dosMap(button), forPlayer: player)
    }

    private func dosMap(_ button: PVDOSButton) -> RetroJoypad {
        switch button {
        case .up:          return .up
        case .down:        return .down
        case .left:        return .left
        case .right:       return .right
        case .fire1:       return .b
        case .fire2:       return .a
        case .select:      return .select
        case .pause:       return .start
        case .reset:       return .l
        case .leftDiff:    return .l2
        case .rightDiff:   return .r2
        case .strafeLeft:  return .l
        case .strafeRight: return .r
        case .run:         return .x
        case .weaponNext:  return .r2
        case .weaponPrev:  return .l2
        case .count:       return .b
        @unknown default:  return .b
        }
    }
}

// MARK: - MAME

extension PVThinLibretroCore: PVMAMESystemResponderClient {
    public func didPush(_ button: PVMAMEButton, forPlayer player: Int) {
        guard let mapped = mameMap(button) else { return }
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PVMAMEButton, forPlayer player: Int) {
        guard let mapped = mameMap(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVMAMEButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        switch button {
        case .leftAnalog:
            setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
        case .rightAnalog:
            setAnalog(stick: kAnalogRightStick, axisX: xValue, axisY: yValue, forPlayer: player)
        default:
            break
        }
    }

    private func mameMap(_ button: PVMAMEButton) -> RetroJoypad? {
        switch button {
        case .up:       return .up
        case .down:     return .down
        case .left:     return .left
        case .right:    return .right
        case .triangle: return .x
        case .circle:   return .a
        case .cross:    return .b
        case .square:   return .y
        case .l1:       return .l
        case .l2:       return .l2
        case .l3:       return .l3
        case .r1:       return .r
        case .r2:       return .r2
        case .r3:       return .r3
        case .start:    return .start
        case .select:   return .select
        case .leftAnalogUp:    return .up
        case .leftAnalogDown:  return .down
        case .leftAnalogLeft:  return .left
        case .leftAnalogRight: return .right
        case .rightAnalogUp, .rightAnalogDown, .rightAnalogLeft, .rightAnalogRight:
            return nil
        case .service:
            // Service/test button is a hardware momentary input, not a standard joypad button.
            // Arcade cores handle it via a dedicated service-input path; no joypad mapping needed.
            return nil
        case .analogMode, .leftAnalog, .rightAnalog, .count:
            return nil
        @unknown default:
            return nil
        }
    }
}

// MARK: - Atari 5200

extension PVThinLibretroCore: PV5200SystemResponderClient {
    public func didPush(_ button: PV5200Button, forPlayer player: Int) {
        pressButton(atari5200Map(button), forPlayer: player)
    }
    public func didRelease(_ button: PV5200Button, forPlayer player: Int) {
        releaseButton(atari5200Map(button), forPlayer: player)
    }
    public func didMoveJoystick(_ button: PV5200Button, withValue value: CGFloat, forPlayer player: Int) {
        // 5200 has a single analog joystick; map axis based on direction buttons
        switch button {
        case .left, .right:
            let x = Int16(max(-1.0, min(1.0, value)) * CGFloat(kAnalogMax))
            _bridge.setAnalogIndex(kAnalogLeftStick, axis: kAnalogAxisX, value: x, forPlayer: UInt32(player))
        case .up, .down:
            let y = Int16(max(-1.0, min(1.0, value)) * CGFloat(kAnalogMax))
            _bridge.setAnalogIndex(kAnalogLeftStick, axis: kAnalogAxisY, value: y, forPlayer: UInt32(player))
        default:
            break
        }
    }

    private func atari5200Map(_ button: PV5200Button) -> RetroJoypad {
        switch button {
        case .up:       return .up
        case .down:     return .down
        case .left:     return .left
        case .right:    return .right
        case .fire1:    return .b
        case .fire2:    return .a
        case .start:    return .start
        case .pause:    return .select
        case .reset:    return .l
        case .number1:  return .x
        case .number2:  return .y
        case .number3:  return .l
        case .number4:  return .r
        case .number5:  return .l2
        case .number6:  return .r2
        case .number7:  return .l3
        case .number8:  return .r3
        case .number9:  return .select
        case .number0:  return .start
        case .asterisk: return .select
        case .pound:    return .start
        case .colorBW:  return .r3
        case .count:    return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Atari 8-bit

extension PVThinLibretroCore: PVA8SystemResponderClient {
    public func didPush(_ button: PVA8Button, forPlayer player: Int) {
        pressButton(a8Map(button), forPlayer: player)
    }
    public func didRelease(_ button: PVA8Button, forPlayer player: Int) {
        releaseButton(a8Map(button), forPlayer: player)
    }
    private func a8Map(_ button: PVA8Button) -> RetroJoypad {
        switch button {
        case .up:    return .up
        case .down:  return .down
        case .left:  return .left
        case .right: return .right
        case .fire:  return .b
        case .count: return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Pokemon Mini

extension PVThinLibretroCore: PVPokeMiniSystemResponderClient {
    public func didPush(_ button: PVPMButton, forPlayer player: Int) {
        pressButton(pmMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVPMButton, forPlayer player: Int) {
        releaseButton(pmMap(button), forPlayer: player)
    }

    private func pmMap(_ button: PVPMButton) -> RetroJoypad {
        switch button {
        case .up:    return .up
        case .down:  return .down
        case .left:  return .left
        case .right: return .right
        case .a:     return .a
        case .b:     return .b
        case .c:     return .x
        case .menu:  return .select
        case .power: return .start
        case .shake: return .l
        @unknown default: return .b
        }
    }
}

// MARK: - Vectrex

extension PVThinLibretroCore: PVVectrexSystemResponderClient {
    public func didPush(_ button: PVVectrexButton, forPlayer player: Int) {
        pressButton(vectrexMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVVectrexButton, forPlayer player: Int) {
        releaseButton(vectrexMap(button), forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVVectrexButton, withValue value: CGFloat, forPlayer player: Int) {
        switch button {
        case .analogLeft, .analogRight:
            let x = Int16(max(-1.0, min(1.0, value)) * CGFloat(kAnalogMax))
            _bridge.setAnalogIndex(kAnalogLeftStick, axis: kAnalogAxisX, value: x, forPlayer: UInt32(player))
        case .analogUp, .analogDown:
            let y = Int16(max(-1.0, min(1.0, value)) * CGFloat(kAnalogMax))
            _bridge.setAnalogIndex(kAnalogLeftStick, axis: kAnalogAxisY, value: y, forPlayer: UInt32(player))
        default:
            break
        }
    }

    private func vectrexMap(_ button: PVVectrexButton) -> RetroJoypad {
        switch button {
        case .analogUp:    return .up
        case .analogDown:  return .down
        case .analogLeft:  return .left
        case .analogRight: return .right
        case .button1:     return .b
        case .button2:     return .a
        case .button3:     return .x
        case .button4:     return .y
        case .count:       return .b
        @unknown default:  return .b
        }
    }
}

// MARK: - Odyssey2

extension PVThinLibretroCore: PVOdyssey2SystemResponderClient {
    public func didPush(_ button: PVOdyssey2Button, forPlayer player: Int) {
        pressButton(odyssey2Map(button), forPlayer: player)
    }
    public func didRelease(_ button: PVOdyssey2Button, forPlayer player: Int) {
        releaseButton(odyssey2Map(button), forPlayer: player)
    }

    private func odyssey2Map(_ button: PVOdyssey2Button) -> RetroJoypad {
        switch button {
        case .up:     return .up
        case .down:   return .down
        case .left:   return .left
        case .right:  return .right
        case .action: return .b
        case .key0:   return .select
        case .key1:   return .x
        case .key2:   return .y
        case .key3:   return .l
        case .key4:   return .r
        case .key5:   return .l2
        case .key6:   return .r2
        case .key7:   return .l3
        case .key8:   return .r3
        case .key9:   return .start
        case .count:  return .b
        @unknown default: return .b
        }
    }
}

// MARK: - Intellivision

extension PVThinLibretroCore: PVIntellivisionSystemResponderClient {
    public func didPush(_ button: PVIntellivisionButton, forPlayer player: Int) {
        pressButton(intellivisionMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVIntellivisionButton, forPlayer player: Int) {
        releaseButton(intellivisionMap(button), forPlayer: player)
    }

    private func intellivisionMap(_ button: PVIntellivisionButton) -> RetroJoypad {
        switch button {
        case .up:                return .up
        case .down:              return .down
        case .left:              return .left
        case .right:             return .right
        case .topAction:         return .a
        case .bottomLeftAction:  return .b
        case .bottomRightAction: return .y
        case .button1:           return .x
        case .button2:           return .l
        case .button3:           return .r
        case .button4:           return .l2
        case .button5:           return .r2
        case .button6:           return .l3
        case .button7:           return .r3
        case .button8:           return .select
        case .button9:           return .start
        case .button0:           return .select
        case .clear:             return .select
        case .enter:             return .start
        case .count:             return .b
        @unknown default:        return .b
        }
    }
}

// MARK: - MSX

extension PVThinLibretroCore: PVMSXSystemResponderClient {
    public func didPush(_ button: PVMSXButton, forPlayer player: Int) {
        pressButton(msxMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVMSXButton, forPlayer player: Int) {
        releaseButton(msxMap(button), forPlayer: player)
    }

    private func msxMap(_ button: PVMSXButton) -> RetroJoypad {
        switch button {
        case .up:        return .up
        case .down:      return .down
        case .left:      return .left
        case .right:     return .right
        case .fire1:     return .b
        case .fire2:     return .a
        case .select:    return .select
        case .pause:     return .start
        case .reset:     return .l
        case .leftDiff:  return .l2
        case .rightDiff: return .r2
        case .count:     return .b
        @unknown default: return .b
        }
    }
}

// MARK: - EP128

extension PVThinLibretroCore: PVEP128SystemResponderClient {
    public func didPush(_ button: PVEP128Button, forPlayer player: Int) {
        pressButton(ep128Map(button), forPlayer: player)
    }
    public func didRelease(_ button: PVEP128Button, forPlayer player: Int) {
        releaseButton(ep128Map(button), forPlayer: player)
    }

    private func ep128Map(_ button: PVEP128Button) -> RetroJoypad {
        switch button {
        case .up:        return .up
        case .down:      return .down
        case .left:      return .left
        case .right:     return .right
        case .fire1:     return .b
        case .fire2:     return .a
        case .select:    return .select
        case .pause:     return .start
        case .reset:     return .l
        case .leftDiff:  return .l2
        case .rightDiff: return .r2
        case .count:     return .b
        @unknown default: return .b
        }
    }
}

// MARK: - CDi

extension PVThinLibretroCore: PVCDiSystemResponderClient {
    public func didPush(_ button: PVCDiButton, forPlayer player: Int) {
        pressButton(cdiMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVCDiButton, forPlayer player: Int) {
        releaseButton(cdiMap(button), forPlayer: player)
    }

    private func cdiMap(_ button: PVCDiButton) -> RetroJoypad {
        switch button {
        case .up:      return .up
        case .down:    return .down
        case .left:    return .left
        case .right:   return .right
        case .button1: return .b
        case .button2: return .a
        case .button3: return .x
        case .reset:   return .start
        case .count:   return .b
        @unknown default: return .b
        }
    }
}

// MARK: - PS2

extension PVThinLibretroCore: PVPS2SystemResponderClient {
    public func didPush(_ button: PVPS2Button, forPlayer player: Int) {
        guard let mapped = ps2MapDigital(button) else { return }
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PVPS2Button, forPlayer player: Int) {
        guard let mapped = ps2MapDigital(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVPS2Button, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        switch button {
        case .leftAnalog:
            setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
        case .rightAnalog:
            setAnalog(stick: kAnalogRightStick, axisX: xValue, axisY: yValue, forPlayer: player)
        default:
            break
        }
    }

    private func ps2MapDigital(_ button: PVPS2Button) -> RetroJoypad? {
        switch button {
        case .up:       return .up
        case .down:     return .down
        case .left:     return .left
        case .right:    return .right
        case .triangle: return .x
        case .circle:   return .a
        case .cross:    return .b
        case .square:   return .y
        case .l1:       return .l
        case .l2:       return .l2
        case .l3:       return .l3
        case .r1:       return .r
        case .r2:       return .r2
        case .r3:       return .r3
        case .start:    return .start
        case .select:   return .select
        case .leftAnalogUp:    return .up
        case .leftAnalogDown:  return .down
        case .leftAnalogLeft:  return .left
        case .leftAnalogRight: return .right
        case .rightAnalogUp, .rightAnalogDown, .rightAnalogLeft, .rightAnalogRight:
            return nil
        case .analogMode, .leftAnalog, .rightAnalog, .count:
            return nil
        @unknown default:
            return nil
        }
    }
}

// MARK: - 3DS

extension PVThinLibretroCore: PV3DSSystemResponderClient {
    public func didPush(_ button: PV3DSButton, forPlayer player: Int) {
        guard let mapped = _3dsMap(button) else { return }
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PV3DSButton, forPlayer player: Int) {
        guard let mapped = _3dsMap(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PV3DSButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        switch button {
        case .leftAnalog:
            setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
        case .rightAnalog:
            setAnalog(stick: kAnalogRightStick, axisX: xValue, axisY: yValue, forPlayer: player)
        default:
            break
        }
    }

    private func _3dsMap(_ button: PV3DSButton) -> RetroJoypad? {
        switch button {
        case .up:         return .up
        case .down:       return .down
        case .left:       return .left
        case .right:      return .right
        case .a:          return .a
        case .b:          return .b
        case .x:          return .x
        case .y:          return .y
        case .l:          return .l
        case .r:          return .r
        case .zl:         return .l2
        case .zr:         return .r2
        case .start:      return .start
        case .select:     return .select
        case .swap:       return .l3
        case .rotate:     return .r3
        case .home:       return .select
        case .leftAnalogUp, .leftAnalogDown, .leftAnalogLeft, .leftAnalogRight, .leftAnalog:
            return nil
        case .rightAnalogUp, .rightAnalogDown, .rightAnalogLeft, .rightAnalogRight, .rightAnalog:
            return nil
        case .analogMode, .count:
            return nil
        @unknown default:
            return nil
        }
    }
}

// MARK: - GameCube

extension PVThinLibretroCore: PVGameCubeSystemResponderClient {
    public func didMoveJoystick(_ button: PVGCButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        switch button {
        case .leftAnalog:
            setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
        case .rightAnalog:
            setAnalog(stick: kAnalogRightStick, axisX: xValue, axisY: yValue, forPlayer: player)
        default:
            break
        }
    }
    public func didPush(_ button: PVGCButton, forPlayer player: Int) {
        guard let mapped = gcMap(button) else { return }
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PVGCButton, forPlayer player: Int) {
        guard let mapped = gcMap(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }

    private func gcMap(_ button: PVGCButton) -> RetroJoypad? {
        switch button {
        case .up:       return .up
        case .down:     return .down
        case .left:     return .left
        case .right:    return .right
        case .a:        return .a
        case .b:        return .b
        case .x:        return .x
        case .y:        return .y
        case .l:        return .l
        case .r:        return .r
        case .z:        return .l2
        case .start:    return .start
        case .digitalL: return .l3
        case .digitalR: return .r3
        case .cUp:      return .x
        case .cDown:    return .y
        case .cLeft:    return .l2
        case .cRight:   return .r2
        case .analogUp, .analogDown, .analogLeft, .analogRight,
             .analogCUp, .analogCDown, .analogCLeft, .analogCRight,
             .leftAnalog, .rightAnalog:
            return nil
        case .count:
            return nil
        @unknown default:
            return nil
        }
    }
}

// MARK: - Wii

extension PVThinLibretroCore: PVWiiSystemResponderClient {
    public func didMoveJoystick(_ button: PVWiiMoteButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        switch button {
        case .leftAnalog:
            setAnalog(stick: kAnalogLeftStick, axisX: xValue, axisY: yValue, forPlayer: player)
        case .rightAnalog:
            setAnalog(stick: kAnalogRightStick, axisX: xValue, axisY: yValue, forPlayer: player)
        default:
            break
        }
    }
    public func didPush(_ button: PVWiiMoteButton, forPlayer player: Int) {
        guard let mapped = wiiMap(button) else { return }
        pressButton(mapped, forPlayer: player)
    }
    public func didRelease(_ button: PVWiiMoteButton, forPlayer player: Int) {
        guard let mapped = wiiMap(button) else { return }
        releaseButton(mapped, forPlayer: player)
    }

    private func wiiMap(_ button: PVWiiMoteButton) -> RetroJoypad? {
        switch button {
        // Wiimote d-pad
        case .wiiDPadUp:    return .up
        case .wiiDPadDown:  return .down
        case .wiiDPadLeft:  return .left
        case .wiiDPadRight: return .right
        // Wiimote buttons
        case .wiiA:     return .a
        case .wiiB:     return .b
        case .wiiMinus: return .select
        case .wiiPlus:  return .start
        case .wiiHome:  return .select
        case .wiiOne:   return .x
        case .wiiTwo:   return .y
        // Classic controller
        case .classicA:      return .a
        case .classicB:      return .b
        case .classicX:      return .x
        case .classicY:      return .y
        case .classicMinus:  return .select
        case .classicPlus:   return .start
        case .classicHome:   return .select
        case .classicZL:     return .l2
        case .classicZR:     return .r2
        case .classicDpadUp:    return .up
        case .classicDpadDown:  return .down
        case .classicDpadLeft:  return .left
        case .classicDpadRight: return .right
        case .classicTriggerL:  return .l
        case .classicTriggerR:  return .r
        // Nunchuk
        case .nunchukC: return .l
        case .nunchukZ: return .r
        // Generic start/select
        case .start:  return .start
        case .select: return .select
        // Motion / IR / analog stick directions — not mappable to digital joypad
        case .wiiIrUp, .wiiIrDown, .wiiIrLeft, .wiiIrRight,
             .wiiIrForward, .wiiIrBackward, .wiiIrHide,
             .wiiSwingUp, .wiiSwingDown, .wiiSwingLeft, .wiiSwingRight,
             .wiiTiltForward, .wiiTiltBackward, .wiiTiltLeft, .wiiTiltRight, .wiiTiltModifier,
             .wiiShakeX, .wiiShakeY, .wiiShakeZ,
             .nunchukStickUp, .nunchukStickDown, .nunchukStickLeft, .nunchukStickRight,
             .nunchukSwingUp, .nunchukSwingDown, .nunchukSwingLeft, .nunchukSwingRight,
             .nunchukTiltForward, .nunchukTiltBackward, .nunchukTiltLeft, .nunchukTiltRight, .nunchukTiltModifier,
             .nunchukShakeX, .nunchukShakeY, .nunchukShakeZ,
             .classicStickLeftUp, .classicStickLeftDown, .classicStickLeftLeft, .classicStickLeftRight,
             .classicStickRightUp, .classicStickRightDown, .classicStickRightLeft, .classicStickRightRight,
             .leftAnalog, .rightAnalog:
            return nil
        case .count:
            return nil
        @unknown default:
            return nil
        }
    }
}

// MARK: - LightGunResponder

extension PVThinLibretroCore: LightGunResponder {

    /// `true` when the currently-loaded libretro core advertises
    /// `RETRO_DEVICE_LIGHTGUN` (device type 4) in its controller-port info,
    /// **or** when the system identifier is present in `LightGunSystemRegistry`
    /// (the built-in baseline or a prior dynamic discovery this session).
    ///
    /// Dynamic path: after `retro_load_game()` the core sends
    /// `RETRO_ENVIRONMENT_SET_CONTROLLER_INFO`, which populates
    /// `controllerPortDescriptors`.  If any port lists a lightgun device we
    /// treat this core+system as lightgun-capable and register the system in
    /// `LightGunSystemRegistry` so that future queries (pre-load) return `true`
    /// without needing a manual static list.
    ///
    /// Fallback path: if the controller info hasn't been received yet (e.g. the
    /// property is queried before the game loads) we fall back to the registry
    /// which is seeded with the built-in baseline.
    public var gameSupportsLightGun: Bool {
        // Dynamic: check what the loaded core actually declared.
        let detectedViaControllerInfo = controllerPortDescriptors.contains { port in
            port.contains { ($0.deviceType & LibretroDeviceType.deviceMask) == LibretroDeviceType.lightgun.rawValue }
        }
        let sysID = SystemIdentifier(rawValue: systemIdentifier ?? "")
        if detectedViaControllerInfo {
            // Cache the discovery in the session registry so that
            // SystemIdentifier.supportsLightGun returns true for this system
            // even when no core is loaded (in-memory, current session only).
            if let id = sysID {
                LightGunSystemRegistry.shared.register(system: id)
            }
            return true
        }
        // Fallback: consult the registry (built-in baseline + previous dynamic discoveries).
        return sysID?.supportsLightGun ?? false
    }

    public var requiresLightGun: Bool {
        SystemIdentifier(rawValue: systemIdentifier ?? "")?.requiresLightGun ?? false
    }

    /// Convert normalized screen coordinates (0.0–1.0) to libretro light gun range
    /// (-0x7FFF .. +0x7FFF) and forward to the bridge.
    public func lightGunMovedToPoint(_ point: CGPoint, isOffscreen: Bool) {
        let x = Int16(clamping: Int((Double(point.x) * 2.0 - 1.0) * Double(Int16.max)))
        let y = Int16(clamping: Int((Double(point.y) * 2.0 - 1.0) * Double(Int16.max)))
        _lightgunLastX = x
        _lightgunLastY = y
        _lightgunAimOffscreen = isOffscreen
        _bridge.setLightgunX(x, y: y,
                             trigger: _lightgunTriggerHeld,
                             auxA: _lightgunAuxAHeld,
                             auxB: _lightgunAuxBHeld,
                             start: _lightgunStartHeld,
                             select: _lightgunSelectHeld,
                             isOffscreen: isOffscreen || _lightgunReloadHeld,
                             reload: _lightgunReloadHeld)
    }

    public func lightGunTriggerDown() {
        _lightgunTriggerHeld = true
        _bridge.setLightgunX(_lightgunLastX, y: _lightgunLastY,
                             trigger: true,
                             auxA: _lightgunAuxAHeld,
                             auxB: _lightgunAuxBHeld,
                             start: _lightgunStartHeld,
                             select: _lightgunSelectHeld,
                             isOffscreen: _lightgunAimOffscreen || _lightgunReloadHeld,
                             reload: _lightgunReloadHeld)
    }

    public func lightGunTriggerUp() {
        _lightgunTriggerHeld = false
        _bridge.setLightgunX(_lightgunLastX, y: _lightgunLastY,
                             trigger: false,
                             auxA: _lightgunAuxAHeld,
                             auxB: _lightgunAuxBHeld,
                             start: _lightgunStartHeld,
                             select: _lightgunSelectHeld,
                             isOffscreen: _lightgunAimOffscreen || _lightgunReloadHeld,
                             reload: _lightgunReloadHeld)
    }

    public func lightGunAuxADown() {
        _lightgunAuxAHeld = true
        _sendCurrentLightgunState()
    }

    public func lightGunAuxAUp() {
        _lightgunAuxAHeld = false
        _sendCurrentLightgunState()
    }

    public func lightGunAuxBDown() {
        _lightgunAuxBHeld = true
        _sendCurrentLightgunState()
    }

    public func lightGunAuxBUp() {
        _lightgunAuxBHeld = false
        _sendCurrentLightgunState()
    }

    public func lightGunStartDown() {
        _lightgunStartHeld = true
        _sendCurrentLightgunState()
    }

    public func lightGunStartUp() {
        _lightgunStartHeld = false
        _sendCurrentLightgunState()
    }

    public func lightGunSelectDown() {
        _lightgunSelectHeld = true
        _sendCurrentLightgunState()
    }

    public func lightGunSelectUp() {
        _lightgunSelectHeld = false
        _sendCurrentLightgunState()
    }

    public func lightGunReloadDown() {
        _lightgunReloadHeld = true
        // offscreen is computed as _lightgunAimOffscreen || _lightgunReloadHeld in _sendCurrentLightgunState
        _sendCurrentLightgunState()
    }

    public func lightGunReloadUp() {
        _lightgunReloadHeld = false
        // restore aim-based offscreen state; do not force false if aim is still offscreen
        _sendCurrentLightgunState()
    }

    // MARK: Private helpers

    private func _sendCurrentLightgunState() {
        _bridge.setLightgunX(_lightgunLastX, y: _lightgunLastY,
                             trigger: _lightgunTriggerHeld,
                             auxA: _lightgunAuxAHeld,
                             auxB: _lightgunAuxBHeld,
                             start: _lightgunStartHeld,
                             select: _lightgunSelectHeld,
                             isOffscreen: _lightgunAimOffscreen || _lightgunReloadHeld,
                             reload: _lightgunReloadHeld)
    }
}

// MARK: - LightGunResponder stored state (via associated objects)
// PVThinLibretroCore is an ObjC class; we use a small state holder to avoid
// adding Swift stored properties to an extension.

private var _lgTriggerKey  = 0
private var _lgAuxAKey     = 0
private var _lgAuxBKey     = 0
private var _lgStartKey    = 0
private var _lgSelectKey   = 0
private var _lgReloadKey   = 0
private var _lgOffscreenKey = 0
private var _lgLastXKey    = 0
private var _lgLastYKey    = 0

// Swift Bool bridged through ObjC associated objects becomes NSNumber at runtime;
// using `as? Bool` always returns nil. Use `as? NSNumber` + `.boolValue` instead.
extension PVThinLibretroCore {
    fileprivate var _lightgunTriggerHeld: Bool {
        get {
            (objc_getAssociatedObject(self, &_lgTriggerKey) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &_lgTriggerKey,
                                     NSNumber(value: newValue),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    fileprivate var _lightgunAuxAHeld: Bool {
        get {
            (objc_getAssociatedObject(self, &_lgAuxAKey) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &_lgAuxAKey,
                                     NSNumber(value: newValue),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    fileprivate var _lightgunAuxBHeld: Bool {
        get {
            (objc_getAssociatedObject(self, &_lgAuxBKey) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &_lgAuxBKey,
                                     NSNumber(value: newValue),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    fileprivate var _lightgunStartHeld: Bool {
        get {
            (objc_getAssociatedObject(self, &_lgStartKey) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &_lgStartKey,
                                     NSNumber(value: newValue),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    fileprivate var _lightgunSelectHeld: Bool {
        get {
            (objc_getAssociatedObject(self, &_lgSelectKey) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &_lgSelectKey,
                                     NSNumber(value: newValue),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    fileprivate var _lightgunReloadHeld: Bool {
        get {
            (objc_getAssociatedObject(self, &_lgReloadKey) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &_lgReloadKey,
                                     NSNumber(value: newValue),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    /// Tracks whether the aim direction (from `lightGunMovedToPoint`) is offscreen.
    /// The effective offscreen state delivered to the bridge is `_lightgunAimOffscreen || _lightgunReloadHeld`.
    fileprivate var _lightgunAimOffscreen: Bool {
        get {
            (objc_getAssociatedObject(self, &_lgOffscreenKey) as? NSNumber)?.boolValue ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &_lgOffscreenKey,
                                     NSNumber(value: newValue),
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    fileprivate var _lightgunLastX: Int16 {
        get { (objc_getAssociatedObject(self, &_lgLastXKey) as? NSNumber).map { Int16($0.int32Value) } ?? 0 }
        set { objc_setAssociatedObject(self, &_lgLastXKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    fileprivate var _lightgunLastY: Int16 {
        get { (objc_getAssociatedObject(self, &_lgLastYKey) as? NSNumber).map { Int16($0.int32Value) } ?? 0 }
        set { objc_setAssociatedObject(self, &_lgLastYKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

// MARK: - RetroArch Generic

extension PVThinLibretroCore: PVRetroArchCoreResponderClient {
    // PVRetroArchCoreResponderClient has no additional button push/release methods
    // beyond those inherited from ButtonResponder, KeyboardResponder, MouseResponder,
    // and JoystickResponder — all of which are already implemented above.
    // This conformance enables systems like AppleII, C64, Macintosh, PalmOS, and
    // TIC-80 to use the thin libretro wrapper with keyboard/mouse input.
}
