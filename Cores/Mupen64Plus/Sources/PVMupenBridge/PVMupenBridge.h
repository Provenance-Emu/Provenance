/*
 Copyright (c) 2010, OpenEmu Team

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
@import GameController;
@import PVCoreObjCBridge;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

// Forward Declerations (until I can fix importing PVCoreBridge in ObjC
//const NSInteger PVN64ButtonCount = 19;
@protocol ObjCBridgedCoreBridge;
@protocol PVN64SystemResponderClient;
typedef enum PVN64Button: NSInteger PVN64Button;

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVMupenBridge : PVCoreObjCBridge <ObjCBridgedCoreBridge, PVN64SystemResponderClient>
#pragma clang diagnostic pop
{
//@private
    @public
    uint8_t padData[4][19];
    int8_t xAxis[4];
    int8_t yAxis[4];

    int controllerMode[4];
    NSOperationQueue * __nonnull _inputQueue;

    /// GB/GBC ROM paths mounted in each Transfer Pak slot (index 0-3, nil = empty).
    NSString * __nullable gbCartROMPath[4];
    /// GB/GBC save (RAM) paths for each Transfer Pak slot (nil = let core auto-manage).
    NSString * __nullable gbCartSavePath[4];

    /// C-string copies owned by this object for the lifetime of the core session.
    /// The m64p_media_loader callbacks must return a char* that stays valid; we
    /// store these here so the GC / ARC doesn't collect them between calls.
    char * __nullable _gbCartROMCStr[4];
    char * __nullable _gbCartSaveCStr[4];

    /// Virtual memory pak buffers used in PLUGIN_RAW (Smart Pak) mode.
    /// Each controller port gets 32KB of SRAM matching the real N64 memory pak.
    /// Addresses 0x0000–0x7FFF (32 bytes per access = 1024 blocks).
    uint8_t mempakBuffer[4][0x8000];

    /// Dirty flags: set when a write to a pak buffer has not yet been flushed to disk.
    BOOL mempakDirty[4];
}

@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) int videoBitDepth;

@property (nonatomic, assign) double mupenSampleRate;
@property (nonatomic, assign) int videoDepthBitDepth;
@property (nonatomic, assign) BOOL isNTSC;
@property (nonatomic, assign) BOOL dualJoystick;

- (void) videoInterrupt;
- (void) setMode:(NSInteger)mode forController:(NSInteger)controller;

/// Sets or clears the GB/GBC cartridge in a Transfer Pak slot (port 0-3).
/// Pass nil romPath to remove the cartridge from the slot.
- (void) setGBCartROMPath:(nullable NSString *)romPath
                 savePath:(nullable NSString *)savePath
                  forPort:(NSInteger)port;

/// Returns the GB ROM path currently mounted in the given Transfer Pak port, or nil.
- (nullable NSString *) gbCartROMPathForPort:(NSInteger)port;

/// Returns the GB save path currently mounted in the given Transfer Pak port, or nil.
- (nullable NSString *) gbCartSavePathForPort:(NSInteger)port;

- (void) swapBuffers;

/// Load virtual mempak data from disk into the in-memory buffer for the given port (0–3).
/// Called at game start. Silently succeeds if no file exists (fresh pak).
- (void) loadMempakForPort:(NSInteger)port;

/// Persist the in-memory mempak buffer for the given port (0–3) to disk.
/// Only writes if the dirty flag is set.
- (void) saveMempakForPort:(NSInteger)port;

/// Save all dirty mempak buffers to disk. Call on pause/stop.
- (void) saveAllMempaks;

@end

extern __weak PVMupenBridge * __nullable _current;

NS_HEADER_AUDIT_END(nullability, sendability)
