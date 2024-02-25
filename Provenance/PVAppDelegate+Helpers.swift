//
//  PVAppDelegate+Helpers.swift
//  Provenance
//
//  Created by Joseph Mattiello on 11/12/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import PVSupport
import PVLogging

// MARK: - Helpers
extension PVAppDelegate {

        // Start optional always on WebDav server using enviroment variable
        // See XCode run scheme enviroment varialbes settings. 
    func isWebDavServerEnvironmentVariableSet() -> Bool {
        // Note: ENV variables are only passed when when from XCode scheme.
        // Users clicking the app icon won't be passed this variable when run outside of XCode
        let buildConfiguration = ProcessInfo.processInfo.environment["ALWAYS_ON_WEBDAV"]
        return buildConfiguration == "1"
    }

    func startOptionalWebDavServer() {
        // Check if the user setting is set or the optional ENV variable
        if PVSettingsModel.shared.webDavAlwaysOn || isWebDavServerEnvironmentVariableSet() {
            PVWebServer.shared.startWebDavServer()
        }
    }

    func _initLogging() {
        // Initialize logging
        PVLogging.shared

//        fileLogger.maximumFileSize = (1024 * 64) // 64 KByte
//        fileLogger.logFileManager.maximumNumberOfLogFiles = 1
//        fileLogger.rollLogFile(withCompletion: nil)
//        DDLog.add(fileLogger)

        #if os(iOS)
            // Debug view logger
//            DDLog.add(PVUIForLumberJack.sharedInstance(), with: .info)
//            window?.addLogViewerGesture()
        #endif

//        DDOSLogger.sharedInstance.logFormatter = PVTTYFormatter()
    }

    func setDefaultsFromSettingsBundle() {
        // Read PreferenceSpecifiers from Root.plist in Settings.Bundle
        if let settingsURL = Bundle.main.url(forResource: "Root", withExtension: "plist", subdirectory: "Settings.bundle"),
            let settingsPlist = NSDictionary(contentsOf: settingsURL),
            let preferences = settingsPlist["PreferenceSpecifiers"] as? [NSDictionary] {
            for prefSpecification in preferences {
                if let key = prefSpecification["Key"] as? String, let value = prefSpecification["DefaultValue"] {
                    // If key doesn't exists in userDefaults then register it, else keep original value
                    if UserDefaults.standard.value(forKey: key) == nil {
                        UserDefaults.standard.set(value, forKey: key)
                        ILOG("registerDefaultsFromSettingsBundle: Set following to UserDefaults - (key: \(key), value: \(value), type: \(type(of: value)))")
                    }
                }
            }
        } else {
            ELOG("registerDefaultsFromSettingsBundle: Could not find Settings.bundle")
        }
    }
   
}
