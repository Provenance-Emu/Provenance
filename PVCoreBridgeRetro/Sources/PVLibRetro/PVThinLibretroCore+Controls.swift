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
#if canImport(GameController)
import GameController
#endif

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

// MARK: - Helper extension on PVThinLibretroCore

extension PVThinLibretroCore {

    /// Press a libretro joypad button.
    func pressButton(_ btn: RetroJoypad, forPlayer player: Int) {
        _bridge.setButton(btn.rawValue, pressed: true, forPlayer: UInt32(player))
    }

    /// Release a libretro joypad button.
    func releaseButton(_ btn: RetroJoypad, forPlayer player: Int) {
        _bridge.setButton(btn.rawValue, pressed: false, forPlayer: UInt32(player))
    }

    /// Set analog stick axis value (CGFloat -1..1 range mapped to libretro int16).
    func setAnalog(stick: UInt32, axisX: CGFloat, axisY: CGFloat, forPlayer player: Int) {
        let x = Int16(max(-1.0, min(1.0, axisX)) * CGFloat(kAnalogMax))
        let y = Int16(max(-1.0, min(1.0, axisY)) * CGFloat(kAnalogMax))
        _bridge.setAnalogIndex(stick, axis: kAnalogAxisX, value: x, forPlayer: UInt32(player))
        _bridge.setAnalogIndex(stick, axis: kAnalogAxisY, value: y, forPlayer: UInt32(player))
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
        case .count:   return .b
        @unknown default: return .b
        }
    }
}

// MARK: - PSX

extension PVThinLibretroCore: PVPSXSystemResponderClient {
    public func didPush(_ button: PVPSXButton, forPlayer player: Int) {
        guard let mapped = psxMapDigital(button) else { return }
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
    public func didPush(_ button: PVDSButton, forPlayer player: Int) {
        pressButton(dsMap(button), forPlayer: player)
    }
    public func didRelease(_ button: PVDSButton, forPlayer player: Int) {
        releaseButton(dsMap(button), forPlayer: player)
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
        case .count:   return .b
        @unknown default: return .b
        }
    }
}

// MARK: - KeyboardResponder

extension PVThinLibretroCore: KeyboardResponder {

    public var gameSupportsKeyboard: Bool { true }
    public var requiresKeyboard: Bool { false }

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

    public var gameSupportsMouse: Bool { true }
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
