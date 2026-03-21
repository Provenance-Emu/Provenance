//
//  PVRetroArchCoreBridge+Netplay.h
//  PVRetroArch
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#pragma once

#import "PVRetroArchCoreBridge.h"

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const PVRetroArchNetplayErrorDomain;

typedef NS_ERROR_ENUM(PVRetroArchNetplayErrorDomain, PVRetroArchNetplayError) {
    PVRetroArchNetplayErrorNotRunning     = 1,
    PVRetroArchNetplayErrorAlreadyActive  = 2,
    PVRetroArchNetplayErrorInvalidSettings = 3,
    PVRetroArchNetplayErrorCommandFailed   = 4,
};

typedef NS_ENUM(NSInteger, PVRetroArchNetplayStatus) {
    PVRetroArchNetplayStatusIdle        = 0,
    PVRetroArchNetplayStatusHosting     = 1,
    PVRetroArchNetplayStatusConnected   = 2,
    PVRetroArchNetplayStatusSpectating  = 3,
};

/// Netplay category on the main RetroArch bridge.
///
/// These methods are backed by RetroArch's HAVE_NETPLAY C engine and call
/// `command_event(CMD_EVENT_NETPLAY_*)` to start/stop sessions.
@interface PVRetroArchCoreBridge (Netplay)

/// Returns YES when this binary was compiled with HAVE_NETPLAY support.
/// Use this to gate UI and bridge registration rather than assuming netplay is always available.
@property (nonatomic, readonly) BOOL netplaySupported;

/// Current netplay session status.
@property (nonatomic, readonly) PVRetroArchNetplayStatus netplayStatus;

/// Start hosting a RetroArch netplay room.
/// @param nickname     Display name shown to peers.
/// @param port         UDP port to listen on (default 55435).
/// @param frameDelay   Input-delay frames (0 = pure rollback).
/// @param error        Set on failure.
/// @return YES on success.
- (BOOL)netplayStartHostingWithNickname:(NSString *)nickname
                                   port:(uint16_t)port
                             frameDelay:(int)frameDelay
                                  error:(NSError *__autoreleasing _Nullable *)error;

/// Connect to a remote RetroArch netplay host.
/// @param hostname     Host IP address or hostname.
/// @param port         UDP port the host is listening on.
/// @param nickname     Display name shown to peers.
/// @param frameDelay   Input-delay frames.
/// @param spectate     YES to connect as spectator only.
/// @param error        Set on failure.
/// @return YES on success.
- (BOOL)netplayConnectToHost:(NSString *)hostname
                        port:(uint16_t)port
                    nickname:(NSString *)nickname
                  frameDelay:(int)frameDelay
                    spectate:(BOOL)spectate
                       error:(NSError *__autoreleasing _Nullable *)error;

/// Stop the current netplay session.
- (void)netplayStop;

/// Flip player assignments (P1 ↔ P2).
- (void)netplayFlipPlayers;

@end

NS_ASSUME_NONNULL_END
