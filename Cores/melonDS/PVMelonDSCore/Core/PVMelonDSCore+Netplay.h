//
//  PVMelonDSCore+Netplay.h
//  PVMelonDS
//
//  Created by Joseph Mattiello on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Exposes melonDS's DS local wireless multiplayer (LocalMP) through the
//  PVMelonDSCoreBridge so that PVNetplayManager can drive sessions.
//
//  DS Local Wireless model:
//    - melonDS emulates DS 802.11 local wireless via LocalMP, a UDP-based
//      protocol where all instances on the same subnet exchange simulated DS
//      wireless frames.
//    - All players call LocalMP::Init() with the same port_base — no
//      host/client distinction at the C++ level; discovery is peer-to-peer.
//    - "Hosting" in Provenance maps to Init(port_base) acting as group
//      initiator; "joining" also calls Init(port_base) to join that group.
//    - LocalMP is LAN-only (UDP multicast); WAN relay is not supported here.
//

#pragma once

#import "PVMelonDSCore.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain for melonDS local wireless errors.
extern NSErrorDomain const PVMelonDSLocalMPErrorDomain;

/// Error codes for melonDS local wireless networking.
typedef NS_ERROR_ENUM(PVMelonDSLocalMPErrorDomain, PVMelonDSLocalMPError) {
    /// LocalMP is not available (melonDS submodule not compiled with LocalMP support).
    PVMelonDSLocalMPErrorUnavailable    = 1,
    /// A local wireless session is already active.
    PVMelonDSLocalMPErrorAlreadyActive  = 2,
    /// LocalMP::Init() returned false (socket bind failure or port conflict).
    PVMelonDSLocalMPErrorInitFailed     = 3,
};

/// Current state of the melonDS local wireless session.
typedef NS_ENUM(NSInteger, PVMelonDSLocalMPStatus) {
    /// No local wireless session is active.
    PVMelonDSLocalMPStatusIdle      = 0,
    /// Local wireless is active (hosting or joined).
    PVMelonDSLocalMPStatusActive    = 1,
};

/// The default UDP port base used by melonDS LocalMP (matches melonDS upstream default).
static const uint16_t PVMelonDSLocalMPDefaultPortBase = 7064;

/// LocalMP networking category on PVMelonDSCoreBridge.
///
/// Wraps `LocalMP::Init()` and `LocalMP::DeInit()` from the melonDS upstream
/// source and exposes local wireless session status so that PVNetplayManager
/// can drive sessions.
@interface PVMelonDSCoreBridge (Netplay)

/// Current local wireless session status.
@property (nonatomic, readonly) PVMelonDSLocalMPStatus localMPStatus;

/// Whether LocalMP support is compiled into this build.
///
/// Returns NO when the melonDS submodule was not present at compile time
/// (the build will still succeed but netplay will be unavailable at runtime).
@property (nonatomic, readonly, class) BOOL localMPAvailable;

/// Start DS local wireless multiplayer.
///
/// Calls `LocalMP::Init(port_base)`.  All devices that want to play together
/// must call this with the same `portBase` and be on the same subnet.
///
/// @param portBase  UDP port base for LocalMP frame exchange (default: 7064).
/// @param error     Set on failure (unavailable, already active, init failed).
/// @return YES on success.
- (BOOL)startLocalMPWithPortBase:(uint16_t)portBase
                           error:(NSError *__autoreleasing _Nullable *)error;

/// Stop the current DS local wireless session.
///
/// Calls `LocalMP::DeInit()`.  Safe to call when no session is active.
- (void)stopLocalMP;

@end

NS_ASSUME_NONNULL_END
