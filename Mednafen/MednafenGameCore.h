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
#import "PVEmulatorCore.h"

@class OERingBuffer;

typedef NS_ENUM(int, PVPSXButton)
{
    OEPSXButtonUp,
    OEPSXButtonDown,
    OEPSXButtonLeft,
    OEPSXButtonRight,
    OEPSXButtonTriangle,
    OEPSXButtonCircle,
    OEPSXButtonCross,
    OEPSXButtonSquare,
    OEPSXButtonL1,
    OEPSXButtonL2,
    OEPSXButtonL3,
    OEPSXButtonR1,
    OEPSXButtonR2,
    OEPSXButtonR3,
    OEPSXButtonStart,
    OEPSXButtonSelect,
    OEPSXButtonAnalogMode,
    OEPSXLeftAnalogUp,
    OEPSXLeftAnalogDown,
    OEPSXLeftAnalogLeft,
    OEPSXLeftAnalogRight,
    OEPSXRightAnalogUp,
    OEPSXRightAnalogDown,
    OEPSXRightAnalogLeft,
    OEPSXRightAnalogRight,
    OEPSXButtonCount
};


__attribute__((visibility("default")))
@interface MednafenGameCore : PVEmulatorCore
- (oneway void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSUInteger)player;
- (oneway void)didMovePSXJoystickDirection:(PVPSXButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player;
@end
