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
                                         subOptions: [])
        let videoGroup = CoreOption.group(.init(title: "Video", description: nil),
                                         subOptions: [])
        options.append(coreGroup)
        options.append(videoGroup)

        return options
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
