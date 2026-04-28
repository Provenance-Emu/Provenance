//
//  PVDolphinCore.swift
//  PVDolphin
//
//  Created by Joseph Mattiello on 10/8/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVCoreBridge
import GameController
import PVLogging
import PVAudio
import PVEmulatorCore
import PVRcheevosBridge

@objc
@objcMembers
open class PVDolphinCore: PVEmulatorCore, @unchecked Sendable {
    // MARK: Lifecycle

    let _bridge: PVDolphinCoreBridge = .init()

    open override var supportsSkins: Bool { false }

    /// Dolphin detects JIT availability at startup and selects the appropriate
    /// execution back-end (JIT or Cached Interpreter) automatically.
    open override var jitRequirement: PVJITRequirement { .automaticWithFallback }

    public required init() {
        super.init()
        self.bridge = (_bridge as! any ObjCBridgedCoreBridge)
    }

    public override func executeFrame() {
        super.executeFrame()
        if achievementsActive {
            tickAchievements()
        }
    }
}

extension PVDolphinCore: PVWiiSystemResponderClient {
    public func didMoveJoystick(_ button: PVCoreBridge.PVWiiMoteButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didMoveJoystick(_ button: Int, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
    public func didPush(_ button: PVCoreBridge.PVWiiMoteButton, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVWiiMoteButton, forPlayer player: Int) {
        (_bridge as! PVWiiSystemResponderClient).didRelease(button, forPlayer: player)
    }
}

extension PVDolphinCore: PVGameCubeSystemResponderClient {
    public func didPush(_ button: PVCoreBridge.PVGCButton, forPlayer player: Int) {
        (_bridge as! PVGameCubeSystemResponderClient).didPush(button, forPlayer: player)
    }
    public func didRelease(_ button: PVCoreBridge.PVGCButton, forPlayer player: Int) {
        (_bridge as! PVGameCubeSystemResponderClient).didRelease(button, forPlayer: player)
    }
    public func didMoveJoystick(_ button: PVCoreBridge.PVGCButton, withXValue xValue: CGFloat, withYValue yValue: CGFloat, forPlayer player: Int) {
        (_bridge as! PVGameCubeSystemResponderClient).didMoveJoystick(button, withXValue: xValue, withYValue: yValue, forPlayer: player)
    }
}

extension PVDolphinCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVDolphinCoreOptions.options
    }
}

extension PVDolphinCore: GameWithCheat {
    @objc public func setCheat(
        code: String,
        type: String,
        codeType: String,
        cheatIndex: UInt8,
        enabled: Bool
    ) -> Bool
    {
        do {
            ILOG("Calling setCheat \(code) \(type) \(codeType)")
            try self._bridge.setCheat(code, setType: type, setCodeType: codeType, setIndex: cheatIndex, setEnabled: enabled)
            return true
        } catch let error {
            ELOG("Error setCheat \(error)")
            return false
        }
    }

    public var supportsCheatCode: Bool
    {
        return true
    }

    public var cheatCodeTypes: [String] {
        return [
            "Gecko",
            "Pro Action Replay",
        ]
    }

    public func resetCheatCodes() {
        _bridge.resetCheatCodes()
    }
}

extension PVDolphinCore: CoreActions {
    enum Actions {
        static var toggleVBISkip: CoreAction {
            let currentValue = PVDolphinCoreOptions.viSkip
            return CoreAction(
                title: currentValue ? "Disable VBI Skip" : "Enable VBI Skip",
                requiresReset: false,
                options: nil,
                style: .default
            )
        }

        static var vbiFrequency25: CoreAction {
            CoreAction(title: "VBI Frequency: 25% (Very Slow)", requiresReset: false, style: .default)
        }
        static var vbiFrequency33: CoreAction {
            CoreAction(title: "VBI Frequency: 33% (Slow)", requiresReset: false, style: .default)
        }
        static var vbiFrequency50: CoreAction {
            CoreAction(title: "VBI Frequency: 50% (Half Speed)", requiresReset: false, style: .default)
        }
        static var vbiFrequency66: CoreAction {
            CoreAction(title: "VBI Frequency: 66% (Reduced)", requiresReset: false, style: .default)
        }
        static var vbiFrequency75: CoreAction {
            CoreAction(title: "VBI Frequency: 75% (Lower)", requiresReset: false, style: .default)
        }
        static var vbiFrequency85: CoreAction {
            CoreAction(title: "VBI Frequency: 85% (Slightly Lower)", requiresReset: false, style: .default)
        }
        static var vbiFrequency100: CoreAction {
            CoreAction(title: "VBI Frequency: 100% (Default)", requiresReset: false, style: .default)
        }

        static var cpuFrequency25: CoreAction {
            CoreAction(title: "CPU Frequency: 25% (Very Slow)", requiresReset: true, style: .default)
        }
        static var cpuFrequency33: CoreAction {
            CoreAction(title: "CPU Frequency: 33% (Slow)", requiresReset: true, style: .default)
        }
        static var cpuFrequency50: CoreAction {
            CoreAction(title: "CPU Frequency: 50% (Half Speed)", requiresReset: true, style: .default)
        }
        static var cpuFrequency66: CoreAction {
            CoreAction(title: "CPU Frequency: 66% (Reduced)", requiresReset: true, style: .default)
        }
        static var cpuFrequency75: CoreAction {
            CoreAction(title: "CPU Frequency: 75% (Lower)", requiresReset: true, style: .default)
        }
        static var cpuFrequency85: CoreAction {
            CoreAction(title: "CPU Frequency: 85% (Slightly Lower)", requiresReset: true, style: .default)
        }
        static var cpuFrequency90: CoreAction {
            CoreAction(title: "CPU Frequency: 90% (Slightly Reduced)", requiresReset: true, style: .default)
        }
        static var cpuFrequency100: CoreAction {
            CoreAction(title: "CPU Frequency: 100% (Default)", requiresReset: true, style: .default)
        }
    }

    public var coreActions: [CoreAction]? {
        return [
            Actions.toggleVBISkip,
            Actions.vbiFrequency25,
            Actions.vbiFrequency33,
            Actions.vbiFrequency50,
            Actions.vbiFrequency66,
            Actions.vbiFrequency75,
            Actions.vbiFrequency85,
            Actions.vbiFrequency100,
            Actions.cpuFrequency25,
            Actions.cpuFrequency33,
            Actions.cpuFrequency50,
            Actions.cpuFrequency66,
            Actions.cpuFrequency75,
            Actions.cpuFrequency85,
            Actions.cpuFrequency90,
            Actions.cpuFrequency100
        ]
    }

    public func selected(action: CoreAction) {
        switch action.title {
        case Actions.toggleVBISkip.title, "Enable VBI Skip", "Disable VBI Skip":
            let currentValue = PVDolphinCoreOptions.viSkip
            PVDolphinCore.setValue(!currentValue, forOption: PVDolphinCoreOptions.viSkipOption)
            ILOG("VBI Skip toggled to: \(!currentValue)")

        case Actions.vbiFrequency25.title:
            PVDolphinCore.setValue(true, forOption: PVDolphinCoreOptions.enableVBIOverrideOption)
            PVDolphinCore.setValue(25.0, forOption: PVDolphinCoreOptions.vbiFrequencyRangeOption)
            ILOG("VBI Frequency set to: 25%")

        case Actions.vbiFrequency33.title:
            PVDolphinCore.setValue(true, forOption: PVDolphinCoreOptions.enableVBIOverrideOption)
            PVDolphinCore.setValue(33.0, forOption: PVDolphinCoreOptions.vbiFrequencyRangeOption)
            ILOG("VBI Frequency set to: 33%")

        case Actions.vbiFrequency50.title:
            PVDolphinCore.setValue(true, forOption: PVDolphinCoreOptions.enableVBIOverrideOption)
            PVDolphinCore.setValue(50.0, forOption: PVDolphinCoreOptions.vbiFrequencyRangeOption)
            ILOG("VBI Frequency set to: 50%")

        case Actions.vbiFrequency66.title:
            PVDolphinCore.setValue(true, forOption: PVDolphinCoreOptions.enableVBIOverrideOption)
            PVDolphinCore.setValue(66.0, forOption: PVDolphinCoreOptions.vbiFrequencyRangeOption)
            ILOG("VBI Frequency set to: 66%")

        case Actions.vbiFrequency75.title:
            PVDolphinCore.setValue(true, forOption: PVDolphinCoreOptions.enableVBIOverrideOption)
            PVDolphinCore.setValue(75.0, forOption: PVDolphinCoreOptions.vbiFrequencyRangeOption)
            ILOG("VBI Frequency set to: 75%")

        case Actions.vbiFrequency85.title:
            PVDolphinCore.setValue(true, forOption: PVDolphinCoreOptions.enableVBIOverrideOption)
            PVDolphinCore.setValue(85.0, forOption: PVDolphinCoreOptions.vbiFrequencyRangeOption)
            ILOG("VBI Frequency set to: 85%")

        case Actions.vbiFrequency100.title:
            PVDolphinCore.setValue(false, forOption: PVDolphinCoreOptions.enableVBIOverrideOption)
            PVDolphinCore.setValue(100.0, forOption: PVDolphinCoreOptions.vbiFrequencyRangeOption)
            ILOG("VBI Frequency set to: 100% (Default)")

        case Actions.cpuFrequency25.title:
            PVDolphinCore.setValue(25, forOption: PVDolphinCoreOptions.cpuClockOption)
            ILOG("CPU Frequency set to: 25%")

        case Actions.cpuFrequency33.title:
            PVDolphinCore.setValue(33, forOption: PVDolphinCoreOptions.cpuClockOption)
            ILOG("CPU Frequency set to: 33%")

        case Actions.cpuFrequency50.title:
            PVDolphinCore.setValue(50, forOption: PVDolphinCoreOptions.cpuClockOption)
            ILOG("CPU Frequency set to: 50%")

        case Actions.cpuFrequency66.title:
            PVDolphinCore.setValue(66, forOption: PVDolphinCoreOptions.cpuClockOption)
            ILOG("CPU Frequency set to: 66%")

        case Actions.cpuFrequency75.title:
            PVDolphinCore.setValue(75, forOption: PVDolphinCoreOptions.cpuClockOption)
            ILOG("CPU Frequency set to: 75%")

        case Actions.cpuFrequency85.title:
            PVDolphinCore.setValue(85, forOption: PVDolphinCoreOptions.cpuClockOption)
            ILOG("CPU Frequency set to: 85%")

        case Actions.cpuFrequency90.title:
            PVDolphinCore.setValue(90, forOption: PVDolphinCoreOptions.cpuClockOption)
            ILOG("CPU Frequency set to: 90%")

        case Actions.cpuFrequency100.title:
            PVDolphinCore.setValue(100, forOption: PVDolphinCoreOptions.cpuClockOption)
            ILOG("CPU Frequency set to: 100%")

        default:
            WLOG("Unknown action: \(action.title)")
        }
    }
}
