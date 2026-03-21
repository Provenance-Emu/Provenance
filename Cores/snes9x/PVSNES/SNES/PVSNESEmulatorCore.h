/*
 Copyright (c) 2009, OpenEmu Team
 
 
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
@import PVCoreObjCBridge;

@protocol ObjCBridgedCoreBridge;
@protocol PVSNESSystemResponderClient;
typedef enum PVSNESButton: NSInteger PVSNESButton;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVSNESEmulatorCoreBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, PVSNESSystemResponderClient>
#pragma clang diagnostic pop

- (void)didPushSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player;
- (void)didReleaseSNESButton:(PVSNESButton)button forPlayer:(NSInteger)player;
- (void)flipBuffers;

# pragma CheatCodeSupport
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;

# pragma mark - Mouse Support
/// YES when the loaded ROM's CRC matches a known SNES mouse game.
@property (nonatomic, readonly) BOOL isSNESMouseGame;
/// Report normalised [0,1] cursor movement; bridge accumulates a virtual SNES-space position.
- (void)snesMouseMovedTo:(CGPoint)normalizedPoint;
/// Report a relative delta in view-point units (e.g. from a tvOS Siri Remote pan gesture).
/// The delta is added directly to the accumulated SNES cursor position (1 pt ≈ 1 SNES pixel).
/// Sub-pixel remainders are accumulated across calls to avoid dropped fractional movement.
- (void)snesMouseMovedByDelta:(CGPoint)delta;
- (void)snesLeftMouseDown;
- (void)snesLeftMouseUp;
- (void)snesRightMouseDown;
- (void)snesRightMouseUp;
- (void)resetSNESMouseTracking;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
