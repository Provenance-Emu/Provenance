//
//  PVRetroArchCoreBridge+Netplay.mm
//  PVRetroArch
//
//  Created by Joseph Mattiello on 3/18/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Bridges Provenance Swift netplay calls to RetroArch's C-level netplay
//  engine (HAVE_NETPLAY). Configures global_t->netplay fields then fires
//  CMD_EVENT_NETPLAY_INIT / CMD_EVENT_NETPLAY_DEINIT via command_event().
//

#import "PVRetroArchCoreBridge+Netplay.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
#import <PVLogging/PVLoggingObjC.h>
#pragma clang diagnostic pop

#ifdef HAVE_NETPLAY
#import "command.h"
#import "runloop.h"
#import "libretro-common/include/string/stdstring.h"
#endif

NS_ASSUME_NONNULL_BEGIN

NSErrorDomain const PVRetroArchNetplayErrorDomain = @"com.provenance.retroarch.netplay";

// Internal storage key for associated status
static const void *kNetplayStatusKey = &kNetplayStatusKey;

@implementation PVRetroArchCoreBridge (Netplay)

// MARK: - Status property (stored via objc_associated_object)

- (PVRetroArchNetplayStatus)netplayStatus {
    NSNumber *num = objc_getAssociatedObject(self, kNetplayStatusKey);
    return num ? (PVRetroArchNetplayStatus)num.integerValue : PVRetroArchNetplayStatusIdle;
}

- (void)setNetplayStatus:(PVRetroArchNetplayStatus)status {
    objc_setAssociatedObject(self,
                             kNetplayStatusKey,
                             @(status),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// MARK: - Host

- (BOOL)netplayStartHostingWithNickname:(NSString *)nickname
                                   port:(uint16_t)port
                             frameDelay:(int)frameDelay
                                  error:(NSError *__autoreleasing _Nullable *)error {
    if (self.netplayStatus != PVRetroArchNetplayStatusIdle) {
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorAlreadyActive
                                     userInfo:@{NSLocalizedDescriptionKey: @"A netplay session is already active."}];
        }
        return NO;
    }

#ifdef HAVE_NETPLAY
    global_t *gl = global_get_ptr();
    if (!gl) {
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorNotRunning
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch runtime is not initialized."}];
        }
        return NO;
    }

    gl->netplay.enable      = true;
    gl->netplay.is_client   = false;
    gl->netplay.is_spectate = false;
    gl->netplay.port        = (port > 0) ? port : 55435;
    gl->netplay.sync_frames = (unsigned)MAX(0, frameDelay);
    gl->netplay.server[0]   = '\0';  // empty server string = host mode

    ILOG(@"[Netplay] Starting host on port %u, frameDelay=%d", gl->netplay.port, frameDelay);

    bool ok = command_event(CMD_EVENT_NETPLAY_INIT, NULL);
    if (!ok) {
        gl->netplay.enable = false;
        ELOG(@"[Netplay] CMD_EVENT_NETPLAY_INIT failed");
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorCommandFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch netplay init failed."}];
        }
        return NO;
    }

    [self setNetplayStatus:PVRetroArchNetplayStatusHosting];
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

#ifdef HAVE_NETPLAY
    global_t *gl = global_get_ptr();
    if (!gl) {
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorNotRunning
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch runtime is not initialized."}];
        }
        return NO;
    }

    gl->netplay.enable      = true;
    gl->netplay.is_client   = !spectate;
    gl->netplay.is_spectate = spectate;
    gl->netplay.port        = (port > 0) ? port : 55435;
    gl->netplay.sync_frames = (unsigned)MAX(0, frameDelay);
    strlcpy(gl->netplay.server,
            hostname.UTF8String,
            sizeof(gl->netplay.server));

    ILOG(@"[Netplay] Connecting to %@:%u spectate=%d", hostname, gl->netplay.port, spectate);

    bool ok = command_event(CMD_EVENT_NETPLAY_INIT, NULL);
    if (!ok) {
        gl->netplay.enable = false;
        ELOG(@"[Netplay] CMD_EVENT_NETPLAY_INIT failed for client connect");
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorCommandFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch netplay connect failed."}];
        }
        return NO;
    }

    [self setNetplayStatus:spectate ? PVRetroArchNetplayStatusSpectating
                                    : PVRetroArchNetplayStatusConnected];
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

    global_t *gl = global_get_ptr();
    if (gl) {
        gl->netplay.enable = false;
    }
#endif
    [self setNetplayStatus:PVRetroArchNetplayStatusIdle];
}

// MARK: - Flip Players

- (void)netplayFlipPlayers {
#ifdef HAVE_NETPLAY
    command_event(CMD_EVENT_NETPLAY_FLIP_PLAYERS, NULL);
#endif
}

@end

NS_ASSUME_NONNULL_END
