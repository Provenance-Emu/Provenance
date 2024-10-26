//
//  PVDuckStationOptions.swift
//  PVDuckStation
//
//  Created by Joseph Mattiello on 10/8/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//


@objc public class PVDuckStationOptions: NSObject, CoreOptions {

    static var gsOption: CoreOption = {
        .enumeration(.init(title: "Graphics Handler",
                           description: "(Requires Restart)",
                           requiresRestart: true),
                     values: [
                        .init(title: "OpenGL", description: "OpenGL", value: 0),
                        .init(title: "Vulkan", description: "Vulkan (Experimental)", value: 1)
                     ],
                     defaultValue: 0)
    }()

    public static var options: [CoreOption] {
        var options = [CoreOption]()
        let coreOptions: [CoreOption] = [gsOption]
        let coreGroup:CoreOption = .group(.init(title: "DuckStation Core",
                                                description: "Global options for DuckStation"),
                                          subOptions: coreOptions)
        options.append(contentsOf: [coreGroup])
        return options
    }
}

@objc public extension PVDuckStationCoreBridge {
    @objc var gs: Int {
        PVDuckStationCore.valueForOption(PVDuckStationOptions.gsOption).asInt ?? 0
    }

//    func parseOptions() {
//        self.gsPreference = NSNumber(value: gs).int8Value
//    }
}
