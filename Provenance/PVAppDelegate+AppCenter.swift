//
//  PVAppDelegate+AppCenter.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/2/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport

#if canImport(AppCenter) && canImport(AppCenterAnalytics)
@_exported import AppCenter
@_exported import AppCenterAnalytics
@_exported import AppCenterCrashes

extension PVAppDelegate {
    public func _initAppCenter() {
        guard let secretKey = Bundle.main.object(forInfoDictionaryKey: "appcenter") as? String else {
            ELOG("No value for Info.plist key 'appcenter'")
            return
        }
        // TODO: This isn't linking in tvOS, but only when building the app. Building PVApp.framework for tvOS links fine.
        // probaby some stupid objc / swiftpm bug.
        #if !os(tvOS)
        //        AppCenter.start(withAppSecret:"ios={Your iOS App Secret};macos={Your macOS App Secret}", services: [Analytics.self, Crashes.self])
        AppCenter.configure(withAppSecret: secretKey)
        if AppCenter.isConfigured {
            AppCenter.startService(Analytics.self)
            AppCenter.startService(Crashes.self)
            ILOG("AppCenter initilized.")
        } else {
            ELOG("AppCenter not configured.")
        }
        #endif
    }
}
#else
extension PVAppDelegate {
    public func _initAppCenter() {
        DLOG("App center not supported on this platform")
    }
}

#endif
