//
//  PVLibRetro.swift
//
//
//  Created by Joseph Mattiello on 5/23/24.
//

import Foundation
@_exported import libretro
@_exported import PVEmulatorCore
@_exported import PVCoreBridge

@objc
@objcMembers
open class PVLibRetroCoreBridge : PVEmulatorCore, @unchecked Sendable {
    
    // Public properties
    @objc open  var pitch_shift: UInt16 = 0
    
//    @objc open  var videoBuffer: UnsafeMutableRawPointer?
    @objc open  var videoBufferA: UnsafeMutablePointer<UInt32>?
    @objc open  var videoBufferB: UnsafeMutablePointer<UInt32>?
    
    @objc open  var pad: [[Int16]] = Array(repeating: Array(repeating: 0, count: 12), count: 2)
    
    @objc public  var core: UnsafeMutablePointer<retro_core_t>?

    // MARK: - Retro Structs
    @objc open  var core_poll_type: UInt32 = 0
    @objc open  var core_input_polled: Bool = false
    @objc open  var core_has_set_input_descriptors: Bool = false
    @objc open  var av_info = retro_system_av_info()
    @objc open  var pix_fmt: retro_pixel_format = RETRO_PIXEL_FORMAT_UNKNOWN
    
    
    @objc open override var pixelType: GLenum { return GLenum(GL_UNSIGNED_SHORT) }
    @objc open override var channelCount: UInt { return 2 }

    // MARK: - Audio
    @objc open var audioSampleRate: Double {
        var avInfo: retro_system_av_info = .init()
        core?.pointee.retro_get_system_av_info(&avInfo)
        let sample_rate = av_info.timing.sample_rate
        return sample_rate > 0 ? sample_rate : 44100
    }
    
}
