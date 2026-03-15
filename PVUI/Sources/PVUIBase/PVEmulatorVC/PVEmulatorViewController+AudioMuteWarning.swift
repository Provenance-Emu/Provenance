//
//  PVEmulatorViewController+AudioMuteWarning.swift
//  PVUIBase
//
//  Shows a one-time toast warning when the user starts a game with
//  device volume at zero or silent mode potentially active.
//  Helps users who think sound is broken when it is actually their
//  iOS silent-mode switch or volume setting.
//

#if os(iOS)
import AVFoundation
import Defaults
import Foundation
import PVLogging
import PVSettings

// MARK: - Audio mute/volume warning at game start

extension PVEmulatorViewController {

    /// Tracks whether the audio-mute warning has already been shown this app session.
    private static var hasShownAudioMuteWarning = false

    /// Call shortly after emulation starts to warn if the device audio
    /// is muted or volume is at zero. Only fires once per app session.
    func checkAudioMuteWarningAfterDelay() {
        guard !Self.hasShownAudioMuteWarning else { return }

        // Delay so the game has time to load and the user sees the emulator first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showAudioMuteWarningIfNeeded()
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
        if Defaults[.respectMuteSwitch] {
            // When the audio session category respects the mute switch and
            // the current route is only the built-in speaker, the mute switch
            // may be silencing output. We cannot directly read the switch state,
            // but we can hint users who have this setting enabled.
            let outputs = session.currentRoute.outputs
            let isBuiltInSpeakerOnly = outputs.allSatisfy { $0.portType == .builtInSpeaker }

            if isBuiltInSpeakerOnly {
                Self.hasShownAudioMuteWarning = true
                ILOG("Respect Silent Mode is on and using built-in speaker — showing silent mode toast")
                PVToastManager.post(
                    "If audio is muted, flip the silent switch or disable \u{201C}Respect Silent Mode\u{201D} in Settings \u{2192} Audio",
                    type: .warning,
                    duration: 6.0,
                    icon: "bell.slash.fill"
                )
            }
        }
    }
}
#endif
