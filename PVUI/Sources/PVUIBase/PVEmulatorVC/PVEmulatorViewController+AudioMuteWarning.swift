//
//  PVEmulatorViewController+AudioMuteWarning.swift
//  PVUIBase
//
//  Shows a one-time toast warning when the user starts a game with
//  device volume at zero or silent mode potentially active.
//  Helps users who think sound is broken when it is actually their
//  iOS silent-mode switch or volume setting.
//

// Exclude Mac Catalyst: the silent-switch and volume-button copy is iOS/iPadOS-only.
#if os(iOS) && !targetEnvironment(macCatalyst)
import AVFoundation
import Defaults
import Foundation
import PVCoreAudio
import PVLogging
import PVSettings

// MARK: - Audio mute/volume warning at game start

extension PVEmulatorViewController {

    /// Tracks whether the audio-mute warning has already been shown this app session.
    private static var hasShownAudioMuteWarning = false

    /// Call shortly after emulation starts to warn if the device audio
    /// is muted or volume is at zero. Only fires once per app session.
    func checkAudioMuteWarningAfterDelay() {
        // Delay so the game has time to load and the user sees the emulator first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, !Self.hasShownAudioMuteWarning else { return }
            self.showAudioMuteWarningIfNeeded()
        }
    }

    // MARK: - Private

    private func showAudioMuteWarningIfNeeded() {
        guard !Self.hasShownAudioMuteWarning else { return }

        let session = AVAudioSession.sharedInstance()
        let volume = session.outputVolume

        if volume <= 0.01 {
            // Volume is essentially zero
            Self.hasShownAudioMuteWarning = true
            ILOG("Device volume is zero — showing audio mute toast")
            PVToastManager.post(
                "Volume is at zero \u{2014} use the volume buttons to hear game audio",
                type: .warning,
                duration: 5.0,
                icon: "speaker.slash.fill"
            )
            return
        }

        // Check if Respect Silent Mode is enabled — if so, the mute switch
        // could be silencing audio without the user realizing.
        // Use AVAudioSession.isSilentModeEnabled (from PVCoreAudio) which
        // combines the built-in speaker route check with
        // secondaryAudioShouldBeSilencedHint for a reliable signal.
        if Defaults[.respectMuteSwitch] {
            let outputs = session.currentRoute.outputs
            // Guard against an empty outputs list (allSatisfy returns true on empty).
            let isBuiltInSpeakerOnly = !outputs.isEmpty &&
                outputs.allSatisfy { $0.portType == .builtInSpeaker }

            if isBuiltInSpeakerOnly && session.isSilentModeEnabled {
                Self.hasShownAudioMuteWarning = true
                ILOG("Silent mode detected with built-in speaker — showing silent mode toast")
                PVToastManager.post(
                    "If audio is muted, turn off Silent Mode or disable \u{201C}Respect Silent Mode\u{201D} in Settings \u{2192} Audio",
                    type: .warning,
                    duration: 6.0,
                    icon: "bell.slash.fill"
                )
            }
        }
    }
}
#endif
