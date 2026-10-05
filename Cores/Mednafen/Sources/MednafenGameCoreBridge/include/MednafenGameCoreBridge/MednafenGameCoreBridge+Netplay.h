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
    PVMednafenNetplayErrorAlreadyActive   = 2,
    PVMednafenNetplayErrorInvalidSettings = 3,
    /// The embedded server could not start (port in use, no network, …).
    PVMednafenNetplayErrorServerFailed    = 6,
};

/// Netplay connection state for the Mednafen engine.
typedef NS_ENUM(NSInteger, PVMednafenNetplayStatus) {
    /// No netplay session is active.
    PVMednafenNetplayStatusIdle         = 0,
    /// Logged in to the server and exchanging input every frame.
    PVMednafenNetplayStatusConnected    = 1,
    /// A connection was requested but is not established yet. It is made on
    /// the emulation thread, so it waits while the game is paused.
    PVMednafenNetplayStatusConnecting   = 2,
    /// The connection failed or was lost (not closed by
    /// `-netplayDisconnect`). `mednafenNetplayLastMessage` says why.
    PVMednafenNetplayStatusDisconnected = 3,
};

/// Netplay category on MednafenGameCoreBridge.
///
/// Mednafen netplay is client/server: every player, the host included, is a
/// client of a `mednafen-server`. Provenance embeds that server, so:
///
/// Host:
///   1. `+startNetplayServerOnPort:…` runs the server on its own thread.
///   2. `-netplayConnectToHost:@"127.0.0.1" port:…` joins it.
///   3. Other players connect to this device's LAN address and the same port.
///
/// Join:
///   1. `-netplayConnectToHost:<host LAN address> port:…`.
///
/// Every player must run the same game (same MD5) on the same Mednafen build.
///
/// Threading: connect and disconnect requests are queued and carried out on
/// the emulation thread at the start of the next frame, because Mednafen's
/// netplay state is only safe to touch from there.
@interface MednafenGameCoreBridge (Netplay)

/// Current Mednafen netplay connection state. Safe from any thread.
@property (nonatomic, readonly) PVMednafenNetplayStatus mednafenNetplayStatus;

/// The most recent netplay message from Mednafen or the server (errors
/// included), or nil. Safe from any thread.
@property (nonatomic, readonly, nullable, copy) NSString *mednafenNetplayLastMessage;

/// Whether the Mednafen binary in this build was compiled with netplay support.
///
/// Always `YES` — Mednafen's netplay.cpp is always compiled in Provenance builds.
@property (nonatomic, readonly) BOOL mednafenNetplaySupported;

/// Request a connection to a Mednafen netplay server.
///
/// Sets `netplay.host`, `netplay.port`, `netplay.nick`, `netplay.password`
/// (the server password), `netplay.localplayers` and an empty
/// `netplay.gamekey`, then calls `MDFNI_NetplayConnect()` — on the
/// emulation thread, at the start of the next frame.
///
/// @param host       Server hostname or IP address.
/// @param port       Server port.
/// @param nickname   Display name visible to all peers.
/// @param password   Server password (empty string for none).
/// @param spectator  YES to take no controller (`netplay.localplayers` = 0).
/// @param error      On failure, set to a `PVMednafenNetplayErrorDomain` error.
/// @return `YES` if the request was queued. Failures after that show up as
///         `PVMednafenNetplayStatusDisconnected`.
- (BOOL)netplayConnectToHost:(NSString *)host
                        port:(uint16_t)port
                    nickname:(NSString *)nickname
                    password:(NSString *)password
                   spectator:(BOOL)spectator
                       error:(NSError *__autoreleasing _Nullable *)error;

/// Disconnect from the current Mednafen netplay session.
///
/// Returns at once. A frame blocked waiting for network data is aborted, and
/// the disconnect itself happens on the emulation thread.
- (void)netplayDisconnect;

// MARK: - Embedded server (host)

/// Start the embedded `mednafen-server` listening on `port` (IPv4 and IPv6).
///
/// There is one server per process. Returns once the server is listening.
/// @param port        TCP port.
/// @param password    Server password; nil or empty for none.
/// @param maxClients  Maximum simultaneous connections, the host included.
/// @param error       On failure (port in use, …), a `PVMednafenNetplayErrorServerFailed` error.
+ (BOOL)startNetplayServerOnPort:(uint16_t)port
                        password:(nullable NSString *)password
                      maxClients:(NSInteger)maxClients
                           error:(NSError *__autoreleasing _Nullable *)error;

/// Stop the embedded server and wait for its thread to exit. Closes every
/// player's connection. No-op if it isn't running.
+ (void)stopNetplayServer;

/// Whether the embedded server is running.
@property (class, nonatomic, readonly) BOOL netplayServerRunning;

/// Players in the embedded server's most populated game, the host included
/// once logged in. A player with a different game (MD5) is in a separate game.
@property (class, nonatomic, readonly) NSInteger netplayServerPlayerCount;

@end

NS_ASSUME_NONNULL_END
