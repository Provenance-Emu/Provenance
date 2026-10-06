//
//  PVmGBAGameCoreBridge+Netplay.h
//  PVCoremGBA
//
//  Created by Provenance Emu on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  GBA link cable over the network.
//
//    Host   (player 1): -startLinkHostOnPort:password:error:
//    Client (player 2): -joinLinkAtHost:port:password:error:
//    Both sides:        -stopLink
//
//  The two GBAs run in lockstep (PVmGBANetLinkDriver.c). Each multiplayer
//  transfer costs the host about one network round trip, so trading and
//  turn-based battles over a LAN work, at reduced speed while the link is
//  busy. Real-time multiplayer is likely too slow.
//
//  Limitations
//  ───────────
//  • Two players.
//  • Direct TCP: LAN, or a forwarded port. No relay.
//  • The password check is a shared-secret hash, not encryption.
//  • Save-state loads are refused while linked.
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
    /// A socket call failed (see localizedDescription for errno).
    PVmGBALinkErrorSocketFailed         = 3,
    /// The peer disconnected unexpectedly mid-session.
    PVmGBALinkErrorPeerDisconnected     = 4,
    /// The supplied host address is empty or could not be resolved.
    PVmGBALinkErrorInvalidAddress       = 5,
    /// The host's password does not match.
    PVmGBALinkErrorWrongPassword        = 6,
    /// The other device runs an incompatible version of the link protocol.
    PVmGBALinkErrorVersionMismatch      = 7,
    /// Connecting, or the peer, timed out.
    PVmGBALinkErrorTimedOut             = 8,
    /// -stopLink was called while connecting.
    PVmGBALinkErrorCancelled            = 9,
    /// The other device sent something that is not the link protocol.
    PVmGBALinkErrorProtocol             = 10,
    /// The link driver gave up (out of memory, or the core couldn't take it).
    PVmGBALinkErrorLinkFailed           = 11,
};

// MARK: - Session status

/// Lifecycle state of the mGBA TCP link session.
typedef NS_ENUM(NSInteger, PVmGBALinkStatus) {
    /// No active link session.
    PVmGBALinkStatusIdle         = 0,
    /// Listening; waiting for the other device.
    PVmGBALinkStatusHosting      = 1,
    /// Linked with the other device.
    PVmGBALinkStatusConnected    = 2,
};

// MARK: - Category

@interface PVmGBAGameCoreBridge (Netplay)

/// Current link session status.
@property (nonatomic, readonly) PVmGBALinkStatus linkStatus;

/// YES while linked with the other device.
@property (nonatomic, readonly, getter=isLinkConnected) BOOL linkConnected;

/// The port the host listens on (the real one when 0 was requested), or the
/// port the client connected to. 0 when idle.
@property (nonatomic, readonly) uint16_t linkPort;

/// Why the session ended on its own (peer left, timed out, hosting failed).
/// nil after a clean -stopLink.
@property (nonatomic, readonly, nullable) NSError *lastDisconnectError;

/// Listen on `port` (0 = any free port) and wait for one client in the
/// background. Returns once listening; the status becomes Connected when the
/// client completes the handshake. IPv6 dual-stack, so IPv4 clients work.
///
/// @param password Required from the client when non-empty.
- (BOOL)startLinkHostOnPort:(uint16_t)port
                   password:(nullable NSString *)password
                      error:(NSError *__autoreleasing _Nullable *)error;

/// Connect to a host and run the handshake. Blocks up to 10 seconds; call it
/// off the main thread. -stopLink from another thread cancels it.
///
/// @param host IPv4 or IPv6 address, or a host name.
- (BOOL)joinLinkAtHost:(NSString *)host
                  port:(uint16_t)port
              password:(nullable NSString *)password
                 error:(NSError *__autoreleasing _Nullable *)error;

/// End the session from any thread. Interrupts a pending accept or connect.
/// The driver leaves the core at the next frame boundary.
- (void)stopLink;

@end

NS_ASSUME_NONNULL_END
