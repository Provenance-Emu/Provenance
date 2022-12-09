//
//  WidgetExtensionBundle.swift
//  WidgetExtension
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import WidgetKit
import SwiftUI

@main
struct WidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        WidgetExtension()
        if #available(iOSApplicationExtension 16.1, *) {
            WidgetExtensionLiveActivity()
        } else {
            // Fallback on earlier versions
        }
    }
}
