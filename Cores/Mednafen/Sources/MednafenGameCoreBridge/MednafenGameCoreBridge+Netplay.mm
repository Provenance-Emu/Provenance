//
//  MednafenGameCoreBridge+Netplay.mm
//  PVMednafen
//
//  Created by Joseph Mattiello on 3/21/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//

#import "MednafenGameCoreBridge+Netplay.h"

@import mednafen;
@import PVLoggingObjC;

// Mednafen netplay C++ API — defined in mednafen/src/netplay.cpp
namespace Mednafen {
    // Connect using netplay.host / netplay.port / netplay.nick / netplay.gamekey settings.
    extern void MDFNI_NetplayConnect(void);
    // Disconnect from the current session and free Connection.
    extern void MDFNI_NetplayDisconnect(void);
    // Set a Mednafen string setting.
    extern void MDFNI_SetSetting(const char *name, const std::string &value);
    // Set a Mednafen unsigned-int setting.
    extern void MDFNI_SetSettingUI(const char *name, unsigned long long value);
    // 0 when idle, non-zero when a session is fully joined.
    extern int MDFNnetplay;
}

NSErrorDomain const PVMednafenNetplayErrorDomain = @"com.provenance.mednafen.netplay";

@implementation MednafenGameCoreBridge (Netplay)

- (PVMednafenNetplayStatus)mednafenNetplayStatus {
    return Mednafen::MDFNnetplay ? PVMednafenNetplayStatusConnected
                                 : PVMednafenNetplayStatusIdle;
}

- (BOOL)mednafenNetplaySupported {
    // netplay.cpp is always compiled into Provenance's Mednafen build.
    return YES;
}

- (BOOL)netplayConnectToHost:(NSString *)host
                        port:(uint16_t)port
                    nickname:(NSString *)nickname
                    password:(NSString *)password
                       error:(NSError *__autoreleasing _Nullable *)error {
    if (host.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:PVMednafenNetplayErrorDomain
                                         code:PVMednafenNetplayErrorInvalidSettings
                                     userInfo:@{NSLocalizedDescriptionKey: @"Host address must not be empty."}];
        }
        return NO;
    }

    if (Mednafen::MDFNnetplay) {
        if (error) {
            *error = [NSError errorWithDomain:PVMednafenNetplayErrorDomain
                                         code:PVMednafenNetplayErrorAlreadyActive
                                     userInfo:@{NSLocalizedDescriptionKey: @"A Mednafen netplay session is already active."}];
        }
        return NO;
    }

    // Configure Mednafen settings before connecting.
    Mednafen::MDFNI_SetSetting("netplay.host",    std::string(host.UTF8String));
    Mednafen::MDFNI_SetSettingUI("netplay.port",  port > 0 ? port : 4046);
    Mednafen::MDFNI_SetSetting("netplay.nick",    std::string(nickname.UTF8String ?: ""));
    Mednafen::MDFNI_SetSetting("netplay.gamekey", std::string(password.UTF8String ?: ""));

    DLOG(@"[Mednafen Netplay] Connecting → %@:%u nick=%@ key=%@", host, port, nickname, password);

    @try {
        // MDFNI_NetplayConnect reads the settings we just set and opens a TCP connection.
        // On success it begins frame-sync; on failure it calls NetError() (logs to Mednafen log).
        Mednafen::MDFNI_NetplayConnect();
    } @catch (NSException *ex) {
        ELOG(@"[Mednafen Netplay] Exception during connect: %@", ex);
        if (error) {
            *error = [NSError errorWithDomain:PVMednafenNetplayErrorDomain
                                         code:PVMednafenNetplayErrorConnectFailed
                                     userInfo:@{NSLocalizedDescriptionKey: ex.reason ?: @"Unknown error during connect."}];
        }
        return NO;
    }

    // MDFNI_NetplayConnect is asynchronous in the game loop; at this point Connection
    // was created but MDFNnetplay may not yet be 1 (set during the first sync frame).
    // We return YES as long as no exception was thrown.
    return YES;
}

- (void)netplayDisconnect {
    DLOG(@"[Mednafen Netplay] Disconnecting.");
    Mednafen::MDFNI_NetplayDisconnect();
}

@end
