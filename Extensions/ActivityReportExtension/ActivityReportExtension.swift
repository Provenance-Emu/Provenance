//
//  ActivityReportExtension.swift
//  ActivityReportExtension
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

// https://developer.apple.com/documentation/deviceactivity/deviceactivitymonitor

import DeviceActivity
import SwiftUI

@available(iOSApplicationExtension 16.0, *)
@main
struct ActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        TotalActivityReport { totalActivity in
            TotalActivityView(totalActivity: totalActivity)
        }
        // Add more reports here...
    }
}
