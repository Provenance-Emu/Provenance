//
//  PVRetroArchCoreBridge+Netplay.mm
//  PVRetroArch
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Bridges Provenance Swift netplay calls to RetroArch's C-level netplay
//  engine (HAVE_NETPLAY). Configures settings_t netplay fields via
//  config_get_ptr(), then fires CMD_EVENT_NETPLAY_INIT / DEINIT via
//  command_event() and netplay_driver_ctl().
//

#import "PVRetroArchCoreBridge+Netplay.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
#import <PVLogging/PVLoggingObjC.h>
#pragma clang diagnostic pop

#ifdef HAVE_NETPLAY
extern "C" {
#import "command.h"
#import "configuration.h"
#import "network/netplay/netplay.h"
#import "network/netplay/netplay_defines.h"
#import "libretro-common/include/string/stdstring.h"
} // extern "C"
#endif

NS_ASSUME_NONNULL_BEGIN

NSErrorDomain const PVRetroArchNetplayErrorDomain = @"com.provenance.retroarch.netplay.error";

@implementation PVRetroArchCoreBridge (Netplay)

// MARK: - Compile-time capability flag

- (BOOL)netplaySupported {
#ifdef HAVE_NETPLAY
    return YES;
#else
    return NO;
#endif
}

// MARK: - Status property (derived live from netplay_driver_ctl)

- (PVRetroArchNetplayStatus)netplayStatus {
#ifdef HAVE_NETPLAY
    if (!netplay_driver_ctl(RARCH_NETPLAY_CTL_IS_ENABLED, NULL))
        return PVRetroArchNetplayStatusIdle;
    if (netplay_driver_ctl(RARCH_NETPLAY_CTL_IS_SPECTATING, NULL))
        return PVRetroArchNetplayStatusSpectating;
    if (netplay_driver_ctl(RARCH_NETPLAY_CTL_IS_SERVER, NULL))
        return PVRetroArchNetplayStatusHosting;
    if (netplay_driver_ctl(RARCH_NETPLAY_CTL_IS_CONNECTED, NULL))
        return PVRetroArchNetplayStatusConnected;
    return PVRetroArchNetplayStatusIdle;
#else
    return PVRetroArchNetplayStatusIdle;
#endif
}

// MARK: - Host

- (BOOL)netplayStartHostingWithNickname:(NSString *)nickname
                                   port:(uint16_t)port
                             frameDelay:(int)frameDelay
                                  error:(NSError *__autoreleasing _Nullable *)error {
#ifdef HAVE_NETPLAY
    if (self.netplayStatus != PVRetroArchNetplayStatusIdle) {
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorAlreadyActive
                                     userInfo:@{NSLocalizedDescriptionKey: @"A netplay session is already active."}];
        }
        return NO;
    }

    settings_t *settings = config_get_ptr();
    if (!settings) {
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorNotRunning
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch settings not initialized."}];
        }
        return NO;
    }

    // Configure netplay settings
    settings->uints.netplay_port = (port > 0) ? port : 55435;
    settings->uints.netplay_input_latency_frames_min = (unsigned)MAX(0, frameDelay);
    settings->paths.netplay_server[0] = '\0';  // empty = host mode
    settings->bools.netplay_start_as_spectator = false;
    settings->bools.netplay_public_announce = false;

    if (nickname.length) {
        strlcpy(settings->paths.username,
                nickname.UTF8String,
                sizeof(settings->paths.username));
    }

    ILOG(@"[Netplay] Starting host on port %u, frameDelay=%d", settings->uints.netplay_port, frameDelay);

    netplay_driver_ctl(RARCH_NETPLAY_CTL_ENABLE_SERVER, NULL);
    bool ok = command_event(CMD_EVENT_NETPLAY_INIT, NULL);
    if (!ok) {
        netplay_driver_ctl(RARCH_NETPLAY_CTL_DISABLE, NULL);
        ELOG(@"[Netplay] CMD_EVENT_NETPLAY_INIT failed");
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorCommandFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch netplay init failed."}];
        }
        return NO;
    }

    ILOG(@"[Netplay] Hosting started");
    return YES;
#else
    if (error) {
        *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                     code:PVRetroArchNetplayErrorCommandFailed
                                 userInfo:@{NSLocalizedDescriptionKey: @"RetroArch was compiled without HAVE_NETPLAY."}];
    }
    return NO;
#endif
}

// MARK: - Join / Spectate

- (BOOL)netplayConnectToHost:(NSString *)hostname
                        port:(uint16_t)port
                    nickname:(NSString *)nickname
                  frameDelay:(int)frameDelay
                    spectate:(BOOL)spectate
                       error:(NSError *__autoreleasing _Nullable *)error {
#ifdef HAVE_NETPLAY
    if (self.netplayStatus != PVRetroArchNetplayStatusIdle) {
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorAlreadyActive
                                     userInfo:@{NSLocalizedDescriptionKey: @"A netplay session is already active."}];
        }
        return NO;
    }

    if (!hostname.length) {
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorInvalidSettings
                                     userInfo:@{NSLocalizedDescriptionKey: @"Hostname must not be empty."}];
        }
        return NO;
    }

    settings_t *settings = config_get_ptr();
    if (!settings) {
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorNotRunning
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch settings not initialized."}];
        }
        return NO;
    }

    // Configure netplay settings
    strlcpy(settings->paths.netplay_server,
            hostname.UTF8String,
            sizeof(settings->paths.netplay_server));
    settings->uints.netplay_port = (port > 0) ? port : 55435;
    settings->uints.netplay_input_latency_frames_min = (unsigned)MAX(0, frameDelay);
    settings->bools.netplay_start_as_spectator = spectate;

    if (nickname.length) {
        strlcpy(settings->paths.username,
                nickname.UTF8String,
                sizeof(settings->paths.username));
    }

    ILOG(@"[Netplay] Connecting to %@:%u spectate=%d", hostname, settings->uints.netplay_port, spectate);

    netplay_driver_ctl(RARCH_NETPLAY_CTL_ENABLE_CLIENT, NULL);
    bool ok = command_event(CMD_EVENT_NETPLAY_INIT, NULL);
    if (!ok) {
        netplay_driver_ctl(RARCH_NETPLAY_CTL_DISABLE, NULL);
        ELOG(@"[Netplay] CMD_EVENT_NETPLAY_INIT failed for client connect");
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorCommandFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch netplay connect failed."}];
        }
        return NO;
    }

    ILOG(@"[Netplay] Connected to %@", hostname);
    return YES;
#else
    if (error) {
        *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                     code:PVRetroArchNetplayErrorCommandFailed
                                 userInfo:@{NSLocalizedDescriptionKey: @"RetroArch was compiled without HAVE_NETPLAY."}];
    }
    return NO;
#endif
}

// MARK: - Stop

- (void)netplayStop {
#ifdef HAVE_NETPLAY
    ILOG(@"[Netplay] Stopping session");
    command_event(CMD_EVENT_NETPLAY_DEINIT, NULL);
    netplay_driver_ctl(RARCH_NETPLAY_CTL_DISABLE, NULL);
#endif
}

// MARK: - Flip Players

- (void)netplayFlipPlayers {
#ifdef HAVE_NETPLAY
    netplay_driver_ctl(RARCH_NETPLAY_CTL_GAME_WATCH, NULL);
#endif
}

@end

NS_ASSUME_NONNULL_END
