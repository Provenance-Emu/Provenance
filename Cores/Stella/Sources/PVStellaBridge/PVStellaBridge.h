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
@import PVStellaCPP;
@import PVCoreObjCBridge;

#if !__swift__
@import PVEmulatorCore;
@import PVCoreBridge;
#else
@protocol ObjCBridgedCoreBridge;
@protocol PV2600SystemResponderClient;
@protocol EmulatorCoreVideoDelegate;
typedef enum PV2600Button: NSInteger PV2600Button;
#endif

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

// Callback method to fetch options of NSObject from String
typedef id _Nullable (^PVStellaBridgeOptionHandler)(NSString * _Nonnull option);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
//PVCORE_DIRECT_MEMBERS
@interface PVStellaBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, EmulatorCoreVideoDelegate>
#pragma clang diagnostic pop

-(instancetype)initWithOptionHandler:(PVStellaBridgeOptionHandler) optionHandler NS_DESIGNATED_INITIALIZER;
@property (readonly, nonatomic, copy) PVStellaBridgeOptionHandler optionHandler;

// MARK: Core
- (void)loadFileAtPath:(NSString *)path error:(NSError * __autoreleasing *)error;
- (void)executeFrameSkippingFrame:(BOOL)skip;
- (void)executeFrame;
- (void)swapBuffers;
- (void)stopEmulation;
- (void)resetEmulation;

// MARK: Output
- (CGRect)screenRect;
- (const void *)videoBuffer;
- (NSTimeInterval)frameInterval;
- (BOOL)rendersToOpenGL;

// MARK: - RetroAchievements (rc_client)

/// `RETRO_MEMORY_SYSTEM_RAM`: 128 bytes, achievement bus addresses `0x00`…`0x7F` (rcheevos Atari 2600 map).
@property (nonatomic, readonly, nullable) void *stellaSystemRAMPtr;
@property (nonatomic, readonly) NSUInteger stellaSystemRAMSize;

@property (nonatomic, readonly) BOOL achievementsActive;
@property (nonatomic, weak, nullable) id achievementsEventOwner;

- (void)tickAchievements;
- (void)loadAchievementsForGameHash:(NSString *)gameHash
                         completion:(void (^)(BOOL success))completion;
- (void)unloadAchievements;

// MARK: Input
- (void)pollControllers;

// MARK: Save States
- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *)) __attribute__((noescape)) block;
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *)) __attribute__((noescape)) block;
@end

@interface PVStellaBridge (PV2600SystemResponderClient) <PV2600SystemResponderClient>
- (void)didPushPV2600Button:(PV2600Button)button forPlayer:(NSUInteger)player;
- (void)didReleasePV2600Button:(PV2600Button)button forPlayer:(NSUInteger)player;
@end

@interface PVStellaBridge (AchievementsEvents)
- (void)rcAchievementTriggeredWithID:(uint32_t)achievementID
                               title:(NSString * _Nullable)title
                         description:(NSString * _Nullable)description
                              points:(uint32_t)points
                            badgeURL:(NSURL * _Nullable)badgeURL
                          isHardcore:(BOOL)isHardcore;
- (void)rcAchievementProgressWithID:(uint32_t)achievementID
                              title:(NSString * _Nullable)title
                       progressText:(NSString * _Nullable)progressText;
- (void)rcLeaderboardStartedWithID:(uint32_t)leaderboardID
                             title:(NSString * _Nullable)title
                       description:(NSString * _Nullable)description
                         scoreText:(NSString * _Nullable)scoreText;
- (void)rcLeaderboardFailedWithID:(uint32_t)leaderboardID;
- (void)rcLeaderboardSubmittedWithID:(uint32_t)leaderboardID
                               title:(NSString * _Nullable)title
                         description:(NSString * _Nullable)description
                           scoreText:(NSString * _Nullable)scoreText;
@end

// MARK: - Trackball / Mouse input (Companion Controller)

/// Trackball and mouse input methods used by the Companion Controller bridge.
/// The Stella libretro core reads these values via `RETRO_DEVICE_MOUSE` during
/// the `input_state_callback`. Deltas are consumed (zeroed) after each poll.
@interface PVStellaBridge (Trackball)

/// Accumulate a relative trackball movement delta.
/// Thread-safe: may be called from the main thread while the emulation thread
/// polls via `input_state_callback`.
/// @param deltaX  Horizontal delta, typically in the range -1.0…1.0.
/// @param deltaY  Vertical delta, typically in the range -1.0…1.0.
- (void)setTrackballDeltaX:(float)deltaX deltaY:(float)deltaY;

/// Set the left mouse / fire button state.
/// @param pressed `YES` when the fire button is held down.
- (void)setMouseButtonLeft:(BOOL)pressed;

@end

@interface PVStellaBridge (Cheats)
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled error:(NSError **)error;
- (void)resetCheatCodes;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
