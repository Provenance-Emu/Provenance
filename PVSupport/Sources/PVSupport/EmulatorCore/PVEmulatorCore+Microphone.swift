//
//  PVEmulatorCore+Microphone.swift
//  PVSupport
//
//  Created by Joseph Mattiello on 8/2/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import AVFoundation

private var g_authorized: Bool = false

@objc
public extension PVEmulatorCore {
    #if os(iOS)
    var microphoneIsAvailable: Bool { return true }
    #else
    var microphoneIsAvailable: Bool { return false }
    #endif

    func requestMicrophoneAccess() {
#if os(iOS)
        let authStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        switch authStatus {
        case .authorized:
            g_authorized = true
            return
        case .denied:
            g_authorized = false
            return
        case .restricted:
            g_authorized = true
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { authorized in
                DLOG("Microphone auth: \(authorized)")
                g_authorized = authorized
            }
        @unknown default:
            fatalError()
        }
#else
        assertionFailure("Shouldn't be here on this platform")
#endif
    }
}
