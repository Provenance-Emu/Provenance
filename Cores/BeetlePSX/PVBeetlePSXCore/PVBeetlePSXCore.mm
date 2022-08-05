//
//  PVBeetlePSXCore.m
//  PVBeetlePSX
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVBeetlePSXCore.h"
#include <stdatomic.h>
//#import "PVBeetlePSXCore+Controls.h"
//#import "PVBeetlePSXCore+Audio.h"
//#import "PVBeetlePSXCore+Video.h"
//
//#import "PVBeetlePSXCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVBeetlePSXCore() {

}

@end

#pragma mark - PVBeetlePSXCore Begin

@implementation PVBeetlePSXCore
{
}

- (instancetype)init {
	if (self = [super init]) {
	}

	_current = self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore
//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
//	NSBundle *coreBundle = [NSBundle bundleForClass:[self class]];
//	const char *dataPath;
//
//    [self initControllBuffers];
//
//	// TODO: Proper path
//	NSString *configPath = self.saveStatesPath;
//	dataPath = [[coreBundle resourcePath] fileSystemRepresentation];
//
//	[[NSFileManager defaultManager] createDirectoryAtPath:configPath
//                              withIntermediateDirectories:YES
//                                               attributes:nil
//                                                    error:nil];
//
//	NSString *batterySavesDirectory = self.batterySavesPath;
//	[[NSFileManager defaultManager] createDirectoryAtPath:batterySavesDirectory
//                              withIntermediateDirectories:YES
//                                               attributes:nil
//                                                    error:NULL];
//
//    return YES;
//}

#pragma mark - Running
//- (void)startEmulation {
//	if (!_isInitialized)
//	{
//		[self.renderDelegate willRenderFrameOnAlternateThread];
//        _isInitialized = true;
//		_frameInterval = dol_host->GetFrameInterval();
//	}
//	[super startEmulation];
//
	//Disable the OE framelimiting
//	[self.renderDelegate suspendFPSLimiting];
//	if(!self.isRunning) {
//		[super startEmulation];
////        [NSThread detachNewThreadSelector:@selector(runReicastRenderThread) toTarget:self withObject:nil];
//	}
//}

//- (void)setPauseEmulation:(BOOL)flag {
//	[super setPauseEmulation:flag];
//}
//
//- (void)stopEmulation {
//	_isInitialized = false;
//
//	self->shouldStop = YES;
////	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
////    dispatch_semaphore_wait(coreWaitForExitSemaphore, DISPATCH_TIME_FOREVER);
//	[self.frontBufferCondition lock];
//	[self.frontBufferCondition signal];
//	[self.frontBufferCondition unlock];
//
//	[super stopEmulation];
//}
//
//- (void)resetEmulation {
//	//	dispatch_semaphore_signal(mupenWaitToBeginFrameSemaphore);
//	[self.frontBufferCondition lock];
//	[self.frontBufferCondition signal];
//	[self.frontBufferCondition unlock];
//}

//# pragma mark - Cheats
//- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
//}
//

- (BOOL)supportsSaveStates { return NO; }
- (BOOL)supportsRumble { return YES; }
- (BOOL)supportsCheatCode { return YES; }

//- (NSTimeInterval)frameInterval {
//    return 60;
//}
//
//- (CGSize)aspectSize {
//    return CGSizeMake(10, 7);
//}
//
//- (CGSize)bufferSize {
//    return CGSizeMake(1024, 1024);
//}
//
//- (GLenum)pixelFormat {
//    return GL_RGBA;
//}
//
//- (GLenum)pixelType {
//    return GL_UNSIGNED_BYTE;
//}
//
//- (GLenum)internalPixelFormat {
//    return GL_RGBA;
//}

//- (BOOL)isDoubleBuffered {
//    return YES;
//}
//
//- (void)swapBuffers
//{
//    Mednafen::MDFN_Surface *tempSurf = backBufferSurf;
//    backBufferSurf = frontBufferSurf;
//    frontBufferSurf = tempSurf;
//}


# pragma mark - Audio

- (double)audioSampleRate {
    return 44100;
}

#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);

#ifdef HAVE_HW
#define BEETLE_OPT beetle_psx_hw_
#else
#define BEETLE_OPT beetle_psx_
#endif
#define STRINGIFY(s)         TOSTRING(s)
#define TOSTRING(s) #s

#define GLUE(a, b) a ## b
#define JOIN(a, b) GLUE(a, b)
    
#define V(x) strcmp(variable, STRINGIFY(JOIN(BEETLE_OPT, x))) == 0
    if (V(renderer)) {
        // hardware, hardware_gl, hardware_vk, software
        char *value = strdup("hardware");
        return value;
    } else if (V(renderer_software_fb)) {
        /*
         "Enable accurate emulation of framebuffer effects (e.g. motion blur, FF7 battle swirl) when using hardware renderers by running a copy of the software renderer at native resolution in the background. If disabled, these operations are omitted (OpenGL) or rendered on the GPU (Vulkan). Disabling can improve performance but may cause severe graphical errors. Leave enabled if unsure.",
         enabled / disabled
         */
        char *value = strdup("enabled");
        return value;
#if defined(HAVE_LIGHTREC)
    else if (V(cpu_dynarec)) {
            /*
             Dynamically recompile CPU instructions to native instructions. Much faster than interpreter, but CPU timing is less accurate, and may have bugs.
             { "disabled", "Disabled (Beetle Interpreter)" },
             { "execute",  "Max Performance" },
             { "execute_one",  "Cycle Timing Check" },
             { "run_interpreter", "Lightrec Interpreter" },
             */
            char *value = strdup("execute");
            return value;
#endif
    } else if (V(cd_access_method)) {
        /*
         Choose method used to read data from content disk images. 'Synchronous' mimics original hardware. 'Asynchronous' can reduce stuttering on devices with slow storage. 'Pre-Cache' loads the entire disk image into memory when launching content, which may improve in-game loading times at the cost of an initial delay at startup. 'Pre-Cache' may cause issues on systems with low RAM, and will fall back to 'Synchronous' for physical media.
         */
        char *value = strdup("async");
        return value;
    } else if (V(cpu_freq_scale)) {
        /*
         Overclock (or underclock) the emulated PSX CPU. Overclocking can eliminate slowdown and improve frame rates in certain games at the expense of increased performance requirements. Note that some games have an internal frame rate limiter and may not benefit from overclocking. May cause certain effects to animate faster than intended in some titles when overclocked.
         50% -> 750%
         */
        char *value = strdup("100%(native)");
        return value;
    } else if (V(gte_overclock)) {
        /*
         Lower all emulated GTE (CPU coprocessor for 3D graphics) operations to a constant one-cycle latency. For games that make heavy use of the GTE, this can greatly improve frame rate and frame time stability.
         */
        char *value = strdup("disabled");
        return value;
    } else if (V(gpu_overclock)) {
        /*
         "GPU Rasterizer Overclock",
         NULL,
         "Enable overclocking of the 2D rasterizer contained within the emulated PSX's GPU. Does not improve 3D rendering, and in general has little effect.",
         NULL,
         "video",
         {
            { "1x(native)", "1x (Native)" },
            { "2x",         NULL },
            { "4x",         NULL },
            { "8x",         NULL },
            { "16x",        NULL },
            { "32x",        NULL },
            { NULL, NULL },
         */
        char *value = strdup("1x(native)");
        return value;
    } else if (V(skip_bios)) {
        /*
         Skip the PlayStation BIOS boot animation normally displayed when loading content. Note: Enabling this causes compatibility issues with a number of games (PAL copy protected games, Saga Frontier, etc.).
         */
        char *value = strdup("enabled");
        return value;
    } else if (V(override_bios)) {
        /*
         Override BIOS (Restart Required)
         Override the standard region specific BIOS with a region-free one if found.
         { "disabled", NULL },
         { "psxonpsp",  "PSP PS1 BIOS" },
         { "ps1_rom",  "PS3 PS1 BIOS" },
         */
        char *value = strdup("psxonpsp");
        return value;
    } else if (V(widescreen_hack)) {
        /*
         Render 3D content anamorphically and output the emulated framebuffer at a widescreen aspect ratio. Produces best results with fully 3D games. 2D elements will be horizontally stretched and may be misaligned.
         */
        char *value = strdup("enabled");
        return value;
    } else if (V(widescreen_hack_aspect_ratio)) {
        /*
         Choose the aspect ratio to be used by the Widescreen Mode Hack.
         { "16:9",  NULL },
         { "16:10", NULL },
         { "18:9",  NULL },
         { "19:9",  NULL },
         { "20:9",  NULL },
         { "21:9",  NULL }, // 64:27
         { "32:9",  NULL },
         */
        char *value = strdup("16:10");
        return value;
    } else if (V(pal_video_timing_override)) {
        /*
         Due to different standards, PAL games often appear slowed down compared to the American or Japanese NTSC releases. This option can be used to override PAL timings in order to attempt to run these games with the NTSC framerate. This option has no effect when running NTSC content.
         */
        char *value = strdup("disabled");
        return value;
    } else if (V(analog_calibration)) {
        /*
         When the input device is set to DualShock, Analog Controller, Analog Joystick, or neGcon, this option enables dynamic calibration of analog inputs. Maximum registered input values are monitored in real time and used to scale analog coordinates passed to the emulator. This should be used for games such as Mega Man Legends 2 that expect larger values than what modern controllers provide. For best results, analog sticks should be rotated at full extent to tune the calibration algorithm each time content is loaded.
         */
        char *value = strdup("disabled");
        return value;
    } else if (V(core_timing_fps)) {
        /*
         Choose the FPS timing that the core will report to the frontend. Automatic Toggling will allow the core to switch between reporting progressive and interlaced rates, but may cause frontend video/audio driver re-inits.
         */
        char *value = strdup("auto_toggle");
        return value;
    } else if (V(aspect_ratio)) {
        /*
         Core Aspect Ratio
         Choose core provided aspect ratio. This setting is ignored when the Widescreen Mode Hack or Display Full VRAM options are enabled.
         { "corrected", "Corrected" },
         { "uncorrected", "Uncorrected" },
         { "4:3",  "Force 4:3" },
         { "ntsc", "Force NTSC" },
         */
        char *value = strdup("corrected");
        return value;
    } else if (V(internal_resolution)) {
        /*
         Choose internal resolution multiplier. Resolutions higher than '1x (Native)' improve fidelity of 3D models at the expense of increased performance requirements. 2D elements are generally unaffected by this setting.
         { "1x(native)", "1x (Native)" },
         { "2x",         NULL },
         { "4x",         NULL },
         { "8x",         NULL },
         { "16x",        NULL },
         */
        char *value = strdup("4x");
        return value;
    } else if (V(dither_mode)) {
        /*
         Choose dithering pattern configuration. '1x (Native)' emulates native low resolution dithering used by original hardware to smooth out color banding artifacts visible at native color depth. 'Internal Resolution' scales dithering granularity to the configured internal resolution for cleaner results. Recommended to be disabled when running at 32 bpp color depth. Note: On Vulkan, enabling this will force downsampling to native color depth, while disabling will automatically enable output at higher color depth.
         */
        char *value = strdup("disabled");
        return value;
    } else if (V(depth)) {
        /*
         Choose internal color depth. Higher color depth can reduce color banding effects without the use of dithering. 16 bpp emulates original hardware but may have visible banding if dithering is not enabled. 'Dithering Pattern' is recommended to be disabled when this option is set to 32 bpp.
         */
        char *value = strdup("32bpp");
        return value;
    } else if (V(pgxp_mode)) {
        /*
         Allows 3D objects to be rendered with subpixel precision, minimizing distortion and jitter of 3D objects seen on original hardware due to the usage of fixed point vertex coordinates. 'Memory Only' mode has minimal compatibility issues and is recommended for general use. 'Memory + CPU (Buggy)' mode can reduce jitter even further but has high performance requirements and may cause various geometry errors.
         */
        char *value = strdup("memory only");
        return value;
    } else if (V(pgxp_2d_tol)) {
        /*
         Hide more glaring errors in PGXP operations: the value specifies the tolerance in which PGXP values will be kept in case of geometries without proper depth information.
         { "disabled", NULL },
         { "0px", NULL },
         { "1px", NULL },
         { "2px", NULL },
         { "3px", NULL },
         { "4px", NULL },
         { "5px", NULL },
         { "6px", NULL },
         { "7px", NULL },
         { "8px", NULL },
         */
        char *value = strdup("disabled");
        return value;
    } else if (V(pgxp_vertex)) {
        /*
         Cache PGXP-enhanced vertex positions for re-use across polygon draws. Can potentially improve object alignment and reduce visible seams when rendering textures, but false positives when querying the cache may produce graphical glitches. It is currently recommended to leave this option disabled. This option is applied only when PGXP Operation Mode is enabled. Only supported by the hardware renderers.
         */
        char *value = strdup("disabled");
        return value;
    } else if (V(pgxp_texture)) {
        /*
         Replace native PSX affine texture mapping with perspective correct texture mapping. Eliminates position-dependent distortion and warping of textures, resulting in properly aligned textures. This option is applied only when PGXP Operation Mode is enabled. Only supported by the hardware renderers.
         */
        char *value = strdup("enabled");
        return value;
    } else if (V(pgxp_nclip)) {
        char *value = strdup("us");
        return value;
    } else if (V(line_render)) {
        /*
         Line-to-Quad Hack
         Choose line-to-quad hack method. Some games (e.g. Doom, Hexen, Soul Blade, etc.) draw horizontal lines by stretching single-pixel-high triangles across the screen, which are rasterized as a row of pixels on original hardware. This hack detects these small triangles and converts them to quads as required, allowing them to be displayed properly on the hardware renderers and at upscaled internal resolutions. 'Aggressive' is required for some titles (e.g. Dark Forces, Duke Nukem) but may otherwise introduce graphical glitches. Leave at 'Default' if unsure."
         { "default",    "Default" },
         { "aggressive", "Aggressive" },
         { "disabled",   NULL },
         */
        char *value = strdup("default");
        return value;
    } else if (V(filter)) {
        /*
         Choose texture filtering method. 'Nearest' emulates original hardware. 'Bilinear' and '3-Point' are smoothing filters, which reduce pixelation via blurring. 'SABR', 'xBR', and 'JINC2' are upscaling filters that may improve texture fidelity/sharpness at the expense of increased performance requirements. Only supported by the hardware renderers.
         { "nearest",  "Nearest" },
         { "SABR",     NULL },
         { "xBR",      NULL },
         { "bilinear", "Bilinear" },
         { "3-point",  "3-Point" },
         { "JINC2",    NULL },
         */
        char *value = strdup("SABR");
        return value;
    } else if (V(analog_toggle)) {
        /*
         When the input device type is DualShock, this option allows the emulated DualShock to be toggled between DIGITAL and ANALOG mode like original hardware. When disabled, the DualShock is locked to ANALOG mode and when enabled, the DualShock can be toggled between DIGITAL and ANALOG mode by pressing and holding START+SELECT+L1+L2+R1+R2
         */
        char *value = strdup("disabled");
        return value;
    } else if (V(enable_multitap_port1)) {
        /*
         Enable multitap functionality on port 1.
         */
        char *value = strdup("disabled");
        return value;
    } else if (V(enable_multitap_port2)) {
        /*
         Enable multitap functionality on port 2.
         */
        char *value = strdup("disabled");
        return value;
//    } else if (V(mouse_sensitivity)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(gun_cursor)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(gun_input_mode)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(negcon_deadzone)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(negcon_response)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(initial_scanline)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(last_scanline)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(initial_scanline_pal)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(last_scanline_pal)) {
//        char *value = strdup("us");
//        return value;
    } else if (V(use_mednafen_memcard0_method)) {
        /*
         Choose the save data format used for memory card 0. 'Mednafen' may be used for compatibility with the stand-alone version of Mednafen. When used with Beetle PSX, Libretro (.srm) and Mednafen (.mcr) saves have internally identical formats and can be converted between one another via renaming.
         */
        char *value = strdup("mednafen");
        return value;
    } else if (V(enable_memcard1)) {
        char *value = strdup("enabled");
        return value;
    } else if (V(shared_memory_cards)) {
        /*
         When enabled, all games will save to and load from the same memory card files. When disabled, separate memory card files will be generated for each item of loaded content. Note: if 'Memory Card 0 Method' is set to 'Libretro', only the right memory card will be affected.
         */
        char *value = strdup("disabled");
        return value;
    } else if (V(frame_duping)) {
        /*
         When enabled and supported by the libretro frontend, this provides a small performance increase by directing the frontend to repeat the previous frame if the core has nothing new to display.
         */
        char *value = strdup("enabled");
        return value;
    } else if (V(display_internal_fps)) {
        /*
         Display the internal frame rate at which the emulated PlayStation system is rendering content.
         Note: Requires onscreen notifications to be enabled in the libretro frontend.
         */
        char *value = strdup("disabled");
        return value;
//    } else if (V(crop_overscan)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(image_offset)) {
//        char *value = strdup("us");
//        return value;
//    } else if (V(image_crop)) {
//        char *value = strdup("us");
//        return value;
    } else if (V(cd_fastload)) {
        /*
         Choose disk access speed multiplier. Values higher than '2x (Native)' can greatly reduce in-game loading times, but may introduce timing errors. Some games may not function properly above a certain value.
         { "2x(native)", "2x (Native)" },
         { "4x",          NULL },
         { "6x",          NULL },
         { "8x",          NULL },
         { "10x",         NULL },
         { "12x",         NULL },
         { "14x",         NULL },
         */
        char *value = strdup("4x");
        return value;
    } else if (V(memcard_left_index)) {
        // Change the memory card currently loaded in the left slot. This option will only work if Memory Card 0 method is set to Mednafen. The default card is index 0.
        char *value = strdup("0");
        return value;
    } else if (V(memcard_right_index)) {
        // Change the memory card currently loaded in the left slot. This option will only work if Memory Card 0 method is set to Mednafen. The default card is index 0.
        char *value = strdup("0");
        return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }
#undef V
    return NULL;
}

@end
