//
//  AutoSaveIntervalRules.swift
//  PVSettings
//
//  Range, presets and wording for `Defaults[.timedAutoSaveInterval]`, shared by Settings and the pause menu.
//

import Foundation

/// The timed auto-save interval (`Defaults[.timedAutoSaveInterval]`, stored in seconds).
public enum AutoSaveIntervalRules {
    public static let secondsPerMinute: TimeInterval = 60
    /// Slider bounds and step in Settings on iOS.
    public static let minimum: TimeInterval = 1 * secondsPerMinute
    public static let maximum: TimeInterval = 30 * secondsPerMinute
    public static let step: TimeInterval = 1 * secondsPerMinute

    /// Choices offered where there is no slider: Settings on tvOS and the pause-menu Timed Auto Save tile.
    public static let presets: [TimeInterval] = [1, 2, 5, 10, 15, 20, 30].map { $0 * secondsPerMinute }

    /// The presets, plus `current` when it is not one of them (e.g. set with the iOS slider and synced),
    /// so the stored value is always shown as selected.
    public static func choices(including current: TimeInterval) -> [TimeInterval] {
        guard !presets.contains(current) else { return presets }
        return (presets + [current]).sorted()
    }

    /// "1 minute", "5 minutes", "2.5 minutes".
    public static func durationLabel(_ seconds: TimeInterval) -> String {
        let minutes = seconds / secondsPerMinute
        let rounded = minutes.rounded()
        if abs(minutes - rounded) < 0.05 {
            let whole = Int(rounded)
            return whole == 1 ? "1 minute" : "\(whole) minutes"
        }
        return String(format: "%.1f minutes", minutes)
    }

    /// Caption under the interval control.
    public static func caption(_ seconds: TimeInterval) -> String {
        "A save state is made every \(durationLabel(seconds)) while you play."
    }
}
