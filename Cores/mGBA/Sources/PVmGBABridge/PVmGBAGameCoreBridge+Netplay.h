//
//  PVmGBAGameCoreBridge+Netplay.h
//  PVCoremGBA
//
//  Created by Provenance Emu on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Extends PVmGBAGameCoreBridge with TCP link-cable netplay.
//
//  GBA / GB / GBC Link Cable Model
//  ─────────────────────────────────
//  mGBA emulates link-cable multi-player via a custom GBASIODriver that
//  exchanges SIO register data with a peer over a TCP socket.
//
//    Host   (player 1 / master): -startLinkHostOnPort:error:
//    Client (player 2 / slave):  -joinLinkAtHost:port:error:
//    Both sides:                 -stopLink
//
//  The host binds a TCP server socket on the specified port and waits for
//  the client to connect.  Once connected, a lightweight frame-locked
//  protocol exchanges GBA SIO multi-player data each emulated frame, so
//  two separate Provenance instances behave as if they share a physical
//  link cable.
//
//  Limitations
//  ───────────
//  • 2-player only (GBA multi-player SIO master + one slave).
//  • Lockstep / LAN only — not suitable for WAN without port forwarding.
//  • No rollback; one dropped TCP packet stalls both sides briefly.
//

#pragma once

#import "mGBAGameCoreBridge.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// MARK: - Error domain & codes

/// Error domain for mGBA link-cable netplay errors.
extern NSErrorDomain const PVmGBALinkErrorDomain;

/// Error codes for mGBA link-cable netplay.
typedef NS_ERROR_ENUM(PVmGBALinkErrorDomain, PVmGBALinkError) {
    /// The emulator core is not yet initialized (ROM not loaded).
    PVmGBALinkErrorNotReady             = 1,
    /// A link session is already active.
    PVmGBALinkErrorAlreadyActive        = 2,
    /// The TCP bind / connect call failed (see localizedDescription for errno).
    PVmGBALinkErrorSocketFailed         = 3,
    /// The peer disconnected unexpectedly mid-session.
    PVmGBALinkErrorPeerDisconnected     = 4,
    /// The supplied host address is empty or syntactically invalid.
    PVmGBALinkErrorInvalidAddress       = 5,
};

// MARK: - Session status

/// Lifecycle state of the mGBA TCP link session.
typedef NS_ENUM(NSInteger, PVmGBALinkStatus) {
    /// No active link session.
    PVmGBALinkStatusIdle         = 0,
    /// Server socket bound; waiting asynchronously for a peer to connect.
    PVmGBALinkStatusHosting      = 1,
    /// TCP connection established; exchanging link-cable data each frame.
    PVmGBALinkStatusConnected    = 2,
};

// MARK: - Category

/// Netplay category on PVmGBAGameCoreBridge.
///
/// Manages a TCP socket pair and a custom GBASIODriver that routes GBA
/// SIO multi-player data over the network.  Call these methods from the
/// Swift `PVmGBACore+PVNetplayCapable` layer via `_bridge`.
@interface PVmGBAGameCoreBridge (Netplay)

/// Current TCP link session status.
@property (nonatomic, readonly) PVmGBALinkStatus linkStatus;

/// YES when a peer is connected and exchanging SIO data.
@property (nonatomic, readonly, getter=isLinkConnected) BOOL linkConnected;

/// The last error that caused an unexpected session teardown (e.g. peer disconnect
/// during an SIO exchange).  nil when the session ended cleanly via -stopLink.
/// The Swift layer can read this after observing a transition to Idle to surface a
/// diagnostic message instead of silently returning to the idle state.
@property (nonatomic, readonly, nullable) NSError *lastDisconnectError;

/// Bind a TCP server socket on `port` and asynchronously accept one peer.
///
/// The receiver transitions to `PVmGBALinkStatusHosting` immediately on
/// success.  When a peer connects the status becomes `PVmGBALinkStatusConnected`
/// and the SIO driver is installed into the running core.
///
/// @param port  Local TCP port to listen on (must be in 1024–65535).
/// @param error Populated on failure.
/// @return YES if the server socket was bound successfully.
- (BOOL)startLinkHostOnPort:(uint16_t)port
                      error:(NSError *__autoreleasing _Nullable *)error;

/// Connect to a remote mGBA link host.
///
/// Blocks briefly while the TCP handshake completes, then installs the SIO
/// driver into the running core.
///
/// @param host  IPv4 address or hostname of the host device.
/// @param port  TCP port the host is listening on.
/// @param error Populated on failure.
/// @return YES if the connection was established successfully.
- (BOOL)joinLinkAtHost:(NSString *)host
                  port:(uint16_t)port
                 error:(NSError *__autoreleasing _Nullable *)error;

/// Tear down the active link session.
///
/// Removes the SIO driver from the core, closes all sockets, and resets
/// the session state to `PVmGBALinkStatusIdle`.
- (void)stopLink;

@end

NS_ASSUME_NONNULL_END
