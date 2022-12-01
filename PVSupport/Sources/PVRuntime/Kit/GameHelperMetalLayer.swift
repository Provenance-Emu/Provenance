// Copyright (c) 2021, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import QuartzCore

@objc(OEGameHelperMetalLayer)
class GameHelperMetalLayer: CAMetalLayer {
    override init() {
        super.init()
        
        anchorPoint     = .zero
        contentsGravity = .resizeAspect
        
        // TODO: this should come from the host
        contentsScale   = 2.0
        pixelFormat     = pixelFormat
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // TODO: Set this to match the final pixel format of FilterChain whenever the shader changes.
    
    override var pixelFormat: MTLPixelFormat {
        didSet {
            switch pixelFormat {
            case .bgra8Unorm_srgb, .bgra8Unorm:
                // Note: all 8bit images are sRGB. It's mathematically incorrect to use a non-sRGB pixel format
                // but most filters do it anyway and the different bugs cancel each other out.
                
                // TODO: Use the sRGB pixel format when not using shaders.
                
                // TODO: Since our images are mostly the "old TV" colorspace (NTSC 1953), try
                // using that (with a per-core setting). The color hue will be a little different.
                // Currently we use ITUR_709 (HDTV) which is close to sRGB but adapted to a dark room.
                let colorSpace = CGColorSpace(name: CGColorSpace.itur_709)
                colorspace = colorSpace
                if #available(macOS 10.11, iOS 16, *) {
                    wantsExtendedDynamicRangeContent = false
                }
            case .rgba16Float:
                // For a filter that wants to output HDR, or at least linear gamma.
                // This "should" use the colorspace above but linear. This is close enough.
                let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
                colorspace = colorSpace
                if #available(macOS 10.11, iOS 16, *) {
                    wantsExtendedDynamicRangeContent = true
                }
            default:
                break
            }
        }
    }
    
    override var bounds: CGRect {
        didSet {
            let size = bounds.size.applying(CGAffineTransform(scaleX: contentsScale, y: contentsScale))
            drawableSize = size
        }
    }
}
