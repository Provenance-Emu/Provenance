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
@protocol PVGBSystemResponderClient;

typedef enum PVGBButton: NSInteger PVGBButton NS_TYPED_ENUM;
typedef enum GBPalette: NSInteger GBPalette NS_TYPED_ENUM;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVGBEmulatorCoreBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, PVGBSystemResponderClient>
#pragma clang diagnostic pop

@property (nonatomic, readonly) BOOL isGameboyColor;

-(enum GBPalette)currentDisplayMode;
-(void)changeDisplayMode:(NSInteger)displayMode;

// MARK: - RetroAchievements memory access

/// Pointer to WRAM area 0 base (mapped region 0xC000–0xCFFF), valid while a ROM is loaded.
/// Always the fixed bank; 4 KiB per area.
@property (nonatomic, readonly, nullable) void *wramBasePtr;
/// Pointer to WRAM area 1 base (mapped region 0xD000–0xDFFF), valid while a ROM is loaded.
/// On CGB this points to the currently selected switchable bank (changes when the bank register is written).
/// On DMG it points to the upper half of WRAM (second 4 KiB, 0xD000–0xDFFF); not a mirror of area 0.
@property (nonatomic, readonly, nullable) void *wramBank1Ptr;
/// Pointer to the physical start of VRAM data, valid while a ROM is loaded.
/// Index 0 corresponds to GB bus address 0x8000.
/// Total VRAM allocation: 16 KiB (both DMG and GBC). DMG uses only the first 8 KiB bank.
@property (nonatomic, readonly, nullable) void *vramBasePtr;
/// Pre-adjusted VRAM bank pointer for direct address indexing.
/// vramBankPtr[addr] for addr in [0x8000, 0x9FFF] returns the byte for the currently
/// active VRAM bank on CGB (controlled by register FF4F). On DMG always refers to bank 0.
/// Use this instead of vramBasePtr for reads to correctly support CGB VRAM bank switching.
@property (nonatomic, readonly, nullable) void *vramBankPtr;
/// Total WRAM size in bytes: 8192 for DMG, 32768 for GBC.
@property (nonatomic, readonly) NSUInteger wramSize;

/// Whether rc_client has a game successfully loaded for achievements.
@property (nonatomic, readonly) BOOL achievementsActive;

/// Weak back-reference to the owning Swift core (PVGBEmulatorCore).
/// Set by PVGBEmulatorCore at init time so achievement event callbacks
/// can walk back to the RetroAchievementsOSDDelegate.
@property (nonatomic, weak, nullable) id achievementsEventOwner;

/// Advance the achievement runtime by one frame.
/// Called after executeFrame/executeFrameSkippingFrame:.
- (void)tickAchievements;

/// Load the game into rc_client using the provided MD5 hash.
/// Completion fires on an arbitrary queue; forward result to achievementsActive.
/// @param gameHash   MD5 hex string (32 chars) for the ROM.
/// @param completion Called with YES if game loaded successfully.
- (void)loadAchievementsForGameHash:(NSString *)gameHash
                         completion:(void (^)(BOOL success))completion;

/// Unload the current game from rc_client and mark achievements inactive.
- (void)unloadAchievements;

@end

/// Achievement event callbacks, invoked from rc_client event handler.
/// The Swift layer (PVGBEmulatorCore+RetroAchievements) overrides these to
/// forward events to the RetroAchievementsOSDDelegate.
@interface PVGBEmulatorCoreBridge (AchievementsEvents)
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

@interface PVGBEmulatorCoreBridge (Cheats)
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled;
- (void)resetCheatCodes;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
