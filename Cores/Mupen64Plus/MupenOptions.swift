//
//  MupenOptions.swift
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 4/11/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation
import PVSupport

extension MupenGameCore: CoreOptional {
//    public func valueForOption<T>(_ option: CoreOption<T>) -> T where T : Decodable, T : Encodable {
//
//    }

    public static var options: [CoreOption] {
        var options = [CoreOption]()

        let glidenOption = CoreOption.multi(display: CoreOptionValueDisplay(title: "GFX Plugin",
                                                                            description: nil),
                                            values: [
                                                CoreOptionMultiValue(title: "GlideN64", description: "Newer, GLES3 GFX Driver"),
                                                CoreOptionMultiValue(title: "RICE", description: "Older, faster, less feature rich GFX Driver"),
        ])

        let rspOptions = CoreOption.multi(display: CoreOptionValueDisplay(title: "RSP Plugin",
                                                                          description: "GlideN64 is newer but slower. Try RICE for older devices"),
                                          values: [
                                              CoreOptionMultiValue(title: "RSPHLE", description: "Faster, default RSP"),
                                              CoreOptionMultiValue(title: "CXD4", description: "Slower. More features for some games, breaks others."),
        ])
        let plugins = CoreOption.group(display: CoreOptionValueDisplay(title: "Plugins", description: nil), subOptions: [glidenOption, rspOptions])

        let hwLighting = CoreOption.bool(display: CoreOptionValueDisplay(title: "HW Lighting", description: "Per-pixel lighting"), defaultValue: false)
        let videoOptions = CoreOption.group(display: CoreOptionValueDisplay(title: "Video"), subOptions: [hwLighting])
        options.append(contentsOf: [plugins, videoOptions])
        return options
    }
}

@objc
extension MupenGameCore {
    public static var useRice: Bool {
        return valueForOption(String.self, "GFX Plugin") == "RICE"
    }

    public static var useCXD4: Bool {
        return valueForOption(String.self, "RSP Plugin") == "CXD4"
    }

    public static var perPixelLighting: Bool {
        return valueForOption(Bool.self, "HW Lighting") ?? false
    }
}
