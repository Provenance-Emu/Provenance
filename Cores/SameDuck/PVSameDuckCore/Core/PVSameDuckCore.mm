//
//  PVSameDuckCore.m
//  PVSameDuck
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVSameDuckCore.h"
#include <stdatomic.h>
#import "PVSameDuckCore+Controls.h"
#import "PVSameDuckCore+Audio.h"
#import "PVSameDuckCore+Video.h"

#import "PVSameDuckCore+Audio.h"

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVSameDuckCore() {

}

@end

#pragma mark - PVSameDuckCore Begin

@implementation PVSameDuckCore
{
}

- (instancetype)init {
	if (self = [super init]) {
        pitch_shift = 4;
	}

	_current = self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore
//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
//    BOOL loaded = [super loadFileAtPath:path completionHandler:error];
//
//    return loaded;
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
//- (BOOL)supportsRumble { return NO; }
//- (BOOL)supportsCheatCode { return NO; }
#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);
    
    
#define V(x) strcmp(variable, x) == 0
    if (V("SameDuck_use_hw")) {
        char *value = strdup("Hardware");
        return value;
    } else if (V("SameDuck_res_multi")) {
        // Internal Resolution Multiplier
        // 1,2,3,4
        char *value = strdup("2");
        return value;
    } else if (V("SameDuck_res_hw")) {
        // Hardware Rendering Resolution
        // 824x1024|434x540|515x640|580x720|618x768|845x1050|869x1080|966x1200|1159x1440|1648x2048
        char *value = strdup("869x1080");
        return value;
    } else if (V("SameDuck_line_brightness")) {
        char *value = strdup("4");
        return value;
    } else if (V("SameDuck_line_width")) {
        char *value = strdup("4");
        return value;
    } else if (V("SameDuck_bloom_brightness")) {
        char *value = strdup("4");
        return value;
    } else if (V("SameDuck_bloom_width")) {
        char *value = strdup("8x");
        return value;
    } else if (V("SameDuck_scale_x")) {
        // "Scale vector display horizontally; 1|0.845|0.85|0.855|0.86|0.865|0.87|0.875|0.88|0.885|0.89|0.895|0.90|0.905|0.91|0.915|0.92|0.925|0.93|0.935|0.94|0.945|0.95|0.955|0.96|0.965|0.97|0.975|0.98|0.985|0.99|0.995|1.005|1.01"
        char *value = strdup("1");
        return value;
    } else if (V("SameDuck_scale_y")) {
        // "Scale vector display vertically; 1|0.845|0.85|0.855|0.86|0.865|0.87|0.875|0.88|0.885|0.89|0.895|0.90|0.905|0.91|0.915|0.92|0.925|0.93|0.935|0.94|0.945|0.95|0.955|0.96|0.965|0.97|0.975|0.98|0.985|0.99|0.995|1.005|1.01"
        char *value = strdup("1");
        return value;
    } else if (V("SameDuck_shift_x")) {
        char *value = strdup("0");
        return value;
    } else if (V("SameDuck_shift_y")) {
        char *value = strdup("0");
        return value;
    } else if (V("SameDuck_pure_memory_size")) {
        char *value = strdup("16");
        return value;
    } else if (V("SameDuck_pure_cpu_type")) {
        char *value = strdup("pentium_slow"); // auto
        return value;
    } else if (V("SameDuck_pure_cpu_core")) {
        char *value = strdup("auto");
        return value;
    } else if (V("SameDuck_pure_keyboard_layout")) {
        char *value = strdup("us");
        return value;
    } else {
        ELOG(@"Unprocessed var: %s", variable);
        return nil;
    }
    
    /*
     "SameDuck_pure_mouse_wheel",
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
     
     "SameDuck_pure_cycles",
     "Emulated Performance", NULL,
     "The raw performance that SameDuck will try to emulate." "\n\n", NULL, //end of Performance section
     "Performance",
     {
         { "auto",    "AUTO - SameDuck will try to detect performance needs (default)" },
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
     
         "SameDuck_pure_cpu_type",
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
         "SameDuck_pure_cpu_core",
         "Advanced > CPU Core", NULL,
         "Emulation method (SameDuck CPU core) used.", NULL,
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
