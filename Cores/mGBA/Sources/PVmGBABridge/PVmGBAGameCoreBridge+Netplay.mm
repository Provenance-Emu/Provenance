//
//  PVmGBAGameCoreBridge+Netplay.mm
//  PVCoremGBA
//
//  Created by Provenance Emu on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  Session lifecycle for the network link cable.
//
//  Threads
//  ───────
//  • Caller (Swift, any thread): start/join/stop. Join blocks while it
//    connects, so Swift calls it off the main actor.
//  • Accept thread (host): waits for the client, then marks the session
//    ready to install.
//  • Session I/O thread (PVmGBALink): socket reads, heartbeats.
//  • Emulation thread: the only thread that touches the core. At each frame
//    boundary it installs the driver for a ready session, or removes the
//    driver of a session that was stopped or lost, then runs the frame
//    through the driver.
//
//  Ownership
//  ─────────
//  The bridge keeps two references: the current session (cleared by
//  -stopLink) and the session whose driver is installed (emulation thread
//  only). A session object lives until both let go, so the driver and the
//  socket session it reads outlive their use on the emulation thread.
//

#import "PVmGBAGameCoreBridge+NetplayInternal.h"

#import <Foundation/Foundation.h>
#import <PVCoreObjCBridge/PVOSDNotification.h>
#import <objc/runtime.h>
#include <os/lock.h>

#include <mgba/core/core.h>
#include <mgba/internal/gba/gba.h>
#include <mgba/internal/gba/sio.h>

#include "PVmGBALink.h"
#include "PVmGBANetLinkDriver.h"

#include <string.h>
#include <time.h>

NSErrorDomain const PVmGBALinkErrorDomain = @"com.provenance.mgba.link";

/// How long the client tries to reach the host.
static const int kPVmGBALinkConnectTimeoutMs = 10000;
/// Longest the emulation thread waits for the link inside one frame. Short
/// enough that emulation plus waiting stays well inside a 60 Hz frame, so
/// the emulation loop still sleeps and releases its lock (pause works).
static const int kPVmGBALinkFrameWaitBudgetMs = 6;

/// Guards each bridge's current-session slot. Not @synchronized(bridge): the
/// emulation loop holds that lock around every frame.
static os_unfair_lock sPVmGBALinkSlotLock = OS_UNFAIR_LOCK_INIT;

/// PVGBALinkSessionStop joins a thread and may block up to the socket send
/// timeout saying goodbye, so it never runs on the main or emulation thread.
static void _pvmgba_link_stop_async(PVGBALinkSession *session, id owner) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        // `owner` keeps the session alive until the stop is done.
        (void) owner;
        PVGBALinkSessionStop(session);
    });
}
/// A link wait this long gets an on-screen "waiting" message.
static const uint64_t kPVmGBALinkStallNoticeMs = 3000;
static const NSTimeInterval kPVmGBALinkOSDDuration = 3.0;

static uint64_t _pvmgba_link_now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t) ts.tv_sec * 1000u + (uint64_t) ts.tv_nsec / 1000000u;
}

static void _pvmgba_link_osd(NSString *message, PVOSDType type) {
    [PVOSDNotification postMessage:message type:type duration:kPVmGBALinkOSDDuration];
}

static NSError *_pvmgba_link_error(PVGBALinkResult result, PVGBALinkSession *session) {
    PVmGBALinkError code;
    NSString *description;
    switch (result) {
    case PVGBALinkErrorWrongPassword:
        code = PVmGBALinkErrorWrongPassword;
        description = @"The host's password doesn't match.";
        break;
    case PVGBALinkErrorVersionMismatch:
        code = PVmGBALinkErrorVersionMismatch;
        description = @"The other device runs a different version of the link cable. Update both.";
        break;
    case PVGBALinkErrorTimeout:
        code = PVmGBALinkErrorTimedOut;
        description = @"The host didn't answer in time.";
        break;
    case PVGBALinkErrorCancelled:
        code = PVmGBALinkErrorCancelled;
        description = @"Cancelled.";
        break;
    case PVGBALinkErrorResolve:
        code = PVmGBALinkErrorInvalidAddress;
        description = @"Couldn't find the host at that address.";
        break;
    case PVGBALinkErrorProtocol:
    case PVGBALinkErrorSessionFull:
        code = PVmGBALinkErrorProtocol;
        description = @"The other device isn't a Provenance mGBA link host.";
        break;
    case PVGBALinkErrorClosed:
        code = PVmGBALinkErrorPeerDisconnected;
        description = @"The other device closed the connection.";
        break;
    default: {
        code = PVmGBALinkErrorSocketFailed;
        int err = session ? PVGBALinkSessionLastErrno(session) : 0;
        description = err ? [NSString stringWithUTF8String:strerror(err)] : @"Network error.";
        break;
    }
    }
    return [NSError errorWithDomain:PVmGBALinkErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: description }];
}

// MARK: - Session context

/// One link session: its socket session, its driver and its published state.
@interface PVmGBALinkContext : NSObject
@property (atomic) PVmGBALinkStatus status;
@property (atomic) uint16_t port;
@property (atomic, strong, nullable) NSError *disconnectError;
/// Set once the handshake is done; the emulation thread then installs the
/// driver.
@property (atomic) BOOL readyToInstall;
@property (nonatomic, readonly) PVGBALinkSession *session;
/// Emulation thread only.
@property (nonatomic) PVmGBANetLinkDriver *driver;
@property (nonatomic) uint64_t stallStartedMs;
@property (nonatomic) BOOL stallNoticePosted;
@end

@implementation PVmGBALinkContext

- (nullable instancetype)init {
    if ((self = [super init])) {
        _session = PVGBALinkSessionCreate();
        if (!_session) {
            return nil;
        }
        _status = PVmGBALinkStatusIdle;
    }
    return self;
}

- (void)dealloc {
    // The driver is out of the core by now: the bridge holds the context
    // while the driver is installed.
    PVGBALinkSessionDestroy(_session);
    PVmGBANetLinkDriverFree(_driver);
}

/// If the connection dropped on its own, record why and say so once.
- (void)noteCloseIfNeeded {
    PVGBALinkCloseReason reason;
    @synchronized (self) {
        if (self.status != PVmGBALinkStatusConnected || !PVGBALinkSessionIsClosed(_session)) {
            return;
        }
        reason = PVGBALinkSessionCloseReason(_session);
        if (reason == PVGBALinkCloseLocal) {
            return;
        }
        PVmGBALinkError code = reason == PVGBALinkCloseTimeout ? PVmGBALinkErrorTimedOut
                                                               : PVmGBALinkErrorPeerDisconnected;
        NSString *description = reason == PVGBALinkCloseTimeout
            ? @"The link partner stopped responding."
            : @"The link partner disconnected.";
        self.disconnectError = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                                   code:code
                                               userInfo:@{ NSLocalizedDescriptionKey: description }];
        self.status = PVmGBALinkStatusIdle;
    }
    _pvmgba_link_osd(reason == PVGBALinkCloseTimeout ? @"Link cable: partner stopped responding"
                                                     : @"Link cable: partner disconnected",
                     PVOSDTypeWarning);
}

/// The driver stopped being linked while the session is still open (a send
/// failed before the I/O thread noticed, or the driver gave up): end the
/// session (the peer gets a goodbye) and report it, so neither side is left
/// waiting.
- (void)failLink:(PVmGBANetLinkFailure)failure {
    BOOL connectionLost = failure == PVmGBANetLinkFailureConnection;
    @synchronized (self) {
        if (self.status != PVmGBALinkStatusConnected || PVGBALinkSessionIsClosed(_session)) {
            return;
        }
        PVmGBALinkError code = connectionLost ? PVmGBALinkErrorPeerDisconnected : PVmGBALinkErrorLinkFailed;
        NSString *description = connectionLost ? @"The connection to the link partner was lost."
                                               : @"The link cable lost sync.";
        self.disconnectError = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                                   code:code
                                               userInfo:@{ NSLocalizedDescriptionKey: description }];
        self.status = PVmGBALinkStatusIdle;
    }
    _pvmgba_link_stop_async(_session, self);
    _pvmgba_link_osd(connectionLost ? @"Link cable: connection lost" : @"Link cable: lost sync",
                     PVOSDTypeWarning);
}

@end

// MARK: - Bridge storage

static uint8_t kPVmGBALinkContextKey;
static uint8_t kPVmGBALinkInstalledKey;

@implementation PVmGBAGameCoreBridge (Netplay)

- (nullable PVmGBALinkContext *)pvmgba_linkContext {
    return objc_getAssociatedObject(self, &kPVmGBALinkContextKey);
}

- (void)pvmgba_setLinkContext:(nullable PVmGBALinkContext *)context {
    objc_setAssociatedObject(self, &kPVmGBALinkContextKey, context, OBJC_ASSOCIATION_RETAIN);
}

/// Claims the current-session slot. NO if a session already holds it.
- (BOOL)pvmgba_claimLinkContext:(PVmGBALinkContext *)context {
    os_unfair_lock_lock(&sPVmGBALinkSlotLock);
    PVmGBALinkContext *current = [self pvmgba_linkContext];
    // Busy unless it already ended on its own (closed, or hosting failed).
    BOOL busy = current && !current.disconnectError && !PVGBALinkSessionIsClosed(current.session);
    if (!busy) {
        [self pvmgba_setLinkContext:context];
    }
    os_unfair_lock_unlock(&sPVmGBALinkSlotLock);
    if (busy) {
        return NO;
    }
    if (current) {
        // A session that ended on its own but was never stopped.
        _pvmgba_link_stop_async(current.session, current);
    }
    return YES;
}

/// Clears the current-session slot if `context` still holds it.
- (void)pvmgba_releaseLinkContext:(PVmGBALinkContext *)context {
    os_unfair_lock_lock(&sPVmGBALinkSlotLock);
    if ([self pvmgba_linkContext] == context) {
        [self pvmgba_setLinkContext:nil];
    }
    os_unfair_lock_unlock(&sPVmGBALinkSlotLock);
}

// MARK: Status

- (PVmGBALinkStatus)linkStatus {
    PVmGBALinkContext *context = [self pvmgba_linkContext];
    [context noteCloseIfNeeded];
    return context ? context.status : PVmGBALinkStatusIdle;
}

- (BOOL)isLinkConnected {
    return self.linkStatus == PVmGBALinkStatusConnected;
}

- (uint16_t)linkPort {
    return [self pvmgba_linkContext].port;
}

- (nullable NSError *)lastDisconnectError {
    return [self pvmgba_linkContext].disconnectError;
}

// MARK: Control

- (BOOL)startLinkHostOnPort:(uint16_t)port
                   password:(nullable NSString *)password
                      error:(NSError *__autoreleasing _Nullable *)error {
    PVmGBALinkContext *context = [PVmGBALinkContext new];
    if (!context) {
        if (error) { *error = _pvmgba_link_error(PVGBALinkErrorSocket, NULL); }
        return NO;
    }
    uint16_t boundPort = 0;
    PVGBALinkResult result = PVGBALinkSessionListen(context.session, port, password.UTF8String, &boundPort);
    if (result != PVGBALinkOK) {
        if (error) { *error = _pvmgba_link_error(result, context.session); }
        return NO;
    }
    context.port = boundPort;
    context.status = PVmGBALinkStatusHosting;
    if (![self pvmgba_claimLinkContext:context]) {
        if (error) {
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorAlreadyActive
                                     userInfo:@{ NSLocalizedDescriptionKey: @"A link session is already active." }];
        }
        return NO;
    }

    [NSThread detachNewThreadWithBlock:^{
        PVGBALinkResult accepted = PVGBALinkSessionAccept(context.session, -1);
        if (accepted == PVGBALinkOK) {
            accepted = PVGBALinkSessionStart(context.session, NULL, NULL);
        }
        if (accepted == PVGBALinkOK) {
            context.readyToInstall = YES;
            context.status = PVmGBALinkStatusConnected;
            _pvmgba_link_osd(@"Link cable connected", PVOSDTypeSuccess);
        } else if (accepted != PVGBALinkErrorCancelled) {
            context.disconnectError = _pvmgba_link_error(accepted, context.session);
            context.status = PVmGBALinkStatusIdle;
            _pvmgba_link_osd(@"Link cable: hosting failed", PVOSDTypeError);
        }
    }];
    return YES;
}

- (BOOL)joinLinkAtHost:(NSString *)host
                  port:(uint16_t)port
              password:(nullable NSString *)password
                 error:(NSError *__autoreleasing _Nullable *)error {
    if (host.length == 0) {
        if (error) { *error = _pvmgba_link_error(PVGBALinkErrorResolve, NULL); }
        return NO;
    }
    PVmGBALinkContext *context = [PVmGBALinkContext new];
    if (!context) {
        if (error) { *error = _pvmgba_link_error(PVGBALinkErrorSocket, NULL); }
        return NO;
    }
    context.port = port;
    // Claim first so -stopLink can cancel the connect.
    if (![self pvmgba_claimLinkContext:context]) {
        if (error) {
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorAlreadyActive
                                     userInfo:@{ NSLocalizedDescriptionKey: @"A link session is already active." }];
        }
        return NO;
    }

    PVGBALinkResult result = PVGBALinkSessionConnect(context.session, host.UTF8String, port,
                                                     password.UTF8String, kPVmGBALinkConnectTimeoutMs);
    if (result == PVGBALinkOK) {
        result = PVGBALinkSessionStart(context.session, NULL, NULL);
    }
    if (result != PVGBALinkOK) {
        [self pvmgba_releaseLinkContext:context];
        if (error) { *error = _pvmgba_link_error(result, context.session); }
        return NO;
    }
    context.readyToInstall = YES;
    context.status = PVmGBALinkStatusConnected;
    _pvmgba_link_osd(@"Link cable connected", PVOSDTypeSuccess);
    return YES;
}

- (void)stopLink {
    os_unfair_lock_lock(&sPVmGBALinkSlotLock);
    PVmGBALinkContext *context = [self pvmgba_linkContext];
    [self pvmgba_setLinkContext:nil];
    os_unfair_lock_unlock(&sPVmGBALinkSlotLock);
    if (!context) {
        return;
    }
    context.status = PVmGBALinkStatusIdle;
    // Wakes a pending accept/connect and says goodbye to the peer, off this
    // thread. The emulation thread removes the driver at its next frame
    // whether or not the stop has finished.
    _pvmgba_link_stop_async(context.session, context);
}

@end

// MARK: - Emulation thread

@implementation PVmGBAGameCoreBridge (NetplayInternal)

- (nullable PVmGBALinkContext *)pvmgba_installedLink {
    return objc_getAssociatedObject(self, &kPVmGBALinkInstalledKey);
}

- (void)pvmgba_setInstalledLink:(nullable PVmGBALinkContext *)context {
    objc_setAssociatedObject(self, &kPVmGBALinkInstalledKey, context, OBJC_ASSOCIATION_RETAIN);
}

- (void)pvmgba_uninstallLink:(PVmGBALinkContext *)context core:(struct mCore *)core {
    struct GBA *gba = (struct GBA *) core->board;
    PVmGBANetLinkDriver *driver = context.driver;
    if (gba && driver && gba->sio.driver == PVmGBANetLinkDriverBase(driver)) {
        GBASIOSetDriver(&gba->sio, NULL);
    }
    PVmGBANetLinkDriverFree(driver);
    context.driver = NULL;
    [self pvmgba_setInstalledLink:nil];
}

- (BOOL)pvmgba_runLinkedFrame:(struct mCore *)core frameAdvanced:(BOOL *)frameAdvanced {
    *frameAdvanced = YES;
    if (!core) {
        return NO;
    }
    PVmGBALinkContext *current = [self pvmgba_linkContext];
    PVmGBALinkContext *installed = [self pvmgba_installedLink];
    [current noteCloseIfNeeded];

    // Stopped, replaced or lost: take the driver out.
    if (installed && (installed != current || !PVmGBANetLinkDriverIsLinked(installed.driver))) {
        PVmGBANetLinkFailure failure = PVmGBANetLinkDriverFailure(installed.driver);
        installed.readyToInstall = NO;
        [self pvmgba_uninstallLink:installed core:core];
        if (installed == current) {
            [installed failLink:failure];
        }
        installed = nil;
    }

    if (!installed && current.readyToInstall && core->platform(core) == mPLATFORM_GBA) {
        PVmGBANetLinkDriver *driver = PVmGBANetLinkDriverCreate(current.session);
        if (driver) {
            current.driver = driver;
            [self pvmgba_setInstalledLink:current];
            GBASIOSetDriver(&((struct GBA *) core->board)->sio, PVmGBANetLinkDriverBase(driver));
            installed = current;
        } else {
            current.readyToInstall = NO;
            [current failLink:PVmGBANetLinkFailureNone];
        }
    }
    if (!installed) {
        return NO;
    }

    bool stalled = false;
    *frameAdvanced = PVmGBANetLinkDriverRunFrame(installed.driver, core, kPVmGBALinkFrameWaitBudgetMs, &stalled);

    if (stalled) {
        uint64_t now = _pvmgba_link_now_ms();
        if (!installed.stallStartedMs) {
            installed.stallStartedMs = now;
        } else if (!installed.stallNoticePosted && now - installed.stallStartedMs >= kPVmGBALinkStallNoticeMs) {
            installed.stallNoticePosted = YES;
            _pvmgba_link_osd(@"Link cable: waiting for partner…", PVOSDTypeInfo);
        }
    } else if (*frameAdvanced) {
        installed.stallStartedMs = 0;
        installed.stallNoticePosted = NO;
    }
    return YES;
}

- (void)pvmgba_detachLinkFromCore:(struct mCore *)core {
    [self stopLink];
    PVmGBALinkContext *installed = [self pvmgba_installedLink];
    if (installed && core) {
        [self pvmgba_uninstallLink:installed core:core];
    }
}

@end
