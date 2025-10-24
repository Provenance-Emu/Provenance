//
//  MednafenControllerMappings.h
//  MednafenGameCoreC
//
//  Created by Joseph Mattiello on 9/24/24.
//  Copyright © 2024 Provenance EMU. All rights reserved.
//

#pragma once
#import <Foundation/Foundation.h>

#define DEADZONE                0.1f
#define OUTSIDE_DEADZONE(x)     gamepad.leftThumbstick.x.value > DEADZONE
#define DPAD_PRESSED(x)         [[dpad x] isPressed]?:OUTSIDE_DEADZONE(x)
    
#pragma mark - Input maps
static int PCEMap[] = { 4, 6, 7, 5, 0, 1, 8, 9, 10, 11, 3, 2, 12};
static int PCFXMap[] = { 8, 10, 11, 9, 0, 1, 2, 3, 4, 5, 7, 6, 12};
static int SNESMap[] = { 4, 5, 6, 7, 8, 0, 9, 1, 10, 11, 3, 2 };
static int GBMap[] = { 6, 7, 5,     4, 0, 1, 3, 2 };
static int GBAMap[] = { 6, 7, 5, 4, 0, 1, 9, 8, 3, 2};
/// ↑, ↓, ←, →, A, B, Start, Select
static const int NESMap[] = { 4, 5, 6, 7, 0, 1, 3, 2 };
/// A, B, 1, 2, ↓, ↑, ←, →, Pause
static const int LynxMap[] = { 6, 7, 4, 5, 0, 1, 3, 2, 8};

/// Select, [Triangle], [X], Start, R1, R2, left stick u, left stick left,
static const int PSXMap[]  = { 4, 6, 7, 5, 12, 13, 14, 15, 10, 8, 1, 11, 9, 2, 3, 0, 16, 24, 23, 22, 21, 20, 19, 18, 17 };
static const int VBMap[]   = { 9, 8, 7, 6, 4, 13, 12, 5, 3, 2, 0, 1, 10, 11 };
static const int WSMap[]   = { 0, 2, 3, 1, 4, 6, 7, 5, 9, 10, 8, 11 };
static const int NeoMap[]  = { 0, 1, 2, 3, 4, 5, 6};
/// SS Sega Saturn
static int SSMap[] = { 4, 5, 6, 7, 10, 8, 9, 2, 1, 0, 15, 3, 11 };
/// SMS, GG and MD unused as of now. Mednafen support is not maintained
static const int GenesisMap[] = { 5, 7, 11, 10, 0 ,1, 2, 3, 4, 6, 8, 9};

typedef NS_ENUM(NSInteger, MednaSystem) {
    MednaSystemGB,
    MednaSystemGBA,
    MednaSystemGG,
    MednaSystemLynx,
    MednaSystemMD,
    MednaSystemNES,
    MednaSystemNeoGeo,
    MednaSystemPCE,
    MednaSystemPCFX,
    MednaSystemSS,
    MednaSystemSMS,
    MednaSystemSNES,
    MednaSystemPSX,
    MednaSystemVirtualBoy,
    MednaSystemWonderSwan,
    MednaSystemApple2
};

