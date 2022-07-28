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
- (BOOL)supportsCheatCodes { return YES; }

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
    
    
#define V(x) strcmp(variable, x) == 0
    if (V("beetle_psx_hw_renderer")) {
        // hardware, hardware_gl, hardware_vk, software
        char *value = strdup("software");
        return value;
    } else if (V("beetle_psx_hw_renderer_software_fb")) {
//        "Enable accurate emulation of framebuffer effects (e.g. motion blur, FF7 battle swirl) when using hardware renderers by running a copy of the software renderer at native resolution in the background. If disabled, these operations are omitted (OpenGL) or rendered on the GPU (Vulkan). Disabling can improve performance but may cause severe graphical errors. Leave enabled if unsure.",
//        NULL,
//        "video",
//        {
//           { "enabled",  NULL },
//           { "disabled", NULL },
//           { NULL, NULL },
//        },
            char *value = strdup("disabled");
            return value;
    } else if (V("dosbox_pure_perfstats")) {
            // Off|Interlaced|Progressive
            char *value = strdup("Progressive");
            return value;
    } else if (V("dosbox_pure_savestate")) {
            // on,rewind,disable
            char *value = strdup("on");
            return value;
    } else if (V("dosbox_pure_on_screen_keyboard")) {
            // true,false
            // Enable the On Screen Keyboard feature which can be activated with the L3 button on the controller.
            char *value = strdup("true");
            return value;
    } else if (V("dosbox_pure_audiorate")) {
            // "This should match the frontend audio output rate (Hz) setting.", NULL,
//            char * value = [[NSString stringWithFormat:@"%i", self.audioSampleRate] cStringUsingEncoding:NSUTF8StringEncoding];
            char *value = strdup("44100");
            return value;
    } else if (V("dosbox_pure_machine")) {
//        { "svga",     "SVGA (Super Video Graphics Array) (default)" },
//        { "vga",      "VGA (Video Graphics Array)" },
//        { "ega",      "EGA (Enhanced Graphics Adapter" },
//        { "cga",      "CGA (Color Graphics Adapter)" },
//        { "tandy",    "Tandy (Tandy Graphics Adapter" },
//        { "hercules", "Hercules (Hercules Graphics Card)" },
//        { "pcjr",     "PCjr" },
        char *value = strdup("svga");
        return value;
    } else if (V("dosbox_pure_cga")) {
        char *value = strdup("early_auto");
        return value;
    } else if (V("dosbox_pure_hercules")) {
        char *value = strdup("white");
        return value;
    } else if (V("dosbox_pure_svga")) {
        char *value = strdup("svga_s3");
        return value;
    } else if (V("dosbox_pure_aspect_correction")) {
        char *value = strdup("false");
        return value;
    } else if (V("dosbox_pure_memory_size")) {
        char *value = strdup("16");
        return value;
    } else if (V("dosbox_pure_cpu_type")) {
        char *value = strdup("pentium_slow"); // auto
        return value;
    } else if (V("dosbox_pure_cpu_core")) {
        char *value = strdup("auto");
        return value;
    } else if (V("dosbox_pure_keyboard_layout")) {
        char *value = strdup("us");
        return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }
    
    /*
     "dosbox_pure_mouse_wheel",
     "Bind Mouse Wheel To Key", NULL,
     "Bind mouse wheel up and down to two keyboard keys to be able to use it in DOS games.", NULL,
     "Input",
     {
         { "67/68", "Left-Bracket/Right-Bracket" },
         { "72/71", "Comma/Period" },
         { "79/82", "Page-Up/Page-Down" },
         { "78/81", "Home/End" },
         { "80/82", "Delete/Page-Down" },
         { "64/65", "Minus/Equals" },
         { "69/70", "Semicolon/Quote" },
         { "99/100", "Numpad Minus/Plus" },
         { "97/98", "Numpad Divide/Multiply" },
         { "84/85", "Up/Down" },
         { "83/86", "Left/Right" },
         { "11/13", "Q/E" },
         { "none", "Disable" },
     },
     "67/68"
     
     "dosbox_pure_cycles",
     "Emulated Performance", NULL,
     "The raw performance that DOSBox will try to emulate." "\n\n", NULL, //end of Performance section
     "Performance",
     {
         { "auto",    "AUTO - DOSBox will try to detect performance needs (default)" },
         { "max",     "MAX - Emulate as many instructions as possible" },
         { "315",     "8086/8088, 4.77 MHz from 1980 (315 cps)" },
         { "1320",    "286, 6 MHz from 1982 (1320 cps)" },
         { "2750",    "286, 12.5 MHz from 1985 (2750 cps)" },
         { "4720",    "386, 20 MHz from 1987 (4720 cps)" },
         { "7800",    "386DX, 33 MHz from 1989 (7800 cps)" },
         { "13400",   "486DX, 33 MHz from 1990 (13400 cps)" },
         { "26800",   "486DX2, 66 MHz from 1992 (26800 cps)" },
         { "77000",   "Pentium, 100 MHz from 1995 (77000 cps)" },
         { "200000",  "Pentium II, 300 MHz from 1997 (200000 cps)" },
         { "500000",  "Pentium III, 600 MHz from 1999 (500000 cps)" },
         { "1000000", "AMD Athlon, 1.2 GHz from 2000 (1000000 cps)" },
     },
     
         "dosbox_pure_cpu_type",
         "CPU Type", NULL,
         "Emulated CPU type. Auto is the fastest choice." "\n"
             "Games that require specific CPU type selection:" "\n"
             "386 (prefetch): X-Men: Madness in The Murderworld, Terminator 1, Contra, Fifa International Soccer 1994" "\n"
             "486 (slow): Betrayal in Antara" "\n"
             "Pentium (slow): Fifa International Soccer 1994, Windows 95/Windows 3.x games" "\n\n", NULL, //end of System section
         "System",
         {
             { "auto", "Auto - Mixed feature set with maximum performance and compatibility" },
             { "386", "386 - 386 instruction with fast memory access" },
             { "386_slow", "386 (slow) - 386 instruction set with memory privilege checks" },
             { "386_prefetch", "386 (prefetch) - With prefetch queue emulation (only on 'auto' and 'normal' core)" },
             { "486_slow", "486 (slow) - 486 instruction set with memory privilege checks" },
             { "pentium_slow", "Pentium (slow) - 586 instruction set with memory privilege checks" },
         },
         "auto"
     },
     {
         "dosbox_pure_cpu_core",
         "Advanced > CPU Core", NULL,
         "Emulation method (DOSBox CPU core) used.", NULL,
         "System",
         {
             #if defined(C_DYNAMIC_X86)
             { "auto", "Auto - Real-mode games use normal, protected-mode games use dynamic" },
             { "dynamic", "Dynamic - Dynamic recompilation (fast, using dynamic_x86 implementation)" },
             #elif defined(C_DYNREC)
             { "auto", "Auto - Real-mode games use normal, protected-mode games use dynamic" },
             { "dynamic", "Dynamic - Dynamic recompilation (fast, using dynrec implementation)" },
             #endif
             { "normal", "Normal (interpreter)" },
             { "simple", "Simple (interpreter optimized for old real-mode games)" },
         },
         #if defined(C_DYNAMIC_X86) || defined(C_DYNREC)
         "auto"
         #else
         "normal"
         #endif
     },
     */
#undef V
    return NULL;
}

@end
