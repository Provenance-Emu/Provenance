//
//  PVMupen64PlusNXCore.h
//  PVMupen64Plus-NX
//
//  Created by Joseph Mattiello on 10/20/21.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
@import PVCoreObjCBridge;
#import <PVCoreBridgeRetro/PVCoreBridgeRetro.h>
#import <PVLibRetro/PVLibRetroGLESCore.h>

#define GET_CURRENT_AND_RETURN(...) __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;
#define GET_CURRENT_OR_RETURN(...)  __strong __typeof__(_current) current = _current; if(current == nil) return __VA_ARGS__;

@protocol PVN64SystemResponderClient;

__attribute__((visibility("default")))
@interface PVMupen64PlusNXCore : PVLibRetroGLESCoreBridge <PVN64SystemResponderClient> {
//	uint8_t padData[4][PVDOSButtonCount];
//	int8_t xAxis[4];
//	int8_t yAxis[4];
//	//    int videoWidth;
//	//    int videoHeight;
//	//    int videoBitDepth;
//	int videoDepthBitDepth; // eh
//
//	float sampleRate;
//
//	BOOL isNTSC;
//@public
//    dispatch_queue_t _callbackQueue;

@public
    /// GB/GBC ROM paths mounted in each Transfer Pak slot (index 0-3, nil = empty).
    NSString * __nullable gbCartROMPath[4];
    /// GB/GBC save (RAM) paths for each Transfer Pak slot (nil = let core auto-manage).
    NSString * __nullable gbCartSavePath[4];
    /// C-string copies owned by this object, valid for the core session lifetime.
    /// The m64p_media_loader callbacks return char* that must stay valid between calls.
    char * __nullable _gbCartROMCStr[4];
    char * __nullable _gbCartSaveCStr[4];
}

/// Sets or clears the GB/GBC cartridge in a Transfer Pak slot (port 0–3).
/// Pass nil for romPath to remove the cartridge from the slot.
- (void)setGBCartROMPath:(nullable NSString *)romPath
               savePath:(nullable NSString *)savePath
                forPort:(NSInteger)port;

/// Returns the GB ROM path currently mounted in the given Transfer Pak port, or nil.
- (nullable NSString *)gbCartROMPathForPort:(NSInteger)port;

/// Returns the GB save path currently mounted in the given Transfer Pak port, or nil.
- (nullable NSString *)gbCartSavePathForPort:(NSInteger)port;

/// Sets the controller pak plugin mode for the given controller port (0-based).
/// PLUGIN_NONE=1, PLUGIN_MEMPAK=2, PLUGIN_RUMBLE_PAK=3, PLUGIN_TRANSFER_PAK=4, PLUGIN_RAW=5
- (void)setMode:(NSInteger)mode forController:(NSInteger)controller;

@end
