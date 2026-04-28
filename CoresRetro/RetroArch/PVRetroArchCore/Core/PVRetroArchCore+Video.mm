//
//  PVRetroArch+Video.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCoreBridge+Video.h"
@import PVCoreBridge;
@import PVCoreAudio;
@import PVAudio;
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/ES3/gl.h>
#import <GLKit/GLKit.h>

// `gfx/video_driver.h` resolves via the `$(SRCROOT)/RetroArch` header search
// path; matches the pattern used by `PVRetroArchCore+RetroArchUI.m` etc.
#include "../../gfx/video_driver.h"

/// Minimum sane game-pixel dimension for any retro-core base resolution.
/// All retro cores expose at least 32px on both axes; anything below this is
/// treated as "geometry not yet reported".
static const unsigned int kPVRAMinReportedDim = 32;
/// Retro cores top out around ~1024×768 for HD-era systems (Saturn HD = 704,
/// PSP = 480, N64/PS1 = 640). Anything ≥1200 on either axis is the device
/// screen leaking through, not real game geometry.
static const unsigned int kPVRAMaxReportedDim = 1200;

@implementation PVRetroArchCoreBridge (Video)

# pragma mark - Methods
- (void)videoInterrupt {}
- (void)swapBuffers {
    [self.renderDelegate didRenderFrameOnAlternateThread];
}
- (void)executeFrame {}

# pragma mark - Properties
- (CGSize)bufferSize {
	return CGSizeMake(0,0);
}
- (CGRect)screenRect {
	return CGRectMake(0, 0, self.videoWidth, self.videoHeight);
}

/// Returns the real game aspect once the libretro core has reported geometry
/// via `SET_SYSTEM_AV_INFO` / `SET_GEOMETRY`, otherwise falls back to the
/// `videoWidth`/`videoHeight` initialised from `UIScreen.bounds` (used by
/// the loading HUD before the first frame arrives).
- (CGSize)aspectSize {
    video_driver_state_t *video_st = video_state_get_ptr();
    if (video_st) {
        const struct retro_game_geometry *geom = &video_st->av_info.geometry;
        unsigned int baseW = geom->base_width;
        unsigned int baseH = geom->base_height;
        if (baseW >= kPVRAMinReportedDim && baseH >= kPVRAMinReportedDim &&
            baseW <= kPVRAMaxReportedDim && baseH <= kPVRAMaxReportedDim) {
            // Latch the flag so consumers (default skin layout) know to
            // trust this value rather than treating it as a screen-bounds
            // fallback.
            if (!_hasReceivedAspectFromCore) {
                _hasReceivedAspectFromCore = YES;
            }
            return CGSizeMake((CGFloat)baseW, (CGFloat)baseH);
        }
    }
    // Loading-HUD fallback: keep the existing screen-bounds value so the
    // bridge has a non-zero aspect to report before retro_load_game runs.
    return CGSizeMake(self.videoWidth, self.videoHeight);
}

- (BOOL)hasReceivedAspectFromCore {
    return _hasReceivedAspectFromCore;
}

- (BOOL)rendersToOpenGL {
	return YES;
}

- (BOOL)isDoubleBuffered {
	return YES;
}

- (const void *)videoBuffer {
	return NULL;
}

- (GLenum)pixelFormat {
	return GL_RGBA;
}

- (GLenum)pixelType {
	return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat {
	return GL_RGBA;
}
@end
