//
//  PVTGBDualCore.h
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

@import Foundation;
@import PVCoreObjCBridge;
#define TGBDUAL_PITCH_SHIFT  1
#define NUMBER_OF_PADS       2
#define NUMBER_OF_PAD_INPUTS 16

@protocol ObjCBridgedCoreBridge;
@protocol PVGBSystemResponderClient;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVTGBDualBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, PVGBSystemResponderClient>
#pragma clang diagnostic pop
{
  uint16_t _gb_pad[NUMBER_OF_PADS][NUMBER_OF_PAD_INPUTS];
  uint16_t *_videoBuffer;
}
@property (nonatomic, assign, nullable) uint16_t *videoBuffer;
@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) BOOL forceMonochromatic;


// MARK: Core
- (BOOL)loadFileAtPath:(NSString *_Nullable)path error:(NSError * _Nullable __autoreleasing *_Nullable)error;
- (void)executeFrameSkippingFrame:(BOOL)skip;
- (void)executeFrame;
- (void)swapBuffers;
- (void)stopEmulation;
- (void)resetEmulation;

// MARK: Output
- (CGRect)screenRect;
- (const void *_Nullable)videoBuffer;
- (NSTimeInterval)frameInterval;
- (BOOL)rendersToOpenGL;

// MARK: Input
- (void)pollControllers;

// MARK: Save States
- (void)saveStateToFileAtPath:(NSString *_Nullable)fileName completionHandler:(void (^_Nullable)(BOOL, NSError *_Nullable)) __attribute__((noescape)) block;
- (void)loadStateFromFileAtPath:(NSString *_Nullable)fileName completionHandler:(void (^_Nullable)(BOOL, NSError *_Nullable)) __attribute__((noescape)) block;

// MARK: RetroAchievements
/// Pointer to GB/GBC work RAM via libretro RETRO_MEMORY_SYSTEM_RAM (DMG: 8 KiB, GBC: 32 KiB).
@property (nonatomic, readonly, nullable) void *wramBasePtr;
/// Size of work RAM exposed via RETRO_MEMORY_SYSTEM_RAM (in bytes).
@property (nonatomic, readonly) NSUInteger wramSize;
/// Pointer to GB/GBC video RAM via libretro RETRO_MEMORY_VIDEO_RAM (DMG: 8 KiB, GBC: 16 KiB).
@property (nonatomic, readonly, nullable) void *vramBasePtr;
/// Size of video RAM exposed via RETRO_MEMORY_VIDEO_RAM (in bytes).
@property (nonatomic, readonly) NSUInteger vramSize;
@end
