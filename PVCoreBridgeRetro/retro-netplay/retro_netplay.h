//
//  retro_netplay.h
//  retro-netplay
//
//  Created by Joseph Mattiello on 8/1/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for RetroArch netplay errors.
extern NSErrorDomain const PVRetroArchNetplayErrorDomain;

typedef NS_ERROR_ENUM(PVRetroArchNetplayErrorDomain, PVRetroArchNetplayError) {
    /// RetroArch runtime is not active.
    PVRetroArchNetplayErrorNotRunning = 1,
    /// A netplay session is already active.
    PVRetroArchNetplayErrorAlreadyActive = 2,
    /// The provided settings were invalid.
    PVRetroArchNetplayErrorInvalidSettings = 3,
    /// The RetroArch command bus rejected the request.
    PVRetroArchNetplayErrorCommandFailed = 4,
};

/// Current netplay session status returned by -sessionStatus.
typedef NS_ENUM(NSInteger, PVRetroArchNetplayStatus) {
    PVRetroArchNetplayStatusIdle = 0,
    PVRetroArchNetplayStatusHosting,
    PVRetroArchNetplayStatusConnected,
    PVRetroArchNetplayStatusSpectating,
};

/// Thin ObjC bridge that wires the Provenance Swift netplay stack to
/// RetroArch's C-level netplay engine (compiled with HAVE_NETPLAY).
///
/// Call from Swift via PVRetroArchCoreBridge+Netplay.swift.
@interface PVRetroArchNetplayBridge : NSObject

/// Shared bridge; corresponds to the running RetroArch singleton.
+ (instancetype)shared;

// MARK: - Host

/// Start hosting a RetroArch netplay room.
/// @param nickname  Display name shown to peers.
/// @param port      UDP port to listen on (default 55435).
/// @param frameDelay  Number of input-delay frames (0 = pure rollback).
/// @param maxPlayers  Maximum number of players (used in Bonjour TXT record).
/// @param error     Set on failure.
/// @return YES on success.
- (BOOL)startHostingWithNickname:(NSString *)nickname
                            port:(uint16_t)port
                      frameDelay:(int)frameDelay
                      maxPlayers:(int)maxPlayers
                           error:(NSError *__autoreleasing _Nullable *)error;

// MARK: - Join

/// Connect to a remote RetroArch netplay host.
/// @param hostname  Host IP address or hostname.
/// @param port      UDP port the host is listening on.
/// @param nickname  Display name shown to peers.
/// @param frameDelay  Number of input-delay frames.
/// @param spectate  YES to connect as spectator only.
/// @param error     Set on failure.
/// @return YES on success.
- (BOOL)connectToHost:(NSString *)hostname
                 port:(uint16_t)port
             nickname:(NSString *)nickname
           frameDelay:(int)frameDelay
             spectate:(BOOL)spectate
                error:(NSError *__autoreleasing _Nullable *)error;

// MARK: - Disconnect

/// Stop the current netplay session (host or client).
- (void)stopNetplay;

// MARK: - Status

/// Query the current netplay status.
- (PVRetroArchNetplayStatus)currentStatus;

/// Flip player assignments (P1 ↔ P2).
- (void)flipPlayers;

@end

NS_ASSUME_NONNULL_END
