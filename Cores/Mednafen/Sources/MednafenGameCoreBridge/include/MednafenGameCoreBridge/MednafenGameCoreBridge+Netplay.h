//
//  MednafenGameCoreBridge+Netplay.h
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#pragma once

#import <MednafenGameCoreBridge/_MednafenGameCoreBridge.h>

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const PVMednafenNetplayErrorDomain;

typedef NS_ERROR_ENUM(PVMednafenNetplayErrorDomain, PVMednafenNetplayError) {
    PVMednafenNetplayErrorNotRunning      = 1,
    PVMednafenNetplayErrorAlreadyActive   = 2,
    PVMednafenNetplayErrorInvalidSettings = 3,
    PVMednafenNetplayErrorConnectFailed   = 4,
    PVMednafenNetplayErrorNoGame          = 5,
};

/// Netplay connection state for the Mednafen engine.
typedef NS_ENUM(NSInteger, PVMednafenNetplayStatus) {
    /// No netplay session is active.
    PVMednafenNetplayStatusIdle       = 0,
    /// Connected and actively syncing frames with peers.
    PVMednafenNetplayStatusConnected  = 1,
};

/// Netplay category on MednafenGameCoreBridge.
///
/// Wraps Mednafen's settings-driven `MDFNI_NetplayConnect` / `MDFNI_NetplayDisconnect`
/// C++ API. Mednafen's model requires a running `mednafen-server` instance — either
/// on the local host (for LAN "host" mode) or on a remote machine (for WAN play).
///
/// LAN "host" flow:
///   1. Launch a local `mednafen-server` process (or use the built-in server stub).
///   2. Call `-netplayConnectToHost:@"127.0.0.1" port:4046 nickname:... password:...`.
///   3. Share your LAN IP so other players can join.
///
/// LAN "client" flow:
///   1. Call `-netplayConnectToHost:<host-LAN-IP> port:4046 nickname:... password:...`.
@interface MednafenGameCoreBridge (Netplay)

/// Current Mednafen netplay connection state.
@property (nonatomic, readonly) PVMednafenNetplayStatus mednafenNetplayStatus;

/// Whether the Mednafen binary in this build was compiled with netplay support.
///
/// Always `YES` — Mednafen's netplay.cpp is always compiled in Provenance builds.
@property (nonatomic, readonly) BOOL mednafenNetplaySupported;

/// Connect to a Mednafen netplay server.
///
/// Configures `netplay.host`, `netplay.port`, `netplay.nick`, `netplay.gamekey`
/// settings and calls `MDFNI_NetplayConnect()`.
///
/// @param host       Server hostname or IP address.
/// @param port       Server port (Mednafen default: 4046).
/// @param nickname   Display name visible to all peers.
/// @param password   Game key / password (empty string for no password).
/// @param error      On failure, set to a `PVMednafenNetplayErrorDomain` error.
/// @return `YES` if the connection handshake was initiated without error.
- (BOOL)netplayConnectToHost:(NSString *)host
                        port:(uint16_t)port
                    nickname:(NSString *)nickname
                    password:(NSString *)password
                       error:(NSError *__autoreleasing _Nullable *)error;

/// Disconnect from the current Mednafen netplay session.
- (void)netplayDisconnect;

@end

NS_ASSUME_NONNULL_END
