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
@protocol PVGBASystemResponderClient;
typedef enum PVGBAButton: NSInteger PVGBAButton;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVVisualBoyAdvanceBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, PVGBASystemResponderClient>
#pragma clang diagnostic pop

// MARK: - RetroAchievements memory access (GBA bus)

/// EWRAM base (`workRAM`), 256 KiB at bus `0x02000000`, valid while a ROM is loaded.
@property (nonatomic, readonly, nullable) void *ewramBasePtr;
/// IWRAM base (`internalRAM`), 32 KiB at bus `0x03000000`, valid while a ROM is loaded.
@property (nonatomic, readonly, nullable) void *iwramBasePtr;
/// VRAM base, 96 KiB at bus `0x06000000`, valid while a ROM is loaded.
@property (nonatomic, readonly, nullable) void *vbaVramBasePtr;

/// Whether `rc_client` has a game successfully loaded for achievements.
@property (nonatomic, readonly) BOOL achievementsActive;

/// Weak back-reference to the owning Swift core (`PVVisualBoyAdvanceCore`).
@property (nonatomic, weak, nullable) id achievementsEventOwner;

/// Advance the achievement runtime by one frame (calls `rc_client_do_frame` when active).
- (void)tickAchievements;

/// Load the game into `rc_client` using the provided MD5 hash.
- (void)loadAchievementsForGameHash:(NSString *)gameHash
                         completion:(void (^)(BOOL success))completion;

/// Unload the current game from `rc_client` and mark achievements inactive.
- (void)unloadAchievements;

// PVGBASystemResponderClient
- (void)didPushGBAButton:(PVGBAButton)button forPlayer:(NSInteger)player;
- (void)didReleaseGBAButton:(PVGBAButton)button forPlayer:(NSInteger)player;

@end

/// Achievement event callbacks invoked from the `rc_client` event handler.
@interface PVVisualBoyAdvanceBridge (AchievementsEvents)
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

@interface PVVisualBoyAdvanceBridge (Cheats)
- (BOOL)setCheatWithCode:(NSString *)code type:(NSString *)type codeType:(NSString *)codeType cheatIndex:(uint8_t)cheatIndex enabled:(BOOL)enabled;
- (NSArray<NSString *> *)cheatCodeTypes;
- (BOOL)supportsCheatCode;
- (void)resetCheatCodes;
@end
