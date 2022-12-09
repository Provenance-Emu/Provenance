//
//  PVPotatorCore.m
//  PVPotator
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVPotatorCore.h"
#include <stdatomic.h>
//#import "PVPotatorCore+Controls.h"
//#import "PVPotatorCore+Audio.h"
//#import "PVPotatorCore+Video.h"
//
//#import "PVPotatorCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVPotatorCore() {

}

@end

#pragma mark - PVPotatorCore Begin

@implementation PVPotatorCore
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
//    return YES;
//}

#pragma mark - Running
//- (void)startEmulation {
//}

//- (void)setPauseEmulation:(BOOL)flag {
//	[super setPauseEmulation:flag];
//}
//
//- (void)stopEmulation {
//}
//
//- (void)resetEmulation {
//}

//# pragma mark - Cheats
//- (void)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled {
//}
//
//- (BOOL)supportsRumble { return NO; }
//- (BOOL)supportsCheatCode { return NO; }

//- (NSTimeInterval)frameInterval {
//    return 60.0;
//}
//
//- (CGSize)aspectSize {
//    return CGSizeMake(1, 1);
//}
//
//- (CGSize)bufferSize {
//    return CGSizeMake(160, 160);
//}

//- (GLenum)pixelFormat {
//    return GL_RGB;
//}
//
//- (GLenum)pixelType {
//    return GL_UNSIGNED_SHORT_5_6_5;
//}
//
//- (GLenum)internalPixelFormat {
//    return GL_RGB565;
//}

# pragma mark - Audio

//- (double)audioSampleRate {
//    return 44100;
//}
//
//- (NSUInteger)channelCount {
//    // TODO: Test 1
//    return 2;
//}

#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);
    
    
#define V(x) strcmp(variable, x) == 0
    if (V("potator_palette")) {
            // none,simple,detailed
            char *value = strdup("potator_green");
            return value;
    } else if (V("potator_lcd_ghosting")) {
            // Off|Interlaced|Progressive
            char *value = strdup("3");
            return value;
    } else if (V("potator_frameskip")) {
            // on,rewind,disable
            char *value = strdup("auto");
            return value;
    } else if (V("potator_frameskip_threshold")) {
            // true,false
            // Enable the On Screen Keyboard feature which can be activated with the L3 button on the controller.
            char *value = strdup("30");
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

@implementation PVPotatorCore (PVSupervisionSystemResponderClient)

-(void)didPushSupervisionButton:(enum PVSupervisionButton)button forPlayer:(NSInteger)player {

}

-(void)didReleaseSupervisionButton:(enum PVSupervisionButton)button forPlayer:(NSInteger)player {

}

@end
