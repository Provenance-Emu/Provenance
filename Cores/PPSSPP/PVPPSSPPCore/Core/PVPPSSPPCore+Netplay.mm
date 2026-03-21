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

static const char kAdhocStatusKey  = 0;
static const char kAdhocAddressKey = 0;

@implementation PVPPSSPPCoreBridge (Netplay)

// MARK: - Properties

- (PVPPSSPPAdhocStatus)adhocStatus {
    NSNumber *boxed = objc_getAssociatedObject(self, &kAdhocStatusKey);
    return boxed ? (PVPPSSPPAdhocStatus)boxed.integerValue : PVPPSSPPAdhocStatusIdle;
}

- (void)setAdhocStatus:(PVPPSSPPAdhocStatus)status {
    objc_setAssociatedObject(self, &kAdhocStatusKey,
                             @(status), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

    g_Config.proAdhocServer = std::string([host UTF8String]);
    g_Config.bEnableWlan    = true;

    [self setAdhocStatus:PVPPSSPPAdhocStatusConnected];
    return YES;
}

- (void)stopAdhoc {
    g_Config.bEnableWlan    = false;
    g_Config.proAdhocServer = "";
    [self setAdhocStatus:PVPPSSPPAdhocStatusIdle];
}

@end
