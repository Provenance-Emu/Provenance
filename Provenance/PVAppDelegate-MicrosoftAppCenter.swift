//
//  PVAppDelegate-MicrosoftAppCenter.swift
//  Provenance
//
//  Created by Joseph Mattiello on 8/7/20.
//  Copyright © 2020 Provenance Emu. All rights reserved.
//

import Foundation
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes

func _initAppCenter() {
    MSAppCenter.start("862ca352-4607-4f8e-8c77-1248fa68ca3a", withServices:[
      MSAnalytics.self,
      MSCrashes.self
    ])
}
