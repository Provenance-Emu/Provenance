//
//  ProSystemGameCore.swift
//  PVProSystem
//
//  Created by Joseph Mattiello on 1/20/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import AVFoundation

let VIDEO_WIDTH = 320
let VIDEO_HEIGHT = 292

@objc
enum PV7800MFiButton : Int {
    case joy1Right
    case joy1Left
    case joy1Down
    case joy1Up
    case joy1Button1
    case joy1Button2
    case joy2Right
    case joy2Left
    case joy2Down
    case joy2Up
    case joy2Button1
    case joy2Button2
    case consoleReset
    case consoleSelect
    case consolePause
    case consoleLeftDifficulty
    case consoleRightDifficulty
}

@objc
@objcMembers
public class PVProSystemGameCore : PVEmulatorCore {
    public var _videoBuffer =  UnsafeMutablePointer<UInt32>.allocate(capacity: 320 * 292 * 4)
//    public var _videoBufferTest = calloc(320 * 292 * 4, MemoryLayout<UInt32>.size).assumingMemoryBound(to: UInt32.self)

    public var displayPalette = Array.init(repeating: UInt32(0), count: 256)
    public var soundBuffer =  UnsafeMutablePointer<UInt8>.allocate(capacity: 8192)
    public var inputState =  UnsafeMutablePointer<UInt8>.allocate(capacity: 17)
    public var videoWidth: Int = 0
    public var videoHeight: Int = 0
    public var isLightgunEnabled: Bool = false

    // TODO: Make me work
    public var biosDirectoryPath: String? {
        return self.biosPath
    }
    //    uint32_t *_videoBuffer;
    //    uint32_t _displayPalette[256];
    //    uint8_t  *_soundBuffer;
    //    uint8_t _inputState[17];
    //    int _videoWidth, _videoHeight;
    //    BOOL _isLightgunEnabled;

    deinit {
        _videoBuffer.deallocate()
//        _displayPalette.deallocate()
        soundBuffer.deallocate()
        inputState.deallocate()
    }


//    @objc
//    public func setPalette32() {
//        for index in 0..<256 {
//            let r = CFSwapInt32LittleToHost(palette_data[(index * 3) + 0] << 16)
//            let g = CFSwapInt32LittleToHost(palette_data[(index * 3) + 1] << 8)
//            let b = CFSwapInt32LittleToHost(palette_data[(index * 3) + 2] << 0)
//            displayPalette[index] = r | g | b
    //        }
    //    }

    // MARK: - Video

    public override var videoBuffer: UnsafeRawPointer? {
        return UnsafeRawPointer(_videoBuffer)
    }

//    public override var screenRect: CGRect {
//        return CGRect(x: 0, y: 0, width: maria_visibleArea.getLength(), height: maria_visibleArea.getHeight())
//    }
//
//    public override var aspectSize: CGSize {
//        return CGSize(width: maria_visibleArea.getLength(), height: maria_visibleArea.getHeight())
//    }

    public override var bufferSize: CGSize {
        return CGSize(width: VIDEO_WIDTH, height: VIDEO_HEIGHT)
    }

    public override var pixelFormat: GLenum {
        return GLenum(GL_BGRA)
    }

    public override var pixelType: GLenum {
        return GLenum(GL_UNSIGNED_BYTE)
    }

    public override var internalPixelFormat: GLenum {
        return GLenum(GL_RGBA)
    }

    // MARK: - Audio

    public override var audioSampleRate: Double {
        return 48000
    }

    public override var channelCount: AVAudioChannelCount {
        return 1
    }

    public override var audioBitDepth: UInt {
        return 8
    }

    let ProSystemMap = [3, 2, 1, 0, 4, 5, 9, 8, 7, 6, 10, 11, 13, 14, 12, 15, 16]

    // MARK: Input
    @objc public func pollControllers() {
        for playerIndex in 0..<2 {
            var controllerMaybe: GCController? = nil

            if let controller1 = controller1 && playerIndex == 0 {
                controllerMaybe = controller1
            } else if let controller2 = controller2 && playerIndex == 1 {
                controllerMaybe = controller2
            }

            guard let controller = controllerMaybe else { continue }

            let playerInputOffset: Int = playerIndex * 6

            if let gamepad = controller.extendedGamepad {
                let dpad: GCControllerDirectionPad = gamepad.dpad

                // Up
                inputState[Int(.upUp) + playerInputOffset] = dpad?.up.isPressed != nil || gamepad?.leftThumbstick.up.isPressed != nil
                // Down
                inputState[Int(PV7800MFiButtonJoy1Down) + playerInputOffset] = dpad?.down.isPressed != nil || gamepad?.leftThumbstick.down.isPressed != nil
                // Left
                inputState[Int(PV7800MFiButtonJoy1Left) + playerInputOffset] = dpad?.left.isPressed != nil || gamepad?.leftThumbstick.left.isPressed != nil
                // Right
                inputState[Int(PV7800MFiButtonJoy1Right) + playerInputOffset] = dpad?.right.isPressed != nil || gamepad?.leftThumbstick.right.isPressed != nil

                // Button 1
                inputState[Int(PV7800MFiButtonJoy1Button1) + playerInputOffset] = gamepad?.buttonA.isPressed != nil || gamepad?.buttonY.isPressed != nil
                // Button 2
                inputState[Int(PV7800MFiButtonJoy1Button2) + playerInputOffset] = gamepad?.buttonB.isPressed != nil || gamepad?.buttonX.isPressed != nil

                // Reset
                inputState[PV7800MFiButtonConsoleReset] = gamepad?.rightShoulder.isPressed
                // Select
                inputState[PV7800MFiButtonConsoleSelect] = gamepad?.leftShoulder.isPressed
                // Pause - Opting out of system pause…
                //            _inputState[PV7800MFiButtonConsolePause] = (gamepad.buttonY.isPressed);

                // TO DO: Move Difficulty options these to Menu
                // Left Difficulty
                //            _inputState[PV7800MFiButtonConsoleLeftDifficulty] = (gamepad.leftTrigger.isPressed);
                // Right Difficulty
                //            _inputState[PV7800MFiButtonConsoleRightDifficulty] = (gamepad.rightTrigger.isPressed);
            } else let gamepad = controller.gamepad {
                let dpad: GCControllerDirectionPad = gamepad.dpad

                // Up
                inputState[Int(PV7800MFiButtonJoy1Up) + playerInputOffset] = dpad?.up.isPressed
                // Down
                inputState[Int(PV7800MFiButtonJoy1Down) + playerInputOffset] = dpad?.down.isPressed
                // Left
                inputState[Int(PV7800MFiButtonJoy1Left) + playerInputOffset] = dpad?.left.isPressed
                // Right
                inputState[Int(PV7800MFiButtonJoy1Right) + playerInputOffset] = dpad?.right.isPressed

                // Button 1
                inputState[Int(PV7800MFiButtonJoy1Button1) + playerInputOffset] = gamepad?.buttonA.isPressed != nil || gamepad?.buttonY.isPressed != nil
                // Button 2
                inputState[Int(PV7800MFiButtonJoy1Button2) + playerInputOffset] = gamepad?.buttonB.isPressed != nil || gamepad?.buttonX.isPressed != nil

                // Reset
                inputState[PV7800MFiButtonConsoleReset] = gamepad?.rightShoulder.isPressed
                // Select
                inputState[PV7800MFiButtonConsoleSelect] = gamepad?.leftShoulder.isPressed

                // Pause
                //            _inputState[PV7800MFiButtonConsolePause] = (gamepad.buttonY.isPressed);

                // TO DO: Move Difficulty options these to Menu
                // Left Difficulty
                //            _inputState[PV7800MFiButtonConsoleLeftDifficulty] = (gamepad.buttonX.isPressed);
                // Right Difficulty
                //            _inputState[PV7800MFiButtonConsoleRightDifficulty] = (gamepad.buttonY.isPressed);
            } else if let gamepad = controller.microGamepad {
                let dpad: GCControllerDirectionPad = gamepad.dpad

                inputState[PV7800MFiButtonJoy1Up] = (dpad?.up.value ?? 0.0) > 0.5
                inputState[PV7800MFiButtonJoy1Down] = (dpad?.down.value ?? 0.0) > 0.5
                inputState[PV7800MFiButtonJoy1Left] = (dpad?.left.value ?? 0.0) > 0.5
                inputState[PV7800MFiButtonJoy1Right] = (dpad?.right.value ?? 0.0) > 0.5

                inputState[PV7800MFiButtonJoy1Button1] = gamepad?.buttonX.isPressed
                inputState[PV7800MFiButtonJoy1Button2] = gamepad?.buttonA.isPressed
            }
        }
}

}

@objc public
extension PVProSystemGameCore : PV7800SystemResponderClient {
    @objc public func didPush7800Button(_ button: PV7800Button, forPlayer player: Int) {
        let playerShift: Int = player == 0 ? 0 : 6

        switch button {
        // Controller buttons P1 + P2
        case .up, .down, .left, .right, .fire1, .fire2:
            inputState[ProSystemMap[Int(button) + playerShift]] = 1
        // Console buttons
        case .select, .pause, .reset:
            inputState[ProSystemMap[Int(button) + 6]] = 1
        // Difficulty switches
        case .leftDiff, .rightDiff:
            inputState[ProSystemMap[Int(button) + 6]] ^= 1 << 0
        default:
            break
        }
    }

    @objc public func didRelease7800Button(_ button: PV7800Button, forPlayer player: Int) {
        let playerShift: Int = player == 0 ? 0 : 6

        switch button {
        // Controller buttons P1 + P2
        case .up, .down, .left, .right, .fire1, .fire2:
            inputState[ProSystemMap[Int(button) + playerShift]] = 0
        // Console buttons
        case .select, .pause, .reset:
            inputState[ProSystemMap[Int(button) + 6]] = 0
        default:
            break
        }
    }

    @objc public func leftMouseDown(at aPoint: CGPoint) {
        if isLightgunEnabled {
            mouseMoved(at: aPoint)

            inputState[3] = 0
        }
    }

    @objc public func leftMouseUp() {
        if isLightgunEnabled {
            inputState[3] = 1
        }
    }
}
