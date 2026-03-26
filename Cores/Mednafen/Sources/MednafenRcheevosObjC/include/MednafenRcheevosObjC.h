//
//  MednafenRcheevosObjC.h
//  MednafenRcheevosObjC
//
//  Objective-C interface for the Mednafen rc_client bridge.
//
//  This header is the only public surface exposed to the Swift layer
//  (MednafenGameCore).  All rc_client C types stay behind the .mm file.
//

#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: - Delegate protocol

/// Receives RetroAchievements events from the rcheevos runtime.
/// Methods are called on an unspecified thread; forward to the main thread for UI.
@protocol MednafenRcheevosDelegate <NSObject>
@optional

- (void)rcheevosDidUnlockAchievementID:(uint32_t)achievementID
                                 title:(NSString *)title
                           description:(NSString *)description
                                points:(uint32_t)points
                            isHardcore:(BOOL)hardcore;

- (void)rcheevosShowProgressForAchievementID:(uint32_t)achievementID
                                       title:(NSString *)title
                                progressText:(NSString *)progressText;

- (void)rcheevosShowChallengeForAchievementID:(uint32_t)achievementID;

- (void)rcheevosHideChallengeForAchievementID:(uint32_t)achievementID;

- (void)rcheevosLeaderboardStartedWithID:(uint32_t)leaderboardID
                                   title:(NSString *)title
                             description:(NSString *)description
                               scoreText:(NSString *)scoreText;

- (void)rcheevosLeaderboardFailedWithID:(uint32_t)leaderboardID;

- (void)rcheevosLeaderboardSubmittedWithID:(uint32_t)leaderboardID
                                     title:(NSString *)title
                               description:(NSString *)description
                                 scoreText:(NSString *)scoreText;
@end

// MARK: - Memory region descriptor

/// Maps a range of rcheevos address space onto a pointer into emulator RAM.
typedef struct {
    /// Base address in the rcheevos flat address space for this system
    /// (e.g. 0x7E0000 for SNES WRAM, 0x00000000 for PSX Main RAM).
    uint32_t rcAddress;
    /// Direct pointer into emulator RAM (must remain valid for the session lifetime).
    uint8_t *ptr;
    /// Size of this region in bytes.
    uint32_t size;
} MednafenRcheevosRegion;

// MARK: - Client

/// Manages a single rc_client_t instance for the Mednafen emulator core.
///
/// Lifecycle:
///   1. Create once per game session.
///   2. Call -setRegions:count: after emulator memory is mapped.
///   3. Call -loginAndLoadGame:completion: to authenticate and start the session.
///   4. Call -doFrame every emulated frame while the game is running.
///   5. Call -unloadGame when emulation stops or a new game is loaded.
///   6. Release the object to destroy the rc_client.
///
/// Thread safety:
///   -doFrame must be called from the emulator thread.
///   -loginAndLoadGame: and -unloadGame may be called from any thread.
///   Delegate callbacks are dispatched to the main queue.
@interface MednafenRcheevosClient : NSObject

/// Receives unlock / progress / challenge / leaderboard events.
@property (nonatomic, weak, nullable) id<MednafenRcheevosDelegate> delegate;

/// YES after a game has been successfully loaded via -loginAndLoadGame:completion:.
@property (nonatomic, readonly) BOOL isGameLoaded;

/// Register the memory regions rcheevos will read when evaluating conditions.
/// Must be called before -loginAndLoadGame:completion:.
/// @param regions  Array of MednafenRcheevosRegion descriptors.
/// @param count    Number of elements in @p regions.
- (void)setRegions:(const MednafenRcheevosRegion *)regions count:(NSUInteger)count;

/// Authenticate with stored credentials and load the game hash.
///
/// Reads `ra_username` / `ra_session_token` from NSUserDefaults (written by
/// PVCheevos's RetroCredentialsManager).  On success sets isGameLoaded = YES
/// and invokes the completion block on the main queue.
///
/// @param md5Hash  Lowercase hex MD5 of the ROM file.
/// @param completion  Called with (YES, nil) on success or (NO, errorMessage) on failure.
- (void)loginAndLoadGame:(NSString *)md5Hash
              completion:(void (^)(BOOL success, NSString *_Nullable errorMessage))completion;

/// Tear down the current game session.  Safe to call if no game is loaded.
- (void)unloadGame;

/// Advance the rcheevos runtime by one emulated frame.
/// Reads memory via the registered regions and fires delegate callbacks on events.
/// Must be called from the emulator thread (typically inside executeFrame).
- (void)doFrame;

@end

NS_ASSUME_NONNULL_END
