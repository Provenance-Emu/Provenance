//
//  SettingsValueFormatting.swift
//  PVUI
//
//  Pure value rules for Settings rows, kept out of the views so they are unit-testable.
//  Rules the pause menu shares (e.g. `AutoSaveIntervalRules`) live in PVSettings.
//

import Foundation

/// The version shown in Settings › About and the side menu header.
enum AppVersionLabel {
    /// "3.4.0 (4521)"; the build number is left off when missing.
    static func text(shortVersion: String?, build: String?) -> String {
        guard let shortVersion, !shortVersion.isEmpty else { return "Unknown" }
        guard let build, !build.isEmpty else { return shortVersion }
        return "\(shortVersion) (\(build))"
    }

    /// The running app's version.
    static var current: String {
        let info = Bundle.main.infoDictionary
        return text(shortVersion: info?["CFBundleShortVersionString"] as? String,
                    build: info?["CFBundleVersion"] as? String)
    }
}
