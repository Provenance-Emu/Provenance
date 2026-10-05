//
//  PVPPSSPPCore+Netplay.h
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Exposes PPSSPP's PSP Ad Hoc network multiplayer through the PVPPSSPPCoreBridge.
//
//  PSP Ad Hoc emulation works through a PRO Ad Hoc Server (TCP port 27312)
//  that introduces players to each other; game data then flows peer to peer
//  over UDP/TCP at `gamePort + iPortOffset`.  Every device must point
//  `proAdhocServer` at the same server and use the same `iPortOffset`:
//
//    - LAN host:   enables PPSSPP's built-in server (`bEnableAdhocServer`) and
//                  sets `proAdhocServer` to this device's own LAN IP.  A
//                  loopback address ("127.x" / "localhost") would put PPSSPP
//                  into single-machine mode, so it is never used here.
//    - LAN client: `proAdhocServer` = the host device's LAN IP; no server.
//    - WAN:        `proAdhocServer` = a publicly reachable PRO Ad Hoc Server.
//
//  `iPortOffset` and the built-in server start are read only when the game
//  boots, so hosting needs a game restart.  The pending configuration is
//  applied by `-applyAdhocBootConfig`, which `-setOptionValues` runs on every
//  boot and restart.  `proAdhocServer` and `bEnableWlan` apply live.
//

#pragma once

#import "PVPPSSPPCore.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for PPSSPP adhoc networking errors.
extern NSErrorDomain const PVPPSSPPAdhocErrorDomain;

/// Error codes for PPSSPP adhoc networking.
typedef NS_ERROR_ENUM(PVPPSSPPAdhocErrorDomain, PVPPSSPPAdhocError) {
    /// The emulator core is not initialized (ROM not loaded yet).
    PVPPSSPPAdhocErrorNotReady          = 1,
    /// An adhoc session is already active.
    PVPPSSPPAdhocErrorAlreadyActive     = 2,
    /// The provided server address is empty or invalid.
    PVPPSSPPAdhocErrorInvalidAddress    = 3,
};

/// Current state of the PPSSPP adhoc session.
typedef NS_ENUM(NSInteger, PVPPSSPPAdhocStatus) {
    /// No adhoc session is active.
    PVPPSSPPAdhocStatusIdle         = 0,
    /// Hosting — wlan enabled, built-in server on, proAdhocServer = this device's LAN IP.
    PVPPSSPPAdhocStatusHosting      = 1,
    /// Configured as a client of another device's (or a public) adhoc server.
    /// This says nothing about whether the game's own ad hoc session is up;
    /// see `adhocSessionConnected`.
    PVPPSSPPAdhocStatusConnected    = 2,
};

/// The PRO Ad Hoc Server's fixed TCP port (`SERVER_PORT` in proAdhoc.h).
#define PVPPSSPPAdhocServerPort 27312
/// The port offset every device in a session must share (PPSSPP's default).
#define PVPPSSPPAdhocPortOffset 10000

/// Adhoc networking category on PVPPSSPPCoreBridge.
///
/// Wraps the networking fields of PPSSPP's `g_Config` (Core/Config.h) so that
/// PVNetplayManager can drive sessions.
@interface PVPPSSPPCoreBridge (Netplay)

/// Current adhoc session status.
@property (nonatomic, readonly) PVPPSSPPAdhocStatus adhocStatus;

/// The server address currently configured in g_Config.proAdhocServer.
/// Returns nil when wlan is disabled.
@property (nonatomic, readonly, nullable) NSString *adhocServerAddress;

/// Whether PPSSPP wlan emulation is currently enabled.
@property (nonatomic, readonly) BOOL wlanEnabled;

/// Whether the game has brought its ad hoc connection up (the game opened its
/// own ad hoc / multiplayer menu and joined the network).
@property (nonatomic, readonly) BOOL adhocSessionConnected;

/// Number of other players the adhoc server has introduced to this game.
@property (nonatomic, readonly) NSInteger adhocPeerCount;

/// This install's ad hoc MAC address ("xx:xx:xx:xx:xx:xx"): random, generated
/// once and persisted, so no two installs share one.
+ (NSString *)adhocMACAddress;

/// Configure this device as the LAN host.
///
/// Sets `proAdhocServer = lanAddress`, `bEnableWlan`, `bEnableAdhocServer` and
/// remembers the configuration for every later boot until `-stopAdhoc`.
///
/// @param lanAddress  This device's own LAN IPv4 address. Loopback is rejected.
/// @param restartRequired  Set to YES when the running game booted without
///        the built-in server (or with another port offset) and must restart.
/// @param error  Set on failure (core not ready, already active, bad address).
/// @return YES on success.
- (BOOL)startAdhocLANHostWithAddress:(NSString *)lanAddress
                     restartRequired:(BOOL * _Nullable)restartRequired
                               error:(NSError *__autoreleasing _Nullable *)error;

/// Configure this device as a client of an adhoc server.
///
/// Sets `proAdhocServer = host` and `bEnableWlan = true`.
///
/// @param host   The host device's LAN IP, or a public server's hostname.
/// @param restartRequired  Set to YES when the running game booted with a
///        setting that only a restart can change.
/// @param error  Set on failure.
/// @return YES on success.
- (BOOL)connectToAdhocServer:(NSString *)host
             restartRequired:(BOOL * _Nullable)restartRequired
                       error:(NSError *__autoreleasing _Nullable *)error;

/// Stop the current adhoc session and restore previous networking settings.
///
/// Restores the `g_Config` values that were active before adhoc was started.
/// A built-in server started at boot keeps running until the next restart.
- (void)stopAdhoc;

/// Apply the boot-only adhoc settings (port offset, MAC, UPnP) and any pending
/// session configuration. Called from `-setOptionValues` before the PSP boots.
- (void)applyAdhocBootConfig;

@end

NS_ASSUME_NONNULL_END
