//
//  retro_netplay.m
//  retro-netplay
//
//  Created by Joseph Mattiello on 8/1/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//
//  Bridges Provenance Swift netplay calls to RetroArch's C-level netplay
//  engine (HAVE_NETPLAY). Calls command_event() with CMD_EVENT_NETPLAY_*
//  constants from command.h, and writes to global_t->netplay before firing.
//

#import "retro_netplay.h"

// RetroArch C headers — included via module map / bridging header in PVRetroArch
#if __has_include(<PVRetroArch/command.h>)
#import <PVRetroArch/command.h>
#import <PVRetroArch/runloop.h>
#import <PVRetroArch/string/stdstring.h>
#else
// Forward-declare what we need when building outside PVRetroArch.
// These symbols are only used inside #ifdef HAVE_NETPLAY blocks,
// so they will never be called unless the full RetroArch headers are present.
typedef int menu_action;
typedef bool (*command_event_fn)(int cmd, void *data);
static command_event_fn command_event = NULL;
typedef struct {
    struct {
        bool enable;
        bool is_client;
        bool is_spectate;
        uint16_t port;
        unsigned sync_frames;
        char server[256];
    } netplay;
} global_t;
static global_t *global_get_ptr(void) { return NULL; }
#endif

NS_ASSUME_NONNULL_BEGIN

NSErrorDomain const PVRetroArchNetplayErrorDomain __attribute__((weak)) = @"com.provenance.retroarch.netplay";

@interface PVRetroArchNetplayBridge ()
@property (nonatomic) PVRetroArchNetplayStatus status;
@end

@implementation PVRetroArchNetplayBridge

+ (instancetype)shared {
    static PVRetroArchNetplayBridge *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PVRetroArchNetplayBridge alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = PVRetroArchNetplayStatusIdle;
    }
    return self;
}

// MARK: - Host

- (BOOL)startHostingWithNickname:(NSString *)nickname
                            port:(uint16_t)port
                      frameDelay:(int)frameDelay
                      maxPlayers:(int)maxPlayers
                           error:(NSError *__autoreleasing _Nullable *)error {
    if (_status != PVRetroArchNetplayStatusIdle) {
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
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch is not running."}];
        }
        return NO;
    }

    // Configure as host: empty server string = hosting
    gl->netplay.enable     = true;
    gl->netplay.is_client  = false;
    gl->netplay.is_spectate = false;
    gl->netplay.port       = port > 0 ? port : 55435;
    gl->netplay.sync_frames = (unsigned)MAX(0, frameDelay);
    *gl->netplay.server    = '\0';   // empty = host mode

    bool ok = command_event(CMD_EVENT_NETPLAY_INIT, NULL);
    if (!ok) {
        // Reset state on failure
        gl->netplay.enable = false;
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorCommandFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch netplay init failed."}];
        }
        return NO;
    }

    _status = PVRetroArchNetplayStatusHosting;
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

// MARK: - Join

- (BOOL)connectToHost:(NSString *)hostname
                 port:(uint16_t)port
             nickname:(NSString *)nickname
           frameDelay:(int)frameDelay
             spectate:(BOOL)spectate
                error:(NSError *__autoreleasing _Nullable *)error {
    if (_status != PVRetroArchNetplayStatusIdle) {
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
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch is not running."}];
        }
        return NO;
    }

    gl->netplay.enable      = true;
    gl->netplay.is_client   = !spectate;
    gl->netplay.is_spectate = spectate;
    gl->netplay.port        = port > 0 ? port : 55435;
    gl->netplay.sync_frames = (unsigned)MAX(0, frameDelay);
    strlcpy(gl->netplay.server,
            hostname.UTF8String,
            sizeof(gl->netplay.server));

    bool ok = command_event(CMD_EVENT_NETPLAY_INIT, NULL);
    if (!ok) {
        gl->netplay.enable = false;
        if (error) {
            *error = [NSError errorWithDomain:PVRetroArchNetplayErrorDomain
                                         code:PVRetroArchNetplayErrorCommandFailed
                                     userInfo:@{NSLocalizedDescriptionKey: @"RetroArch netplay connect failed."}];
        }
        return NO;
    }

    _status = spectate ? PVRetroArchNetplayStatusSpectating : PVRetroArchNetplayStatusConnected;
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

// MARK: - Disconnect

- (void)stopNetplay {
#ifdef HAVE_NETPLAY
    command_event(CMD_EVENT_NETPLAY_DEINIT, NULL);

    global_t *gl = global_get_ptr();
    if (gl) {
        gl->netplay.enable = false;
    }
#endif
    _status = PVRetroArchNetplayStatusIdle;
}

// MARK: - Status

- (PVRetroArchNetplayStatus)currentStatus {
    return _status;
}

- (void)flipPlayers {
#ifdef HAVE_NETPLAY
    command_event(CMD_EVENT_NETPLAY_FLIP_PLAYERS, NULL);
#endif
}

@end

NS_ASSUME_NONNULL_END
