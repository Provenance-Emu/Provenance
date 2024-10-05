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
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>
#import <MednafenGameCoreC/MednafenGameCoreC.h>
#import <MednafenGameCoreBridge/MednafenGameCoreBridge.h>
#import <mednafen/mednafen.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

/// Forward Declerations
@protocol ObjCBridgedCoreBridge, GameWithCheat;
@protocol PVPSXSystemResponderClient, PVWonderSwanSystemResponderClient, PVVirtualBoySystemResponderClient, PVPCESystemResponderClient, PVPCFXSystemResponderClient, PVPCECDSystemResponderClient, PVLynxSystemResponderClient, PVNeoGeoPocketSystemResponderClient, PVSNESSystemResponderClient, PVNESSystemResponderClient, PVGBSystemResponderClient, PVGBASystemResponderClient, PVSaturnSystemResponderClient;
typedef enum PVGBAButton: NSInteger PVGBAButton;
typedef enum PVGBButton: NSInteger PVGBButton;
typedef enum PVGenesisButton: NSInteger PVGenesisButton;
typedef enum PVLynxButton: NSInteger PVLynxButton;
typedef enum PVNESButton: NSInteger PVNESButton;
typedef enum PVNGPButton: NSInteger PVNGPButton;
typedef enum PVPCEButton: NSInteger PVPCEButton;
typedef enum PVPCECDButton: NSInteger PVPCECDButton;
typedef enum PVPCFXButton: NSInteger PVPCFXButton;
typedef enum PVPSXButton: NSInteger PVPSXButton;
typedef enum PVSNESButton: NSInteger PVSNESButton;
typedef enum PVSaturnButton: NSInteger PVSaturnButton;
typedef enum PVVBButton: NSInteger PVVBButton;
typedef enum PVWSButton: NSInteger PVWSButton;

__attribute__((visibility("default")))
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface MednafenGameCoreBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, PVPSXSystemResponderClient, PVWonderSwanSystemResponderClient, PVVirtualBoySystemResponderClient, PVPCESystemResponderClient, PVPCFXSystemResponderClient, PVPCECDSystemResponderClient, PVLynxSystemResponderClient, PVNeoGeoPocketSystemResponderClient, PVSNESSystemResponderClient, PVNESSystemResponderClient, PVGBSystemResponderClient, PVGBASystemResponderClient, PVSaturnSystemResponderClient>
#pragma clang diagnostic pop
{
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

@property (nonatomic) BOOL isStartPressed;
@property (nonatomic) BOOL isSelectPressed;
@property (nonatomic) BOOL isAnalogModePressed;
@property (nonatomic) BOOL isL3Pressed;
@property (nonatomic) BOOL isR3Pressed;

// for Swift
@property (nonatomic, assign) MednaSystem systemType;
@property (nonatomic, assign) NSUInteger maxDiscs;

@property (nonatomic, assign) BOOL video_opengl;

-(void)setMedia:(BOOL)open forDisc:(NSUInteger)disc;
-(void)changeDisplayMode;
-(const void *)getGame;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface MednafenGameCoreBridge (Cheats) <GameWithCheat>
#pragma clang diagnostic pop
- (NSArray<NSString*> *)getCheatCodeTypes;
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;
- (BOOL)getCheatSupport;
@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface MednafenGameCoreBridge (Controls) <PVPSXSystemResponderClient, PVWonderSwanSystemResponderClient, PVVirtualBoySystemResponderClient, PVPCESystemResponderClient, PVPCFXSystemResponderClient, PVPCECDSystemResponderClient, PVLynxSystemResponderClient, PVNeoGeoPocketSystemResponderClient, PVSNESSystemResponderClient, PVNESSystemResponderClient, PVGBSystemResponderClient, PVGBASystemResponderClient, PVSaturnSystemResponderClient>
#pragma clang diagnostic pop

- (void)didPushLynxButton:(PVLynxButton)lynxButton forPlayer:(NSInteger)player;
- (void)didReleaseLynxButton:(PVLynxButton)lynxButton forPlayer:(NSInteger)player;
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
- (void)didPushNGPButton:(enum PVNGPButton)button forPlayer:(NSInteger)player;
- (void)didReleaseNGPButton:(enum PVNGPButton)button forPlayer:(NSInteger)player;
#pragma mark PC-*
#pragma mark PCE aka TurboGFX-16 & SuperGFX
- (void)didPushPCEButton:(enum PVPCEButton)button forPlayer:(NSInteger)player;
- (void)didReleasePCEButton:(enum PVPCEButton)button forPlayer:(NSInteger)player;
#pragma mark PCE-CD
- (void)didPushPCECDButton:(enum PVPCECDButton)button forPlayer:(NSInteger)player;
- (void)didReleasePCECDButton:(enum PVPCECDButton)button forPlayer:(NSInteger)player;
#pragma mark PCFX
- (void)didPushPCFXButton:(enum PVPCFXButton)button forPlayer:(NSInteger)player;
- (void)didReleasePCFXButton:(enum PVPCFXButton)button forPlayer:(NSInteger)player;
#pragma mark SS Sega Saturn
- (void)didPushSSButton:(enum PVSaturnButton)button forPlayer:(NSInteger)player;
- (void)didReleaseSSButton:(enum PVSaturnButton)button forPlayer:(NSInteger)player;
#pragma mark PSX
- (void)didPushPSXButton:(enum PVPSXButton)button forPlayer:(NSInteger)player;
- (void)didReleasePSXButton:(enum PVPSXButton)button forPlayer:(NSInteger)player;
- (void)didMovePSXJoystickDirection:(enum PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSInteger)player;
#pragma mark Virtual Boy
- (void)didPushVBButton:(enum PVVBButton)button forPlayer:(NSInteger)player;
- (void)didReleaseVBButton:(enum PVVBButton)button forPlayer:(NSInteger)player;
#pragma mark WonderSwan
- (void)didPushWSButton:(enum PVWSButton)button forPlayer:(NSInteger)player;
- (void)didReleaseWSButton:(enum PVWSButton)button forPlayer:(NSInteger)player;
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

NS_HEADER_AUDIT_END(nullability, sendability)
