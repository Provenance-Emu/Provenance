//
//  AchievementSoundPlayer.swift
//  PVUIBase
//
//  Plays a short SFX when an achievement is unlocked.
//

import Foundation
import AudioToolbox
import PVLogging

/// Plays the achievement-unlock sound effect.
///
/// MVP uses a built-in iOS/tvOS system sound so no binary asset has to ship.
/// When a bundled `.caf` is added later, load it via
/// `AudioServicesCreateSystemSoundID(url, &id)` and replace `systemSoundID`.
public enum AchievementSoundPlayer {

    /// iOS "Tweet sent" positive chime (short, reliable across iOS/tvOS).
    /// See https://github.com/TUNER88/iOSSystemSoundsLibrary for the catalog.
    private static let systemSoundID: SystemSoundID = 1016

    /// Play the unlock SFX. Safe to call from any thread — AudioServices is
    /// implicitly asynchronous and dispatches to its own audio thread.
    public static func playUnlock() {
        AudioServicesPlaySystemSound(systemSoundID)
    }

    /// Play a distinct "leaderboard / milestone" SFX.
    /// Currently aliases the unlock sound; swap to a different system sound
    /// or bundled asset if a separate cue is desired.
    public static func playMilestone() {
        AudioServicesPlaySystemSound(systemSoundID)
    }
}
