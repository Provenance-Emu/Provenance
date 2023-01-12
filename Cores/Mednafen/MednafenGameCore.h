/*
 Copyright (c) 2013, OpenEmu Team
 
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Foundation/Foundation.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>

@class OERingBuffer;

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
    MednaSystemWonderSwan
};

#pragma mark - Input maps
static int PCEMap[] = { 4, 6, 7, 5, 0, 1, 8, 9, 10, 11, 3, 2, 12};
static int PCFXMap[] = { 8, 10, 11, 9, 0, 1, 2, 3, 4, 5, 7, 6, 12};
static int SNESMap[] = { 4, 5, 6, 7, 8, 0, 9, 1, 10, 11, 3, 2 };
static int GBMap[] = { 6, 7, 5, 4, 0, 1, 3, 2 };
static int GBAMap[] = { 6, 7, 5, 4, 0, 1, 9, 8, 3, 2};
// ↑, ↓, ←, →, A, B, Start, Select
static int NESMap[] = { 4, 5, 6, 7, 0, 1, 3, 2 };
// Pause, B, 1, 2, ↓, ↑, ←, →
static const int LynxMap[] = { 6, 7, 4, 5, 0, 1, 3, 2 };

// Select, [Triangle], [X], Start, R1, R2, left stick u, left stick left,
static const int PSXMap[]  = { 4, 6, 7, 5, 12, 13, 14, 15, 10, 8, 1, 11, 9, 2, 3, 0, 16, 24, 23, 22, 21, 20, 19, 18, 17 };
static const int VBMap[]   = { 9, 8, 7, 6, 4, 13, 12, 5, 3, 2, 0, 1, 10, 11 };
static const int WSMap[]   = { 0, 2, 3, 1, 4, 6, 7, 5, 9, 10, 8, 11 };
static const int NeoMap[]  = { 0, 1, 2, 3, 4, 5, 6};
// SS Sega Saturn
static int SSMap[] = { 4, 5, 6, 7, 10, 8, 9, 2, 1, 0, 15, 3, 11 };
// SMS, GG and MD unused as of now. Mednafen support is not maintained
static const int GenesisMap[] = { 5, 7, 11, 10, 0 ,1, 2, 3, 4, 6, 8, 9};

__attribute__((visibility("default")))
@interface MednafenGameCore : PVEmulatorCore

@property (nonatomic) BOOL isStartPressed;
@property (nonatomic) BOOL isSelectPressed;
@property (nonatomic) BOOL isAnalogModePressed;
@property (nonatomic) BOOL isL3Pressed;
@property (nonatomic) BOOL isR3Pressed;

@end


#define DEADZONE 0.1f
#define OUTSIDE_DEADZONE(x) gamepad.leftThumbstick.x.value > DEADZONE
#define DPAD_PRESSED(x) [[dpad x] isPressed]?:OUTSIDE_DEADZONE(x)

// for Swift
@interface MednafenGameCore() {
    uint32_t *inputBuffer[13];
    int16_t axis[8];
    int videoWidth, videoHeight;
    int videoOffsetX, videoOffsetY;
    int multiTapPlayerCount;
    NSString *romName;
    double sampleRate;
    double masterClock;
    
    BOOL _isSBIRequired;
    
    NSString *mednafenCoreModule;
    NSTimeInterval mednafenCoreTiming;
}

@property (nonatomic, assign) MednaSystem systemType;
@property (nonatomic, assign) NSUInteger maxDiscs;

@property (nonatomic, assign) BOOL video_opengl;

-(void)setMedia:(BOOL)open forDisc:(NSUInteger)disc;
-(void)changeDisplayMode;
-(const void *)getGame;

@end

@interface MednafenGameCore (Cheats)
- (NSArray<NSString*> *)getCheatCodeTypes;
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;
- (BOOL)getCheatSupport;
@end

@interface MednafenGameCore (Controls)

- (void)didPushLynxButton:(PVLynxButton)button forPlayer:(NSInteger)player;
- (void)didReleaseLynxButton:(PVLynxButton)button forPlayer:(NSInteger)player;
- (NSInteger)LynxControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;

#pragma mark SNES
- (void)didPushSNESButton:(enum PVSNESButton)button forPlayer:(NSInteger)player;
- (void)didReleaseSNESButton:(enum PVSNESButton)button forPlayer:(NSInteger)player;

#pragma mark NES
- (void)didPushNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player;
- (void)didReleaseNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player;

#pragma mark GB / GBC
- (void)didPushGBButton:(enum PVGBButton)button forPlayer:(NSInteger)player;
- (void)didReleaseGBButton:(enum PVGBButton)button forPlayer:(NSInteger)player;

#pragma mark GBA
- (void)didPushGBAButton:(enum PVGBAButton)button forPlayer:(NSInteger)player;
- (void)didReleaseGBAButton:(enum PVGBAButton)button forPlayer:(NSInteger)player;

#pragma mark Sega
- (void)didPushSegaButton:(enum PVGenesisButton)button forPlayer:(NSInteger)player;
- (void)didReleaseSegaButton:(enum PVGenesisButton)button forPlayer:(NSInteger)player;

#pragma mark Neo Geo
- (void)didPushNGPButton:(PVNGPButton)button forPlayer:(NSInteger)player;
- (void)didReleaseNGPButton:(PVNGPButton)button forPlayer:(NSInteger)player;

#pragma mark PC-*
#pragma mark PCE aka TurboGFX-16 & SuperGFX
- (void)didPushPCEButton:(PVPCEButton)button forPlayer:(NSInteger)player;
- (void)didReleasePCEButton:(PVPCEButton)button forPlayer:(NSInteger)player;

#pragma mark PCE-CD
- (void)didPushPCECDButton:(PVPCECDButton)button forPlayer:(NSInteger)player;
- (void)didReleasePCECDButton:(PVPCECDButton)button forPlayer:(NSInteger)player;
#pragma mark PCFX
- (void)didPushPCFXButton:(PVPCFXButton)button forPlayer:(NSInteger)player;
- (void)didReleasePCFXButton:(PVPCFXButton)button forPlayer:(NSInteger)player;
#pragma mark SS Sega Saturn
- (void)didPushSSButton:(enum PVSaturnButton)button forPlayer:(NSInteger)player;
-(void)didReleaseSSButton:(enum PVSaturnButton)button forPlayer:(NSInteger)player;

#pragma mark PSX
- (void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSInteger)player;

- (void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSInteger)player;
- (void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
#pragma mark Virtual Boy
- (void)didPushVBButton:(PVVBButton)button forPlayer:(NSInteger)player;
- (void)didReleaseVBButton:(PVVBButton)button forPlayer:(NSInteger)player;
#pragma mark WonderSwan
- (void)didPushWSButton:(PVWSButton)button forPlayer:(NSInteger)player;
- (void)didReleaseWSButton:(PVWSButton)button forPlayer:(NSInteger)player;

- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player withAnalogMode:(bool)analogMode;
#pragma mark SS Buttons
- (NSInteger)SSValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;
#pragma mark GB Buttons
- (NSInteger)GBValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;
#pragma mark GBA Buttons
- (NSInteger)GBAValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;

#pragma mark SNES Buttons
- (NSInteger)SNESValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;
#pragma mark NES Buttons
- (NSInteger)NESValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;
#pragma mark NEOGEOPOCKET Buttons
- (NSInteger)NeoGeoValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;
#pragma mark PCE Buttons
- (NSInteger)PCEValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;
#pragma mark PSX Buttons
- (float)PSXAnalogControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;
- (NSInteger)PSXcontrollerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller withAnalogMode:(bool)analogMode;
#pragma mark VirtualBoy Buttons
- (NSInteger)VirtualBoyControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;
#pragma mark Wonderswan Buttons
- (NSInteger)WonderSwanControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller;

//- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player;
//- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player;
//- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
@end
