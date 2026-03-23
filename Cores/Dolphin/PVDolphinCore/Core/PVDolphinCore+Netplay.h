//
//  PVDolphinCore+Netplay.h
//  PVDolphin
//
//  Created by Joseph Mattiello on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  ObjC category on PVDolphinCoreBridge that exposes Dolphin's built-in
//  netplay capabilities to the Provenance netplay infrastructure.
//
//  Dolphin netplay model:
//    - Hosting:   start a local NetPlayServer on a given port, then connect
//                 locally as the first player via NetPlayClient.
//    - Joining:   create a NetPlayClient pointing to the host's IP:port.
//    - Traversal: connect via Dolphin's public relay server
//                 (stun.dolphin-emu.org:6262) using the host's traversal code
//                 instead of a direct IP address.
//
//  Currently exposed Dolphin netplay capabilities:
//    - Direct IP and traversal-based hosting/joining
//    - Per-session password protection (host side)
//    - Input buffer size / frame delay (Config::NETPLAY_INPUT_BUFFER_SIZE)
//    - Traversal code query after hosting
//
//  Pending wiring (not yet active):
//    - Max-player enforcement on the server (requires NetPlayServer API confirmation)
//    - Client-side password authentication (requires NetPlayClient password API)
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
    /// This instance is hosting a session; waiting for peers to connect.
    PVDolphinNetplayStatusHosting = 1,
    /// Connected to a remote host as a client.
    PVDolphinNetplayStatusConnected = 2,
};

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

/// The traversal code assigned by Dolphin's relay when hosting via STUN.
///
/// Only valid while `dolphinNetplayStatus == PVDolphinNetplayStatusHosting`
/// with traversal enabled.  Returns nil for direct-IP sessions.
@property (nonatomic, readonly, nullable) NSString *dolphinTraversalCode;

/// Start a Dolphin NetPlayServer on `port` and connect this instance as
/// player 1.  Pass a nil or empty password for an open room.
///
/// @param port       TCP port for the server.  Pass 0 to use the default (2626).
/// @param password   Optional room password.
/// @param maxPlayers Maximum number of players (1–4 for GC; 1–4 for Wii).
/// @param error      Populated on failure.
/// @return YES on success; NO on failure.
- (BOOL)startNetplayHostOnPort:(uint16_t)port
                      password:(nullable NSString *)password
                    maxPlayers:(NSInteger)maxPlayers
                         error:(NSError *_Nullable __autoreleasing *_Nullable)error
NS_SWIFT_NAME(startNetplayHost(onPort:password:maxPlayers:));

/// Join an existing session by direct IP:port.
///
/// To connect via Dolphin's STUN relay instead, pass a non-empty
/// `traversalCode` (the host's relay identifier) and leave `host` empty.
///
/// @param host           Host IP address for direct connect (ignored when traversalCode is set).
/// @param port           Host TCP port.  Pass 0 to use the default (2626).
/// @param traversalCode  Dolphin traversal code for relay-based connect.  Pass nil for direct IP.
/// @param password       Room password.  Pass nil for open rooms.
/// @param error          Populated on failure.
/// @return YES on success; NO on failure.
- (BOOL)joinNetplayHost:(NSString *)host
                   port:(uint16_t)port
          traversalCode:(nullable NSString *)traversalCode
               password:(nullable NSString *)password
                  error:(NSError *_Nullable __autoreleasing *_Nullable)error
NS_SWIFT_NAME(joinNetplay(host:port:traversalCode:password:));

/// Stop any active server and/or client.  Safe to call when already idle.
- (void)stopNetplay;

/// Set Dolphin's input buffer size (frame delay) via Config::NETPLAY_INPUT_BUFFER_SIZE.
///
/// Must be called while a session is active; no-op when no session is running.
/// Typical values: 0 = minimum latency (rollback-like), 1–5 for LAN/WAN delay-based play.
///
/// @param bufferSize  Number of input frames to buffer (0–127).  Values above 127
///                    are clamped to 127 to match Dolphin's internal limit.
- (void)setNetplayInputBufferSize:(uint32_t)bufferSize
NS_SWIFT_NAME(setNetplayInputBufferSize(_:));

/// The traversal code assigned by Dolphin's relay server when hosting via STUN.
///
/// Queries `NetPlayServer::GetInterfaceListToSend()` (or equivalent) to retrieve
/// the code that remote players enter to connect via stun.dolphin-emu.org.
/// Returns nil for direct-IP sessions or when the relay has not yet assigned a code.
- (nullable NSString *)queryDolphinTraversalCode
NS_SWIFT_NAME(queryDolphinTraversalCode());

@end

NS_ASSUME_NONNULL_END
