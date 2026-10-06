//
//  PVDolphinCore+Netplay.h
//  PVDolphin
//
//  Created by Joseph Mattiello on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  ObjC category on PVDolphinCoreBridge that exposes Dolphin's built-in
//  netplay to the Provenance netplay infrastructure.
//
//  Dolphin netplay model:
//    - Hosting:   start a NetPlayServer, then join it as player 1 over
//                 127.0.0.1 with a NetPlayClient.
//    - Joining:   create a NetPlayClient pointing at the host's IP:port.
//    - Traversal: host and client meet through Dolphin's public relay
//                 (stun.dolphin-emu.org:6262, alt 6226). The host gets a
//                 short code from the relay; clients join with that code
//                 instead of an address.
//
//  Every player boots the game together: the host asks the server to start
//  (`requestDolphinNetplayGameStart:`), and every player, the host included,
//  reboots the running core into the netplay session. When the netplay game
//  ends, the core boots the loaded ROM again on its own.
//
//  Not supported by this Dolphin revision: room passwords and a player cap.
//  Both are accepted for API symmetry and ignored.
//

#pragma once
#import <Foundation/Foundation.h>
#import <PVDolphin/PVDolphinCore.h>

NS_ASSUME_NONNULL_BEGIN

// ---------------------------------------------------------------------------
// MARK: - Status enum
// ---------------------------------------------------------------------------

/// Current lifecycle state of the Dolphin netplay session.
typedef NS_ENUM(NSInteger, PVDolphinNetplayStatus) {
    /// No active session; engine is idle.
    PVDolphinNetplayStatusIdle = 0,
    /// This instance is hosting a session (its own client is joined to it).
    PVDolphinNetplayStatusHosting = 1,
    /// Connected to a remote host as a client.
    PVDolphinNetplayStatusConnected = 2,
};

/// Asynchronous session events reported by Dolphin's netplay thread.
typedef NS_ENUM(NSInteger, PVDolphinNetplayEvent) {
    /// The connection to the host (or the host's own server) dropped.
    PVDolphinNetplayEventConnectionLost = 0,
    /// The client could not connect or was rejected; `message` has the reason.
    PVDolphinNetplayEventConnectionError = 1,
    /// Players' emulation diverged; `message` names the player and frame.
    PVDolphinNetplayEventDesync = 2,
    /// The traversal relay assigned this host a code; `message` is the code.
    PVDolphinNetplayEventTraversalCodeReady = 3,
    /// The traversal relay could not be reached; `message` has the reason.
    PVDolphinNetplayEventTraversalFailed = 4,
    /// A player joined or left; `message` is the player's name.
    PVDolphinNetplayEventPlayersChanged = 5,
};

/// Receives `PVDolphinNetplayEvent`s. Always called on the main queue.
typedef void (^PVDolphinNetplayEventHandler)(PVDolphinNetplayEvent event, NSString * _Nullable message);

// ---------------------------------------------------------------------------
// MARK: - Error domain
// ---------------------------------------------------------------------------

extern NSErrorDomain const PVDolphinNetplayErrorDomain;

typedef NS_ERROR_ENUM(PVDolphinNetplayErrorDomain, PVDolphinNetplayError) {
    /// Netplay is not compiled into this binary (dolphin-ios submodule absent).
    PVDolphinNetplayErrorUnsupported      = 0,
    /// A session is already active; call stopNetplay first.
    PVDolphinNetplayErrorAlreadyActive    = 1,
    /// The connection attempt failed (C++ exception or handshake error).
    PVDolphinNetplayErrorConnectFailed    = 2,
    /// Required parameters (host / traversal code) are missing or invalid.
    PVDolphinNetplayErrorInvalidSettings  = 3,
    /// Some player in the session doesn't have the host's game.
    PVDolphinNetplayErrorGameMismatch     = 4,
};

// ---------------------------------------------------------------------------
// MARK: - Netplay category
// ---------------------------------------------------------------------------

@interface PVDolphinCoreBridge (Netplay)

/// YES when the Dolphin netplay subsystem is compiled into this binary.
///
/// Returns NO in simulator builds or when the dolphin-ios submodule has not
/// been initialised.
@property (nonatomic, readonly) BOOL dolphinNetplaySupported;

/// Current netplay status — idle, hosting, or connected as a client.
@property (nonatomic, readonly) PVDolphinNetplayStatus dolphinNetplayStatus;

/// The traversal code the relay assigned to this host.
///
/// Nil until the relay answers, and always nil for direct-IP sessions.
/// `PVDolphinNetplayEventTraversalCodeReady` fires when it becomes available.
@property (nonatomic, readonly, nullable) NSString *dolphinTraversalCode;

/// Number of players in the session, the local player included. 0 when idle.
@property (nonatomic, readonly) NSInteger dolphinNetplayPlayerCount;

/// Receives session events. Captured when a session starts, so set it before
/// calling `startNetplayHostOnPort:…` or `joinNetplayHost:…`.
@property (nonatomic, copy, nullable) PVDolphinNetplayEventHandler dolphinNetplayEventHandler;

/// Extra game files Dolphin may match against the host's game, beyond the ROM
/// that is loaded now (which is always a candidate). Captured when a session
/// starts.
@property (nonatomic, copy, nullable) NSArray<NSString *> *dolphinNetplayCandidateGamePaths;

/// Start a Dolphin NetPlayServer and join it as player 1, then select the
/// loaded game on the server.
///
/// @param port         Listen port. 0 selects 2626 for direct sessions and a
///                     random port for traversal sessions.
/// @param password     Ignored: this Dolphin revision has no room passwords.
/// @param maxPlayers   Ignored: this Dolphin revision has no player cap.
/// @param useTraversal YES registers with Dolphin's traversal relay so clients
///                     can join by code (see `dolphinTraversalCode`).
/// @param error        Populated on failure.
/// @return YES on success; NO on failure.
- (BOOL)startNetplayHostOnPort:(uint16_t)port
                      password:(nullable NSString *)password
                    maxPlayers:(NSInteger)maxPlayers
                  useTraversal:(BOOL)useTraversal
                         error:(NSError *_Nullable __autoreleasing *_Nullable)error
NS_SWIFT_NAME(startNetplayHost(onPort:password:maxPlayers:useTraversal:));

/// Join an existing session by direct IP:port.
///
/// To connect via Dolphin's traversal relay instead, pass a non-empty
/// `traversalCode` (the host's relay code) and leave `host` empty.
///
/// @param host           Host IP address for direct connect (ignored when traversalCode is set).
/// @param port           Host port. 0 selects 2626. Ignored for traversal.
/// @param traversalCode  Dolphin traversal code for relay-based connect.  Pass nil for direct IP.
/// @param password       Ignored: this Dolphin revision has no room passwords.
/// @param error          Populated on failure.
/// @return YES on success; NO on failure.
- (BOOL)joinNetplayHost:(NSString *)host
                   port:(uint16_t)port
          traversalCode:(nullable NSString *)traversalCode
               password:(nullable NSString *)password
                  error:(NSError *_Nullable __autoreleasing *_Nullable)error
NS_SWIFT_NAME(joinNetplay(host:port:traversalCode:password:));

/// Stop any active server and/or client.  Safe to call when already idle.
/// Blocks until Dolphin's netplay threads have exited; never call it from a
/// netplay callback.
- (void)stopNetplay;

/// Host only: start the selected game for every player. Pins the CPU core to
/// an interpreter and turns off dual core, DSP JIT and fastmem for the
/// session first, so a JIT host can't hand a jitless player a core it can't
/// run. Every player then reboots into the netplay game.
///
/// @param error  `PVDolphinNetplayErrorGameMismatch` when a player lacks the
///               game; `InvalidSettings` when not hosting.
/// @return YES once the start is under way (it may still wait on save sync).
- (BOOL)requestDolphinNetplayGameStart:(NSError *_Nullable __autoreleasing *_Nullable)error
NS_SWIFT_NAME(requestDolphinNetplayGameStart());

/// Set the pad buffer (input delay, in frames).
///
/// Host: applied to the running server, which sends it to every client, and
/// stored as Config::NETPLAY_BUFFER_SIZE. Client: stored as
/// Config::NETPLAY_CLIENT_BUFFER_SIZE only, because the host dictates the
/// buffer outside host-input-authority mode. Both are written to the
/// "current" Config layer, so nothing is persisted to the INI on disk.
///
/// @param bufferSize  Frames to buffer (0–127; larger values are clamped).
- (void)setNetplayInputBufferSize:(uint32_t)bufferSize
NS_SWIFT_NAME(setNetplayInputBufferSize(_:));

@end

NS_ASSUME_NONNULL_END
