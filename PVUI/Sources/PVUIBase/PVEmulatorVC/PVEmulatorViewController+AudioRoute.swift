//
//  PVEmulatorViewController+AudioRoute.swift
//  PVUI
//
//  Handles AVAudioSession route-change events so the emulator can
//  auto-pause when AirPods or Bluetooth headphones disconnect.
//

import Foundation
import PVCoreAudio
import PVSettings
import PVLogging
import Defaults

#if !os(macOS)
import AVFoundation

extension PVEmulatorViewController {

    // MARK: - Registration

    /// Call from `initNotificationObservers()` to enable headphone-disconnect auto-pause.
    func registerAudioRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChangeForPause(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    // MARK: - Handler

    @objc func handleAudioRouteChangeForPause(_ notification: Notification) {
        guard Defaults[.pauseOnHeadphonesDisconnect] else { return }

        guard
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else { return }

        guard reason == .oldDeviceUnavailable else { return }

        // Check whether the device that was removed was a headset/headphones/BT audio output.
        guard
            let previousRoute = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription,
            previousRoute.isHeadsetPluggedIn
        else { return }

        ILOG("Headphones/AirPods disconnected — auto-pausing emulation")

        DispatchQueue.main.async { [weak self] in
            guard let self, self.core.isOn, !self.isShowingMenu else { return }
            self.isShowingMenu = true
        }
    }
}
#endif
