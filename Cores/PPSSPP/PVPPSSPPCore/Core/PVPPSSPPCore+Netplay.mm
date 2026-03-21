//
//  PVPPSSPPCore+Netplay.mm
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#import "PVPPSSPPCore+Netplay.h"

// PPSSPP config globals.
#include "Core/Config.h"

NSErrorDomain const PVPPSSPPAdhocErrorDomain = @"org.provenance-emu.ppsspp.adhoc";

// ---------------------------------------------------------------------------
// Private ivar storage via associated objects
// ---------------------------------------------------------------------------

static const char kAdhocStatusKey       = 0;
static const char kSavedWlanKey         = 0;
static const char kSavedAdhocServerKey  = 0;

@implementation PVPPSSPPCoreBridge (Netplay)

// MARK: - Properties

- (PVPPSSPPAdhocStatus)adhocStatus {
    NSNumber *boxed = objc_getAssociatedObject(self, &kAdhocStatusKey);
    return boxed ? (PVPPSSPPAdhocStatus)boxed.integerValue : PVPPSSPPAdhocStatusIdle;
}

- (void)setAdhocStatus:(PVPPSSPPAdhocStatus)status {
    objc_setAssociatedObject(self, &kAdhocStatusKey,
                             @(status), OBJC_ASSOCIATION_RETAIN);
}

- (nullable NSString *)adhocServerAddress {
    if (!g_Config.bEnableWlan) { return nil; }
    const std::string &addr = g_Config.proAdhocServer;
    if (addr.empty()) { return nil; }
    return [NSString stringWithUTF8String:addr.c_str()];
}

- (BOOL)wlanEnabled {
    return g_Config.bEnableWlan ? YES : NO;
}

// MARK: - Control

- (void)_savePriorAdhocConfig {
    // Capture g_Config values before netplay overwrites them so stopAdhoc can restore them.
    NSString *savedServer = [NSString stringWithUTF8String:g_Config.proAdhocServer.c_str()];
    objc_setAssociatedObject(self, &kSavedAdhocServerKey, savedServer, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(self, &kSavedWlanKey, @(g_Config.bEnableWlan), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)startAdhocLANHostWithError:(NSError *__autoreleasing _Nullable *)error {
    if (self.adhocStatus != PVPPSSPPAdhocStatusIdle) {
        if (error) {
            *error = [NSError errorWithDomain:PVPPSSPPAdhocErrorDomain
                                         code:PVPPSSPPAdhocErrorAlreadyActive
                                     userInfo:@{
                NSLocalizedDescriptionKey: @"An adhoc session is already active."
            }];
        }
        return NO;
    }

    if (!_isInitialized) {
        if (error) {
            *error = [NSError errorWithDomain:PVPPSSPPAdhocErrorDomain
                                         code:PVPPSSPPAdhocErrorNotReady
                                     userInfo:@{
                NSLocalizedDescriptionKey: @"The PPSSPP core is not ready to start adhoc networking."
            }];
        }
        return NO;
    }

    [self _savePriorAdhocConfig];

    // Point proAdhocServer at localhost.  A PRO Adhoc Server–compatible
    // listener must be reachable at 127.0.0.1 for PSP games to discover peers.
    // PPSSPP's built-in adhoc server thread handles this when bEnableWlan=true.
    g_Config.proAdhocServer = "127.0.0.1";
    g_Config.bEnableWlan    = true;

    [self setAdhocStatus:PVPPSSPPAdhocStatusHosting];
    return YES;
}

- (BOOL)connectToAdhocServer:(NSString *)host
                       error:(NSError *__autoreleasing _Nullable *)error {
    if (!host || host.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:PVPPSSPPAdhocErrorDomain
                                         code:PVPPSSPPAdhocErrorInvalidAddress
                                     userInfo:@{
                NSLocalizedDescriptionKey: @"Adhoc server address must not be empty."
            }];
        }
        return NO;
    }

    if (self.adhocStatus != PVPPSSPPAdhocStatusIdle) {
        if (error) {
            *error = [NSError errorWithDomain:PVPPSSPPAdhocErrorDomain
                                         code:PVPPSSPPAdhocErrorAlreadyActive
                                     userInfo:@{
                NSLocalizedDescriptionKey: @"An adhoc session is already active."
            }];
        }
        return NO;
    }

    if (!_isInitialized) {
        if (error) {
            *error = [NSError errorWithDomain:PVPPSSPPAdhocErrorDomain
                                         code:PVPPSSPPAdhocErrorNotReady
                                     userInfo:@{
                NSLocalizedDescriptionKey: @"The core is not ready to use adhoc networking yet."
            }];
        }
        return NO;
    }

    [self _savePriorAdhocConfig];

    g_Config.proAdhocServer = std::string([host UTF8String]);
    g_Config.bEnableWlan    = true;

    // NOTE: PVPPSSPPAdhocStatusConnected reflects "wlan enabled and server
    // configured" — PPSSPP does not expose a socket-level connected callback,
    // so we cannot confirm the actual TCP/UDP handshake here.  Actual game
    // connectivity is handled by PPSSPP internals once the game logic triggers
    // adhoc discovery.
    [self setAdhocStatus:PVPPSSPPAdhocStatusConnected];
    return YES;
}

- (void)stopAdhoc {
    // Restore the g_Config values that were in effect before netplay started
    // so the user's prior PPSSPP network configuration is not permanently lost.
    NSNumber *savedWlan   = objc_getAssociatedObject(self, &kSavedWlanKey);
    NSString *savedServer = objc_getAssociatedObject(self, &kSavedAdhocServerKey);
    g_Config.bEnableWlan    = savedWlan ? savedWlan.boolValue : false;
    g_Config.proAdhocServer = savedServer ? std::string([savedServer UTF8String]) : "";
    objc_setAssociatedObject(self, &kSavedWlanKey, nil, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(self, &kSavedAdhocServerKey, nil, OBJC_ASSOCIATION_RETAIN);
    [self setAdhocStatus:PVPPSSPPAdhocStatusIdle];
}

@end
