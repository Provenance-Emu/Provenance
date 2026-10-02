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

#import <Foundation/Foundation.h>
@import CoreGraphics;
@import PVCoreObjCBridge;
@protocol LightGunResponder; // full definition in PVCoreBridge; imported by .mm

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

@protocol ObjCBridgedCoreBridge;
@protocol PVNESSystemResponderClient;
@protocol LightGunResponder;

@interface PVFCEUEmulatorCoreBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, PVNESSystemResponderClient, LightGunResponder> {

    uint32_t pad[2][12];

    // Light gun (Zapper) state — written by LightGunResponder methods, consumed each frame.
    uint32_t _zapperData[3]; // [0]=x, [1]=y, [2]=button bits (1=trigger, 2=offscreen)
    CGPoint  _lightGunPosition;
    BOOL     _lightGunTrigger;
    BOOL     _lightGunIsOffscreen;
    BOOL     _zapperEnabled; // YES when the loaded ROM uses a Zapper (port 0 or 1)
}

- (void)internalSwapDisc:(NSUInteger)discNumber;

# pragma mark - RetroAchievements
/// Pointer to FCEUX's `RAM[0x800]` — the 2 KiB internal NES RAM at CPU
/// $0000 (mirrored at $0800/$1000/$1800). rcheevos' NES and FDS maps
/// (consoleinfo.c) put it at flat address 0x0000, and their $0800-$1FFF
/// "Mirror RAM" regions duplicate this same block.
@property (nonatomic, readonly, nullable) void *systemRAMPtr;
/// Size in bytes of the block exposed via @c systemRAMPtr (2 KiB).
@property (nonatomic, readonly) NSUInteger systemRAMSize;

/// Pointer to FCEUX's `PPU[4]` ($2000-$2003), the same 4 bytes
/// libretro-fceumm publishes in its memory map for flat 0x2000.
@property (nonatomic, readonly, nullable) void *ppuRegistersPtr;
/// Size in bytes of the block exposed via @c ppuRegistersPtr.
@property (nonatomic, readonly) NSUInteger ppuRegistersSize;

/// PRG-RAM currently mapped at CPU $6000 (flat 0x6000): cartridge WRAM
/// (battery-backed or not) for NES carts, or the 32 KiB FDS RAM spanning
/// $6000-$DFFF for Famicom Disk System games. NULL when no game is loaded
/// or the cart maps no RAM there. Resolved from FCEUX's page table, so a
/// banked WRAM chip is pinned to the bank active when this is read.
@property (nonatomic, readonly, nullable) void *cartridgeRAMPtr;
/// Contiguous size in bytes of the block exposed via @c cartridgeRAMPtr
/// (0 when unavailable; at most 8 KiB for carts, 32 KiB for FDS).
@property (nonatomic, readonly) NSUInteger cartridgeRAMSize;

/// Invoked on the emulation thread at the end of every emulated frame.
/// The ObjC emulation loop calls the bridge's `executeFrame` directly, so a
/// Swift `PVEmulatorCore.executeFrame()` override never runs; the Swift core
/// uses this hook to drive the RetroAchievements per-frame tick instead.
@property (nonatomic, copy, nullable) void (^frameCompletedHandler)(void);

@end

@interface PVFCEUEmulatorCoreBridge (Cheats)
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled;
- (void)resetCheatCodes;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
