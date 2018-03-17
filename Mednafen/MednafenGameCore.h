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

@class OERingBuffer;

typedef NS_ENUM(NSInteger, MednaSystem) {
    MednaSystemLynx,
    MednaSystemNeoGeo,
    MednaSystemPCE,
    MednaSystemPCFX,
    MednaSystemPSX,
    MednaSystemVirtualBoy,
    MednaSystemWonderSwan
};

typedef NS_ENUM(NSInteger, PVPSXButton)
{
    PVPSXButtonUp,
    PVPSXButtonDown,
    PVPSXButtonLeft,
    PVPSXButtonRight,
    PVPSXButtonTriangle,
    PVPSXButtonCircle,
    PVPSXButtonCross,
    PVPSXButtonSquare,
    PVPSXButtonL1,
    PVPSXButtonL2,
    PVPSXButtonL3,
    PVPSXButtonR1,
    PVPSXButtonR2,
    PVPSXButtonR3,
    PVPSXButtonStart,
    PVPSXButtonSelect,
    PVPSXButtonAnalogMode,
    PVPSXButtonLeftAnalogUp,
    PVPSXButtonLeftAnalogDown,
    PVPSXButtonLeftAnalogLeft,
    PVPSXButtonLeftAnalogRight,
    PVPSXButtonRightAnalogUp,
    PVPSXButtonRightAnalogDown,
    PVPSXButtonRightAnalogLeft,
    PVPSXButtonRightAnalogRight,
    PVPSXButtonCount
};

typedef NS_ENUM(NSInteger, PVWSButton) {
    PVWSButtonX1, // Up
    PVWSButtonX3, // Down
    PVWSButtonX4, // Left
    PVWSButtonX2, // Right
    PVWSButtonY1,
    PVWSButtonY3,
    PVWSButtonY4,
    PVWSButtonY2,
    PVWSButtonA,
    PVWSButtonB,
    PVWSButtonStart,
    PVWSButtonSound,
    PVWSButtonCount
};

typedef NS_ENUM(NSInteger, PVVBButton) {
    PVVBButtonLeftUp,
    PVVBButtonLeftDown,
    PVVBButtonLeftLeft,
    PVVBButtonLeftRight,
    PVVBButtonRightUp,
    PVVBButtonRightDown,
    PVVBButtonRightLeft,
    PVVBButtonRightRight,
    PVVBButtonL,
    PVVBButtonR,
    PVVBButtonA,
    PVVBButtonB,
    PVVBButtonStart,
    PVVBButtonSelect,
    PVVBButtonCount
};

typedef NS_ENUM(NSInteger, PVPCEButton) {
    PVPCEButtonUp,
    PVPCEButtonDown,
    PVPCEButtonLeft,
    PVPCEButtonRight,
    PVPCEButtonButton1,
    PVPCEButtonButton2,
    PVPCEButtonButton3,
    PVPCEButtonButton4,
    PVPCEButtonButton5,
    PVPCEButtonButton6,
    PVPCEButtonRun,
    PVPCEButtonSelect,
    PVPCEButtonMode,
    PVPCEButtonCount
};

typedef NS_ENUM(NSInteger, PVPCFXButton) {
    PVPCFXButtonUp,
    PVPCFXButtonDown,
    PVPCFXButtonLeft,
    PVPCFXButtonRight,
    PVPCFXButtonButton1,
    PVPCFXButtonButton2,
    PVPCFXButtonButton3,
    PVPCFXButtonButton4,
    PVPCFXButtonButton5,
    PVPCFXButtonButton6,
    PVPCFXButtonRun,
    PVPCFXButtonSelect,
    PVPCFXButtonCount,
};

typedef NS_ENUM(NSInteger, PVPCECDButton) {
    PVPCECDButtonUp,
    PVPCECDButtonDown,
    PVPCECDButtonLeft,
    PVPCECDButtonRight,
    PVPCECDButtonButton1,
    PVPCECDButtonButton2,
    PVPCECDButtonButton3,
    PVPCECDButtonButton4,
    PVPCECDButtonButton5,
    PVPCECDButtonButton6,
    PVPCECDButtonRun,
    PVPCECDButtonSelect,
    PVPCECDButtonMode,
    PVPCECDButtonCount
};

typedef NS_ENUM(NSInteger, PVLynxButton) {
    PVLynxButtonUp,
    PVLynxButtonDown,
    PVLynxButtonLeft,
    PVLynxButtonRight,
    PVLynxButtonA,
    PVLynxButtonB,
    PVLynxButtonOption1,
    PVLynxButtonOption2,
    PVLynxButtonCount
};

typedef NS_ENUM(NSInteger, PVNGPButton) {
    PVNGPButtonUp,
    PVNGPButtonDown,
    PVNGPButtonLeft,
    PVNGPButtonRight,
    PVNGPButtonA,
    PVNGPButtonB,
    PVNGPButtonOption,
    PVNGPButtonCount,
};

__attribute__((visibility("default")))
@interface MednafenGameCore : PVEmulatorCore

@property (nonatomic) BOOL isStartPressed;
@property (nonatomic) BOOL isSelectPressed;

// Atari Lynx
- (oneway void)didPushLynxButton:(PVLynxButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleaseLynxButton:(PVLynxButton)button forPlayer:(NSUInteger)player;

// Neo Geo Pocket + Color
- (oneway void)didPushNGPButton:(PVNGPButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleaseNGPButton:(PVNGPButton)button forPlayer:(NSUInteger)player;

// PC-*
- (oneway void)didPushPCEButton:(PVPCEButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleasePCEButton:(PVPCEButton)button forPlayer:(NSUInteger)player;
- (oneway void)didPushPCECDButton:(PVPCECDButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleasePCECDButton:(PVPCECDButton)button forPlayer:(NSUInteger)player;
- (oneway void)didPushPCFXButton:(PVPCFXButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleasePCFXButton:(PVPCFXButton)button forPlayer:(NSUInteger)player;

// PSX
- (oneway void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
- (oneway void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player;

// Virtual Boy
- (oneway void)didPushVBButton:(PVVBButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleaseVBButton:(PVVBButton)button forPlayer:(NSUInteger)player;

// WonderSwan
- (oneway void)didPushWSButton:(PVWSButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleaseWSButton:(PVWSButton)button forPlayer:(NSUInteger)player;

@end

// for Swiwt
@interface MednafenGameCore()
@property (nonatomic, assign) MednaSystem systemType;
@property (nonatomic, assign) NSUInteger maxDiscs;
-(void)setMedia:(BOOL)open forDisc:(NSUInteger)disc;
@end
