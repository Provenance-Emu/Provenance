//
//  CoreOptions.swift
//  Core-VirtualJaguar
//
//  Created by Joseph Mattiello on 9/19/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation
//import PVSupport
import PVCoreBridge
import PVCoreObjCBridge
import PVEmulatorCore

internal final class PVFCEUOptions: CoreOptions, Sendable {

    public static var options: [CoreOption] {
        var options = [CoreOption]()

        let coreGroup = CoreOption.group(.init(title: "Core", description: nil),
                                         subOptions: [fourscoreOption, famicomMicOption])
        let videoGroup = CoreOption.group(.init(title: "Video", description: nil),
                                         subOptions: [])
        options.append(coreGroup)
        options.append(videoGroup)

        return options
    }

    // MARK: - Core Options

    /// Manual fourscore/4-player mode override.
    /// 0 = Auto (detect from ROM header — default)
    /// 1 = Always On (force-enable NES Four Score / Famicom 4-player)
    /// 2 = Off (disable even when ROM header requests it)
    static var fourscoreOption: CoreOption {
        CoreOption.enumeration(
            .init(
                title: "4-Player / Fourscore",
                description: "Enable NES Four Score or Famicom 4-player adapter. Auto detects from ROM header (works for most Famicom 4-player games). Use 'Always On' for NES Four Score games (e.g. Gauntlet, Super Dodge Ball) that lack header detection.",
                requiresRestart: true
            ),
            values: [
                .init(title: "Auto",       description: "Detect from ROM header", value: 0),
                .init(title: "Always On",  description: "Force-enable fourscore",  value: 1),
                .init(title: "Off",        description: "Disable fourscore",       value: 2),
            ],
            defaultValue: 0
        )
    }

    static var fourscoreMode: Int {
        valueForOption(fourscoreOption)
    }

    static var famicomMicOption: CoreOption {
        CoreOption.bool(
            .init(
                title: "Famicom Microphone",
                description: "Enable Famicom controller 2 microphone input via iOS mic. Only needed for games that use the Famicom mic (e.g. Zelda JP, Gimmick!). Disabling preserves the P2 Start button for NES 2-player games.",
                requiresRestart: false
            ),
            defaultValue: false
        )
    }

    static var famicomMicEnabled: Bool {
        valueForOption(famicomMicOption)
    }

}

extension PVFCEUEmulatorCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVFCEUOptions.options
    }
}

@objc
public extension PVFCEUEmulatorCore {
}

//
//extension PVJaguarGameCore: CoreActions {
//	public var coreActions: [CoreAction]? {
//		let bios = CoreAction(title: "Use Jaguar BIOS", options: nil)
//		let fastBlitter =  CoreAction(title: "Use fast blitter", options:nil)
//		return [bios, fastBlitter]
//	}
//
//	public func selected(action: CoreAction) {
//		DLOG("\(action.title), \(String(describing: action.options))")
//	}
//}
