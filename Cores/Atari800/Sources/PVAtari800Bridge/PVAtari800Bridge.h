/*
 Copyright (c) 2011, OpenEmu Team
 
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

@import Foundation;
@import CoreGraphics;
@import PVCoreObjCBridge;

@protocol ObjCBridgedCoreBridge;
@protocol PVA8SystemResponderClient;
@protocol PV5200SystemResponderClient;
typedef enum PVA8Button: NSInteger PVA8Button;
typedef enum PV5200Button: NSInteger PV5200Button;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVAtari800Bridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, PVA8SystemResponderClient, PV5200SystemResponderClient>
#pragma clang diagnostic pop

- (void)didPush5200Button:(PV5200Button)button forPlayer:(NSUInteger)player;
- (void)didRelease5200Button:(PV5200Button)button forPlayer:(NSUInteger)player;
- (void)didMove5200JoystickDirection:(PV5200Button)button withValue:(CGFloat)value forPlayer:(NSUInteger)player;

- (void)didReleaseA8Button:(PVA8Button)button forPlayer:(NSUInteger)player;
- (void)didPushA8Button:(PVA8Button)button forPlayer:(NSUInteger)player;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
