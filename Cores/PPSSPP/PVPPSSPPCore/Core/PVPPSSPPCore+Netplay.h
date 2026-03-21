//
//  PVPPSSPPCore+Netplay.h
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Exposes PPSSPP's PSP Ad Hoc network multiplayer through the PVPPSSPPCoreBridge.
//
//  PSP Ad Hoc emulation works by routing PSP-to-PSP wlan traffic through a
//  central proxy server (PRO Adhoc Server compatible protocol).  All players
//  must point their `proAdhocServer` config entry at the same host:
//
//    - LAN host: sets server to "127.0.0.1" (local mini-server) — other devices
//      on the same network use this device's local IP as their server address.
//    - LAN client: sets server to the host device's LAN IP.
//    - WAN: sets server to a publicly-reachable PRO Adhoc Server instance.
//

#pragma once

#import "PVPPSSPPCore.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for PPSSPP adhoc networking errors.
extern NSErrorDomain const PVPPSSPPAdhocErrorDomain;

/// Error codes for PPSSPP adhoc networking.
typedef NS_ERROR_ENUM(PVPPSSPPAdhocErrorDomain, PVPPSSPPAdhocError) {
    /// The emulator core is not initialised (ROM not loaded yet).
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
    /// Hosting — wlan enabled, proAdhocServer == "127.0.0.1".
    PVPPSSPPAdhocStatusHosting      = 1,
    /// Connected as a client to a remote adhoc server.
    PVPPSSPPAdhocStatusConnected    = 2,
};

/// Adhoc networking category on PVPPSSPPCoreBridge.
///
/// Wraps `g_Config.bEnableWlan` and `g_Config.proAdhocServer` from
/// PPSSPP's Core/Config.h so that PVNetplayManager can drive sessions.
@interface PVPPSSPPCoreBridge (Netplay)

/// Current adhoc session status.
@property (nonatomic, readonly) PVPPSSPPAdhocStatus adhocStatus;

/// The server address currently configured in g_Config.proAdhocServer.
/// Returns nil when wlan is disabled.
@property (nonatomic, readonly, nullable) NSString *adhocServerAddress;

/// Whether PPSSPP wlan emulation is currently enabled.
@property (nonatomic, readonly) BOOL wlanEnabled;

/// Enable LAN host mode.
///
/// Sets `g_Config.proAdhocServer = "127.0.0.1"` and
/// `g_Config.bEnableWlan = true`.  The caller is responsible for ensuring a
/// PRO Adhoc Server–compatible listener is reachable at 127.0.0.1 (e.g. via
/// a bundled mini-server or the PPSSPP internal adhoc server thread).
///
/// Other devices on the LAN should call `-connectToAdhocServer:error:` with
/// this device's LAN IP address.
///
/// @param error  Set on failure (core not ready, already active, etc.).
/// @return YES on success.
- (BOOL)startAdhocLANHostWithError:(NSError *__autoreleasing _Nullable *)error;

/// Enable client mode pointing at a remote adhoc server.
///
/// Sets `g_Config.proAdhocServer = host` and `g_Config.bEnableWlan = true`.
///
/// @param host   IP address or hostname of the PRO Adhoc Server instance.
/// @param error  Set on failure.
/// @return YES on success.
- (BOOL)connectToAdhocServer:(NSString *)host
                       error:(NSError *__autoreleasing _Nullable *)error;

/// Disable adhoc networking.
///
/// Sets `g_Config.bEnableWlan = false` and clears `g_Config.proAdhocServer`.
- (void)stopAdhoc;

@end

NS_ASSUME_NONNULL_END
