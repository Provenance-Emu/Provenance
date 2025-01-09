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

internal final class PVProSystemCoreOptions: CoreOptions, Sendable {

    public static var options: [CoreOption] {
        var options = [CoreOption]()

        let coreGroup = CoreOption.group(.init(title: "Core",
                                               description: nil),
                                         subOptions: [])

        let videoGroup = CoreOption.group(
            .init(title: "Video",
                  description: nil),
            subOptions: [])

        options.append(coreGroup)
        options.append(videoGroup)

        return options
    }
}

extension PVProSystemCore: CoreOptional {
    public static var options: [PVCoreBridge.CoreOption] {
        PVProSystemCoreOptions.options
    }
}

@objc
public extension PVProSystemCore {
}
