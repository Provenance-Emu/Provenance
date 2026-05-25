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

@import Foundation;
//@import PVEmulatorCore;
//@import PVCoreBridge;
@import PVCoreObjCBridge;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

@protocol ObjCBridgedCoreBridge;
@protocol PV7800SystemResponderClient;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
__attribute__((visibility("default")))
@interface PVProSystemGameCore : PVCoreObjCBridge<ObjCBridgedCoreBridge, PV7800SystemResponderClient>
#pragma clang diagnostic pop

/// Whether the left difficulty switch is in the A (Advanced) position.
/// false = B (Beginner, inputState = 1), true = A (Advanced, inputState = 0).
@property (nonatomic, assign) BOOL leftDifficultyIsAdvanced;

/// Whether the right difficulty switch is in the A (Advanced) position.
/// false = B (Beginner, inputState = 1), true = A (Advanced, inputState = 0).
@property (nonatomic, assign) BOOL rightDifficultyIsAdvanced;

/// Toggle the left difficulty switch between A and B.
- (void)toggleLeftDifficulty;

/// Toggle the right difficulty switch between A and B.
- (void)toggleRightDifficulty;

// MARK: RetroAchievements
/// Pointer to the Atari 7800 6502 RAM (memory_ram, 64 KiB).
@property (nonatomic, readonly, nullable) void *systemRAMPtr;
/// Size in bytes of the exposed RAM (64 KiB).
@property (nonatomic, readonly) NSUInteger systemRAMSize;

// MARK: Light Gun (XG-1)
// Declarations inlined into main interface — the (LightGun) category in
// PVProSystemCoreBridge+LightGun.h was silently elided during Swift module
// synthesis (same issue Stella's bridge hit). Implementations remain in
// PVProSystemCoreBridge+LightGun.mm and resolve at link time.

/// `YES` when the loaded cartridge declares lightgun support in its header
/// (`cartridge_controller[0] & CARTRIDGE_CONTROLLER_LIGHTGUN`) or when its
/// MD5 matches one of the five known commercial 7800 lightgun titles.
@property (nonatomic, readonly) BOOL isLightGunEnabled;

/// Headerless MD5 of the currently loaded cartridge, or `nil` if no cart is
/// loaded. Used by the Swift wrapper to gate `gameSupportsLightGun` per-game.
@property (nonatomic, readonly, nullable, copy) NSString *cartridgeMD5;

/// Update the lightgun aim using normalised [0, 1] screen coordinates.
- (void)lightGunMoveNormalized:(CGPoint)normalisedPoint isOffscreen:(BOOL)isOffscreen;

/// Trigger press / release.
- (void)lightGunTriggerPressed;
- (void)lightGunTriggerReleased;

@end

NS_HEADER_AUDIT_END(nullability, sendability)
