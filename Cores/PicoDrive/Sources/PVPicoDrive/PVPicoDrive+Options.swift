//
//  PVTGBDualCore+Options.swift
//  PVTGBDualCore
//
//  Created by Joseph Mattiello on 5/30/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVCoreBridge
import PVLogging
import libpicodrive
import PVEmulatorCore

extension PVPicoDrive: @preconcurrency CoreOptional {
    @MainActor public static var options: [CoreOption] {
        var options = [CoreOption]()
 
        #warning("TODO: Impliment this the options")
        let coreGroup = CoreOption.group(.init(title: "Core",
                                                description: nil),
                                          subOptions: [])


        let videoGroup = CoreOption.group(.init(title: "Video",
                                                description: nil),
                                          subOptions: [])


        options.append(coreGroup)
        options.append(videoGroup)

        return options
    }

    // MARK: ---- Core ---- //
    
    // MARK: ----- Video ------ //
    
    @MainActor
    public func get(variable: String) -> Any? {
        switch variable {
        default:
            WLOG("Unsupported variable <\(variable)>")
            return nil
        }
    }
}
