//
//  GCControllerExtensions.swift
//  Provenance
//
//  Created by Sev Gerk on 1/27/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

import GameController

extension GCController {
    func supportsThumbstickButtons() -> Bool {
        if #available(iOS 12.1, tvOS 12.1, *) {
            let controller = self.extendedGamepad
            return (controller!.responds(to: #selector(getter: GCExtendedGamepad.leftThumbstickButton))) && controller!.leftThumbstickButton != nil
        } else {
            // Fallback on earlier versions
        }
        return false
    }
}
