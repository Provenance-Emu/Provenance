//
//  PVEmulatorCore+Camera.swift
//  PVSupport-iOS
//
//  Created by Joseph Mattiello on 8/2/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import AVFoundation

#if os(tvOS)
@objc
public extension PVEmulatorCore {
    var cameraIsAvailable: Bool { false }
    func requestCameraAccess() { assertionFailure("tvOS Not Supported") }
    @objc func cameraStart() -> Bool {
        assertionFailure("tvOS Not Supported")
        return false }
    @objc func cameraStop() { assertionFailure("tvOS Not Supported") }
}
#else
public typealias retro_camera_lifetime_status_t = () -> Void
public typealias retro_camera_frame_raw_framebuffer_t = () -> Void
public typealias retro_camera_frame_opengl_texture_t = (_ texture_id : UInt16, _ texture_target : UInt16, _ affine : inout Float) -> Void
public typealias retro_camera_start_t = () -> Bool
public typealias retro_camera_stop_t = () -> Void

fileprivate var g_authorized: Bool = false
fileprivate var g_session: AVCaptureDevice.DiscoverySession? = nil

@objc
public extension PVEmulatorCore {
    var cameraIsAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) && g_authorized }
    
    func requestCameraAccess() {
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
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
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                DLOG("Camera auth: \(authorized)")
                g_authorized = authorized
            }
        @unknown default:
            fatalError()
        }
    }
    
    @nonobjc
    func cameraStart(withDesiredSize size: CGSize? = nil) -> Bool {
        guard cameraIsAvailable else { return false }
//        AVCaptureDeviceDiscoverySession
//        :AVMediaTypeVideo
//        AVCaptureDevice.init(uniqueID: String)
        return false;
    }

    @objc func cameraStart() -> Bool {
        return cameraStart(withDesiredSize: nil)
    }
    
    @objc func cameraStop() {
        
    }
}
#endif
