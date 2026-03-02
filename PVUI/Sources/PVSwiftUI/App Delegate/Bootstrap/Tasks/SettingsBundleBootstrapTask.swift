//
//  SettingsBundleBootstrapTask.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2026-03-02.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

import Foundation
import PVLogging

/// Registers default values from `Settings.bundle/Root.plist` into
/// `UserDefaults.standard` for any key that has not yet been set.
///
/// No dependencies. Provides `BootstrapKey.settings`.
struct SettingsBundleBootstrapTask: BootstrapTask {
    var name: String { "SettingsBundle" }
    var dependencies: [String] { [] }
    var provisions: [String] { [BootstrapKey.settings] }

    func execute() async throws {
        guard
            let settingsURL = Bundle.main.url(
                forResource: "Root", withExtension: "plist", subdirectory: "Settings.bundle"),
            let settingsPlist = NSDictionary(contentsOf: settingsURL),
            let preferences = settingsPlist["PreferenceSpecifiers"] as? [NSDictionary]
        else {
            ELOG("SettingsBundleBootstrapTask: Could not find Settings.bundle/Root.plist")
            return
        }

        for prefSpecification in preferences {
            if let key = prefSpecification["Key"] as? String,
               let value = prefSpecification["DefaultValue"],
               UserDefaults.standard.value(forKey: key) == nil {
                UserDefaults.standard.set(value, forKey: key)
                ILOG("SettingsBundleBootstrapTask: Registered default — key: \(key), value: \(value)")
            }
        }
    }
}
