//
//  PVAppDelegate+AppCenter.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/2/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation

#if canImport(AppCenter)
import AppCenter
import AppCenterAnalytics
//import AppCenterCrashes
import PVSupport

extension PVAppDelegate {
    public func _initAppCenter() {
        guard let secretKey = Bundle.main.object(forInfoDictionaryKey: "appcenter") as? String else {
            ELOG("No value for Info.plist key 'appcenter'")
            return
        }
//        AppCenter.start(withAppSecret:"ios={Your iOS App Secret};macos={Your macOS App Secret}", services: [Analytics.self, Crashes.self])
        AppCenter.configure(withAppSecret: secretKey)
        if AppCenter.isConfigured {
            AppCenter.startService(Analytics.self)
            //AppCenter.startService(Crashes.self)
            ILOG("AppCenter initialized.")
        } else {
            ELOG("AppCenter not configured.")
        }
    }
}
#else
extension PVAppDelegate {
    public func _initAppCenter() {
        //DLOG("App center not supported on this platform")
    }
}

#endif
