//
//  SettingsValueFormatting.swift
//  PVUI
//
//  Pure value rules for Settings rows (ranges, presets, captions), kept out of the views so they are unit-testable.
//

import Foundation

/// The timed auto-save interval (`Defaults[.timedAutoSaveInterval]`, stored in seconds).
enum AutoSaveIntervalRules {
    static let secondsPerMinute: TimeInterval = 60
    /// Slider bounds and step on iOS.
    static let minimum: TimeInterval = 1 * secondsPerMinute
    static let maximum: TimeInterval = 30 * secondsPerMinute
    static let step: TimeInterval = 1 * secondsPerMinute

    /// Choices offered on tvOS, which has no slider.
    static let presets: [TimeInterval] = [1, 2, 5, 10, 15, 20, 30].map { $0 * secondsPerMinute }

    /// The tvOS choices, plus `current` when it is not one of them (e.g. set with the iOS slider and synced),
    /// so the stored value is always shown as selected.
    static func choices(including current: TimeInterval) -> [TimeInterval] {
        guard !presets.contains(current) else { return presets }
        return (presets + [current]).sorted()
    }

    /// "1 minute", "5 minutes", "2.5 minutes".
    static func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = seconds / secondsPerMinute
        let rounded = minutes.rounded()
        if abs(minutes - rounded) < 0.05 {
            let whole = Int(rounded)
            return whole == 1 ? "1 minute" : "\(whole) minutes"
        }
        return String(format: "%.1f minutes", minutes)
    }

    /// Caption under the interval control.
    static func caption(_ seconds: TimeInterval) -> String {
        "A save state is made every \(durationLabel(seconds)) while you play."
    }
}

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
