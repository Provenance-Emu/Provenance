//
//  PVmGBAGameCoreBridge+Netplay.mm
//  PVCoremGBA
//
//  Created by Provenance Emu on 3/22/26.
//  Copyright © 2026 Provenance Emu. All rights reserved.
//
//  TCP link-cable netplay implementation for PVmGBAGameCoreBridge.
//
//  Architecture
//  ─────────────
//  Two compilation paths exist depending on whether the libmGBA submodule
//  headers are available at build time:
//
//  1. Full SIO integration (PVMGBA_LINK_SIO_AVAILABLE = 1)
//     – Requires <mgba/internal/gba/sio.h> and <mgba/gba/core.h>.
//     – Installs a custom GBASIODriver into the running mGBA core that
//       intercepts SIO multi-player register writes, sends this device's
//       SIODATA8 to the peer over TCP, receives the peer's SIODATA8, and
//       writes it back into the GBA's I/O memory so the game sees both
//       players' data after each transfer.
//     – This path is active in production builds (submodule populated).
//
//  2. TCP-only stub (PVMGBA_LINK_SIO_AVAILABLE = 0)
//     – Manages the TCP socket connection without hooking the SIO driver.
//     – The connection is established and tracked; actual byte exchange is
//       a no-op until the submodule is populated.
//     – This path exists so the file compiles in CI environments where the
//       submodule is not checked out.
//
//  Socket threading
//  ─────────────────
//  • `startLinkHostOnPort:` creates a listening server socket, then spawns
//    a GCD background task on `_pvmgbaLinkIOQueue` to accept the peer.
//  • `joinLinkAtHost:port:` connects synchronously (with a short timeout)
//    on a background queue.
//  • Once connected, the SIO driver (path 1) performs blocking send/recv
//    of exactly 2 bytes each call.  Because `writeRegister` is called from
//    the emulator thread, these calls block that thread very briefly — the
//    TCP round-trip on a local Wi-Fi LAN is typically < 2 ms, well within
//    the ~16 ms frame budget.
//
//  Associated-object keys
//  ───────────────────────
//  Session state (PVmGBALinkContext) is stored via ObjC associated objects
//  so this category does not need to modify the existing class extension
//  in mGBAGameCoreBridge.m.
//

#import "PVmGBAGameCoreBridge+Netplay.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// POSIX socket headers
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>    // memset, strerror
#include <stdio.h>     // snprintf
#include <stdatomic.h> // atomic_load, atomic_store

// ──────────────────────────────────────────────────────────────────────────────
// Conditional mGBA SIO integration
// ──────────────────────────────────────────────────────────────────────────────

#if __has_include(<mgba/internal/gba/sio.h>) && __has_include(<mgba/gba/core.h>)
    #define PVMGBA_LINK_SIO_AVAILABLE 1
    #include <mgba/internal/gba/sio.h>
    #include <mgba/gba/core.h>
    // GBA I/O register addresses used by SIO
    #ifndef REG_SIOCNT
        #define REG_SIOCNT   0x128
    #endif
    #ifndef REG_SIODATA8
        #define REG_SIODATA8 0x12A
    #endif
    // SIO_MULTI_BUSY is the transfer-in-progress flag in SIOCNT
    #ifndef SIO_MULTI_BUSY
        #define SIO_MULTI_BUSY 0x0080
    #endif
#else
    #define PVMGBA_LINK_SIO_AVAILABLE 0
#endif

// ──────────────────────────────────────────────────────────────────────────────
// Error domain
// ──────────────────────────────────────────────────────────────────────────────

NSErrorDomain const PVmGBALinkErrorDomain = @"com.provenance.mgba.link";

// ──────────────────────────────────────────────────────────────────────────────
// Associated-object key addresses (values are never read; addresses are keys)
// ──────────────────────────────────────────────────────────────────────────────

static uint8_t kPVmGBALinkContextKey;

// ──────────────────────────────────────────────────────────────────────────────
// Session context object
// ──────────────────────────────────────────────────────────────────────────────

/// Holds all mutable state for one link-cable session.
@interface PVmGBALinkContext : NSObject
@property (atomic) PVmGBALinkStatus status;
/// Listening server socket (host only); -1 when unused.
@property (atomic) int serverFD;
/// Accepted / connected peer socket; -1 until connected.
@property (atomic) int peerFD;
/// YES for the host (player 1 / master), NO for the client (player 2 / slave).
@property (nonatomic) BOOL isHost;
/// Serial queue for async socket accept operations.
@property (nonatomic, strong) dispatch_queue_t ioQueue;
/// Weak back-reference so the SIO driver can close the peer socket on error.
/// (Set to nil on teardown to break any retain cycles.)
@property (nonatomic, weak) PVmGBAGameCoreBridge *bridge;
/// Non-nil when the session was torn down due to an unexpected error (e.g. peer
/// disconnect). Nil when torn down cleanly via -stopLink.
@property (atomic, strong, nullable) NSError *lastDisconnectError;
@end

@implementation PVmGBALinkContext
- (instancetype)init {
    if ((self = [super init])) {
        _status   = PVmGBALinkStatusIdle;
        _serverFD = -1;
        _peerFD   = -1;
        _isHost   = NO;
        _ioQueue  = dispatch_queue_create("com.provenance.mgba.link.io",
                                          DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
- (void)closeAllSockets {
    // Synchronized to prevent double-close races between the emulation thread
    // (_tcpLinkWriteRegister on disconnect) and the main thread (-stopLink).
    @synchronized (self) {
        if (_peerFD != -1) {
            close(_peerFD);
            _peerFD = -1;
        }
        if (_serverFD != -1) {
            close(_serverFD);
            _serverFD = -1;
        }
    }
}
- (void)dealloc {
    // Ensure sockets are always closed even if -stopLink was not called.
    [self closeAllSockets];
}
@end

// ──────────────────────────────────────────────────────────────────────────────
// SIO driver (full path — requires mGBA headers)
// ──────────────────────────────────────────────────────────────────────────────

#if PVMGBA_LINK_SIO_AVAILABLE

/// Custom GBASIODriver that routes GBA SIO multi-player data over a TCP socket.
///
/// The struct layout places the GBASIODriver as the first member so that a
/// pointer to the outer struct can be safely cast to `struct GBASIODriver *`
/// and vice versa.
typedef struct PVmGBATCPLinkDriver {
    struct GBASIODriver d;      ///< MUST be the first member.
    __unsafe_unretained PVmGBALinkContext *ctx;  ///< Non-owning; outlived by ctx.
    _Atomic(bool) inactive;     ///< Set before uninstalling to guard in-flight callbacks.
} PVmGBATCPLinkDriver;

/// Attempt to access the private `core` ivar of PVmGBAGameCoreBridge at runtime.
static inline struct mCore * _Nullable _pvmgba_core(PVmGBAGameCoreBridge *bridge) {
    static Ivar ivar = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        ivar = class_getInstanceVariable(object_getClass(bridge), "core");
    });
    if (ivar == NULL) { return NULL; }
    return *((struct mCore * __unsafe_unretained *)((__bridge uint8_t *)bridge + ivar_getOffset(ivar)));
}

/// Called by the mGBA core when the game writes to a SIO register.
///
/// When SIOCNT is written with SIO_MULTI_BUSY set (transfer initiated):
///  1. Read this player's SIODATA8.
///  2. Send it to the peer as a big-endian uint16_t over TCP.
///  3. Receive the peer's SIODATA8.
///  4. Write the peer's data into the GBA's I/O memory so the game sees it.
///
/// The blocking send+recv here is intentional — the GBA SIO protocol
/// is inherently synchronous (the master waits for slaves), so stalling
/// the emulation thread by a LAN round-trip (< 2 ms typically) is
/// acceptable and matches how a physical link cable would behave.
static bool _tcpLinkWriteRegister(struct GBASIODriver *driver,
                                   uint32_t address,
                                   uint16_t value)
{
    PVmGBATCPLinkDriver *link = (PVmGBATCPLinkDriver *)driver;
    PVmGBALinkContext   *ctx  = link->ctx;

    // Return immediately if stopLink marked this driver as inactive.
    if (atomic_load(&link->inactive)) { return false; }

    // Snapshot the peer FD under the context lock to avoid a data race with
    // -stopLink (main thread) or the ioQueue accept block writing peerFD.
    int peerFD;
    @synchronized (ctx) {
        if (ctx == nil || ctx.peerFD < 0) { return false; }
        peerFD = ctx.peerFD;
    }

    if (address != REG_SIOCNT)        { return false; }
    if (!(value & SIO_MULTI_BUSY))    { return false; }

    // Retrieve the mCore pointer to read/write I/O memory.
    struct mCore *core = (struct mCore *)driver->p->p;  // GBASIO → GBA → mCore
    if (core == NULL) { return false; }

    // Player's own SIO data (SIODATA8, 8-bit, padded to 16-bit network word).
    uint16_t localData = core->rawRead16(core, REG_SIODATA8, -1);
    uint16_t netLocal  = htons(localData);

    // Send-all loop: send() may return fewer bytes than requested even for small
    // payloads. Retry until all bytes are written before proceeding to recv.
    {
        const uint8_t *ptr = (const uint8_t *)&netLocal;
        size_t remaining = sizeof(netLocal);
        while (remaining > 0) {
            ssize_t n = send(peerFD, ptr, remaining, 0);
            if (n <= 0) {
                if (n < 0 && errno == EINTR) { continue; }  // Retry on signal interruption
                // Peer socket closed or non-retryable error — tear down the session.
                NSError *disconnectErr =
                    [NSError errorWithDomain:PVmGBALinkErrorDomain
                                       code:PVmGBALinkErrorPeerDisconnected
                                   userInfo:@{ NSLocalizedDescriptionKey: @"Peer disconnected during SIO send." }];
                @synchronized (ctx) {
                    if (ctx.peerFD == peerFD) {  // guard against concurrent teardown
                        ctx.lastDisconnectError = disconnectErr;
                        ctx.status = PVmGBALinkStatusIdle;
                        [ctx closeAllSockets];
                    }
                }
                // NOTE: The SIO driver remains installed until -stopLink is called by
                // the Swift polling layer after it observes lastDisconnectError.
                // Subsequent writeRegister calls return early (peerFD == -1).
                return false;
            }
            ptr       += n;
            remaining -= (size_t)n;
        }
    }

    // Receive peer's data. SO_RCVTIMEO is set on this socket (2-second deadline)
    // so a stalled peer triggers EAGAIN/EWOULDBLOCK rather than hanging indefinitely.
    // Retry on EINTR to avoid spurious disconnects from signal interruptions.
    uint16_t netRemote = 0;
    ssize_t recvd;
    do {
        recvd = recv(peerFD, &netRemote, sizeof(netRemote), MSG_WAITALL);
    } while (recvd < 0 && errno == EINTR);
    if (recvd != (ssize_t)sizeof(netRemote)) {
        int recvErrno = errno;
        NSString *desc = (recvd == 0)
            ? @"Peer disconnected during SIO receive."
            : ((recvErrno == EAGAIN || recvErrno == EWOULDBLOCK)
               ? @"SIO receive timed out — peer may be stalled."
               : [NSString stringWithUTF8String:strerror(recvErrno)]);
        NSError *disconnectErr =
            [NSError errorWithDomain:PVmGBALinkErrorDomain
                               code:PVmGBALinkErrorPeerDisconnected
                           userInfo:@{ NSLocalizedDescriptionKey: desc }];
        @synchronized (ctx) {
            if (ctx.peerFD == peerFD) {
                ctx.lastDisconnectError = disconnectErr;
                ctx.status = PVmGBALinkStatusIdle;
                [ctx closeAllSockets];
            }
        }
        return false;
    }

    uint16_t remoteData = ntohs(netRemote);

    // Write the peer's data into the GBA I/O memory so the game can read it.
    // SIODATA8 offset 0 is player 1 (master), offset 2 is player 2 (slave).
    // Host is player 1 (master), client is player 2 (slave).
    if (ctx.isHost) {
        // We are master; write slave's data to SIODATA8[1].
        core->rawWrite16(core, REG_SIODATA8 + 2, -1, remoteData);
    } else {
        // We are slave; write master's data to SIODATA8[0].
        core->rawWrite16(core, REG_SIODATA8, -1, remoteData);
    }

    return false; // false = let the core continue handling the register write
}

/// Allocate and configure a PVmGBATCPLinkDriver for the given context.
static PVmGBATCPLinkDriver *_pvmgba_create_driver(PVmGBALinkContext *ctx) {
    PVmGBATCPLinkDriver *drv = (PVmGBATCPLinkDriver *)calloc(1, sizeof(PVmGBATCPLinkDriver));
    if (drv == NULL) { return NULL; }
    // Minimal driver — only writeRegister is needed for SIO_MULTI.
    drv->d.init          = NULL;
    drv->d.deinit        = NULL;
    drv->d.load          = NULL;
    drv->d.unload        = NULL;
    drv->d.writeRegister = _tcpLinkWriteRegister;
    drv->ctx             = ctx;
    return drv;
}

/// Install the TCP link driver into the GBA SIO for SIO_MULTI mode.
///
/// Returns YES on success.  Logs a warning and returns NO if the core
/// or board pointer is unavailable (e.g. ROM not yet loaded).
static BOOL _pvmgba_install_driver(PVmGBAGameCoreBridge *bridge,
                                   PVmGBATCPLinkDriver *drv)
{
    struct mCore *core = _pvmgba_core(bridge);
    if (core == NULL) { return NO; }

    struct GBA *gba = (struct GBA *)core->board;
    if (gba == NULL)  { return NO; }

    GBASIOSetDriver(&gba->sio, &drv->d, SIO_MULTI);
    return YES;
}

/// Remove any installed TCP link driver from the SIO and free its memory.
static void _pvmgba_uninstall_driver(PVmGBAGameCoreBridge *bridge,
                                     PVmGBATCPLinkDriver *drv)
{
    if (drv == NULL) { return; }
    struct mCore *core = _pvmgba_core(bridge);
    if (core != NULL) {
        struct GBA *gba = (struct GBA *)core->board;
        if (gba != NULL) {
            GBASIOSetDriver(&gba->sio, NULL, SIO_MULTI);
        }
    }
    free(drv);
}

#endif // PVMGBA_LINK_SIO_AVAILABLE

// ──────────────────────────────────────────────────────────────────────────────
// Private driver storage (associated object, second key)
// ──────────────────────────────────────────────────────────────────────────────

static uint8_t kPVmGBALinkDriverKey;  // Key for the PVmGBATCPLinkDriver* NSValue

// ──────────────────────────────────────────────────────────────────────────────
// Helper: build NSError from errno
// ──────────────────────────────────────────────────────────────────────────────

static NSError *_pvmgba_socket_error(PVmGBALinkError code, int err) {
    NSString *detail = [NSString stringWithUTF8String:strerror(err)];
    return [NSError errorWithDomain:PVmGBALinkErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: detail }];
}

// ──────────────────────────────────────────────────────────────────────────────
// Category implementation
// ──────────────────────────────────────────────────────────────────────────────

@implementation PVmGBAGameCoreBridge (Netplay)

// MARK: - Associated-object helpers

- (nullable PVmGBALinkContext *)_linkContext {
    return objc_getAssociatedObject(self, &kPVmGBALinkContextKey);
}

- (PVmGBALinkContext *)_linkContextCreatingIfNeeded {
    PVmGBALinkContext *ctx = [self _linkContext];
    if (ctx == nil) {
        ctx = [[PVmGBALinkContext alloc] init];
        ctx.bridge = self;
        objc_setAssociatedObject(self, &kPVmGBALinkContextKey,
                                 ctx, OBJC_ASSOCIATION_RETAIN);
    }
    return ctx;
}

- (void)_clearLinkContext {
    objc_setAssociatedObject(self, &kPVmGBALinkContextKey,
                             nil, OBJC_ASSOCIATION_RETAIN);
}

// MARK: - Status properties

- (PVmGBALinkStatus)linkStatus {
    PVmGBALinkContext *ctx = [self _linkContext];
    return ctx ? ctx.status : PVmGBALinkStatusIdle;
}

- (BOOL)isLinkConnected {
    return self.linkStatus == PVmGBALinkStatusConnected;
}

- (nullable NSError *)lastDisconnectError {
    return [self _linkContext].lastDisconnectError;
}

// MARK: - startLinkHostOnPort:error:

- (BOOL)startLinkHostOnPort:(uint16_t)port
                      error:(NSError *__autoreleasing _Nullable *)error
{
    // Reject privileged and unassigned ports (documented range is 1024-65535, or 0 for OS-assigned).
    if (port > 0 && port < 1024) {
        if (error) {
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorInvalidAddress
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                     @"Port must be in the range 1024–65535 (or 0 for OS-assigned)." }];
        }
        return NO;
    }

    // Reject if a session is already active.
    PVmGBALinkContext *existing = [self _linkContext];
    if (existing && existing.status != PVmGBALinkStatusIdle) {
        if (error) {
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorAlreadyActive
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                     @"A link session is already active." }];
        }
        return NO;
    }

    // Create TCP server socket.
    int serverFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (serverFD < 0) {
        if (error) { *error = _pvmgba_socket_error(PVmGBALinkErrorSocketFailed, errno); }
        return NO;
    }

    // SO_REUSEADDR so we can restart quickly.
    // SO_NOSIGPIPE prevents SIGPIPE if the peer closes the connection.
    int yes = 1;
    setsockopt(serverFD, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    setsockopt(serverFD, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(port);

    if (bind(serverFD, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        int err = errno;
        close(serverFD);
        if (error) { *error = _pvmgba_socket_error(PVmGBALinkErrorSocketFailed, err); }
        return NO;
    }

    if (listen(serverFD, 1) < 0) {
        int err = errno;
        close(serverFD);
        if (error) { *error = _pvmgba_socket_error(PVmGBALinkErrorSocketFailed, err); }
        return NO;
    }

    // Context is ready — status transitions to Hosting.
    PVmGBALinkContext *ctx = [self _linkContextCreatingIfNeeded];
    ctx.serverFD = serverFD;
    ctx.isHost   = YES;
    ctx.status   = PVmGBALinkStatusHosting;

    // Accept the peer asynchronously on the I/O queue.
    __weak typeof(self) weakSelf = self;
    dispatch_async(ctx.ioQueue, ^{
        struct sockaddr_in peerAddr;
        socklen_t peerLen = sizeof(peerAddr);
        int peerFD = accept(serverFD, (struct sockaddr *)&peerAddr, &peerLen);

        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) { return; }

        PVmGBALinkContext *ctx2 = [strongSelf _linkContext];
        if (ctx2 == nil || ctx2.status != PVmGBALinkStatusHosting) {
            // Session was cancelled while waiting.
            if (peerFD >= 0) { close(peerFD); }
            return;
        }

        if (peerFD < 0) {
            // accept() failed (likely -stopLink was called). Clean up the listening socket.
            @synchronized (ctx2) {
                if (ctx2.serverFD >= 0) {
                    close(ctx2.serverFD);
                    ctx2.serverFD = -1;
                }
                ctx2.status = PVmGBALinkStatusIdle;
            }
            return;
        }

        // Suppress SIGPIPE on the accepted peer socket.
        int nosig2 = 1;
        setsockopt(peerFD, SOL_SOCKET, SO_NOSIGPIPE, &nosig2, sizeof(nosig2));
        // Bound the emulation-thread recv() to 2 seconds so a stalled peer
        // doesn't hang the emulator indefinitely.
        struct timeval rcvTimeout2 = { .tv_sec = 2, .tv_usec = 0 };
        setsockopt(peerFD, SOL_SOCKET, SO_RCVTIMEO, &rcvTimeout2, sizeof(rcvTimeout2));

#if PVMGBA_LINK_SIO_AVAILABLE
        // Install the SIO driver now that a peer is connected.
        PVmGBATCPLinkDriver *drv = _pvmgba_create_driver(ctx2);
        if (drv == NULL) {
            // Driver allocation failed; treat as a hard failure and tear down.
            close(peerFD);
            @synchronized (ctx2) {
                ctx2.peerFD = -1;
                ctx2.status = PVmGBALinkStatusIdle;
            }
            return;
        }

        if (_pvmgba_install_driver(strongSelf, drv)) {
            NSValue *drvValue = [NSValue valueWithPointer:drv];
            objc_setAssociatedObject(strongSelf,
                                     &kPVmGBALinkDriverKey,
                                     drvValue,
                                     OBJC_ASSOCIATION_RETAIN);
            @synchronized (ctx2) {
                ctx2.peerFD   = peerFD;
                // 2-player link cable: close the listening socket once a peer is accepted.
                if (ctx2.serverFD >= 0) {
                    close(ctx2.serverFD);
                    ctx2.serverFD = -1;
                }
                ctx2.status = PVmGBALinkStatusConnected;
            }
        } else {
            // Driver installation failed (core not ready); tear down the session.
            free(drv);
            close(peerFD);
            @synchronized (ctx2) {
                ctx2.peerFD = -1;
                ctx2.status = PVmGBALinkStatusIdle;
            }
        }
#else
        // When SIO is not available, consider the link connected once a peer is accepted.
        @synchronized (ctx2) {
            ctx2.peerFD   = peerFD;
            // 2-player link cable: close the listening socket once a peer is accepted.
            if (ctx2.serverFD >= 0) {
                close(ctx2.serverFD);
                ctx2.serverFD = -1;
            }
            ctx2.status = PVmGBALinkStatusConnected;
        }
#endif
    });

    return YES;
}

// MARK: - joinLinkAtHost:port:error:

- (BOOL)joinLinkAtHost:(NSString *)host
                  port:(uint16_t)port
                 error:(NSError *__autoreleasing _Nullable *)error
{
    if (host.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorInvalidAddress
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                     @"Host address must not be empty." }];
        }
        return NO;
    }

    // Reject privileged and unassigned ports — same range as -startLinkHostOnPort:.
    if (port > 0 && port < 1024) {
        if (error) {
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorInvalidAddress
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                     @"Port must be in the range 1024–65535 (or 0 for OS-assigned)." }];
        }
        return NO;
    }

    PVmGBALinkContext *existing = [self _linkContext];
    if (existing && existing.status != PVmGBALinkStatusIdle) {
        if (error) {
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorAlreadyActive
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                     @"A link session is already active." }];
        }
        return NO;
    }

    // Resolve host and create socket.
    struct addrinfo hints, *res;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family   = AF_UNSPEC;   // Support both IPv4 and IPv6 (required for App Store)
    hints.ai_socktype = SOCK_STREAM;

    char portStr[8];
    snprintf(portStr, sizeof(portStr), "%u", (unsigned)port);

    int gaiErr = getaddrinfo(host.UTF8String, portStr, &hints, &res);
    if (gaiErr != 0) {
        if (error) {
            NSString *desc = [NSString stringWithFormat:@"Cannot resolve host '%@': %s",
                              host, gai_strerror(gaiErr)];
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorInvalidAddress
                                     userInfo:@{ NSLocalizedDescriptionKey: desc }];
        }
        return NO;
    }

    // Iterate resolved addresses (IPv4 and IPv6) and try each until one connects.
    int sockFD = -1;
    NSError *lastConnectError = nil;
    for (struct addrinfo *rp = res; rp != NULL; rp = rp->ai_next) {
        int fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if (fd < 0) { continue; }

        // Suppress SIGPIPE on this candidate socket.
        int nosig = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &nosig, sizeof(nosig));

        // Apply a 5-second connect timeout via non-blocking connect + select.
        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);

        int connectResult = connect(fd, rp->ai_addr, rp->ai_addrlen);
        if (connectResult < 0 && errno != EINPROGRESS) {
            lastConnectError = _pvmgba_socket_error(PVmGBALinkErrorSocketFailed, errno);
            close(fd);
            continue;
        }

        if (connectResult != 0) {
            fd_set writeSet;
            FD_ZERO(&writeSet);
            FD_SET(fd, &writeSet);
            struct timeval tv = { .tv_sec = 5, .tv_usec = 0 };
            int sel = select(fd + 1, NULL, &writeSet, NULL, &tv);
            if (sel <= 0) {
                NSString *desc = (sel == 0)
                    ? [NSString stringWithFormat:@"Connection to %@:%u timed out.", host, (unsigned)port]
                    : [NSString stringWithUTF8String:strerror(errno)];
                lastConnectError = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                                       code:PVmGBALinkErrorSocketFailed
                                                   userInfo:@{ NSLocalizedDescriptionKey: desc }];
                close(fd);
                continue;
            }
            int soErr = 0;
            socklen_t soErrLen = sizeof(soErr);
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &soErr, &soErrLen);
            if (soErr != 0) {
                lastConnectError = _pvmgba_socket_error(PVmGBALinkErrorSocketFailed, soErr);
                close(fd);
                continue;
            }
        }

        // Restore exact original descriptor flags (not just mask-off O_NONBLOCK).
        fcntl(fd, F_SETFL, flags);
        sockFD = fd;
        break;
    }
    freeaddrinfo(res);

    if (sockFD < 0) {
        if (error) { *error = lastConnectError ?: _pvmgba_socket_error(PVmGBALinkErrorSocketFailed, ECONNREFUSED); }
        return NO;
    }

    // Bound the emulation-thread recv() to 2 seconds so a stalled peer
    // doesn't hang the emulator indefinitely.
    {
        struct timeval rcvTimeout = { .tv_sec = 2, .tv_usec = 0 };
        setsockopt(sockFD, SOL_SOCKET, SO_RCVTIMEO, &rcvTimeout, sizeof(rcvTimeout));
    }

    // Session is connected.
    PVmGBALinkContext *ctx = [self _linkContextCreatingIfNeeded];
    ctx.peerFD = sockFD;
    ctx.isHost = NO;

#if PVMGBA_LINK_SIO_AVAILABLE
    PVmGBATCPLinkDriver *drv = _pvmgba_create_driver(ctx);
    if (drv == NULL) {
        // Driver allocation failed; tear down the connection.
        close(sockFD);
        ctx.peerFD = -1;
        [self _clearLinkContext];
        if (error) {
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorNotReady
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                     @"Failed to allocate SIO driver." }];
        }
        return NO;
    }

    if (_pvmgba_install_driver(self, drv)) {
        NSValue *drvValue = [NSValue valueWithPointer:drv];
        objc_setAssociatedObject(self,
                                 &kPVmGBALinkDriverKey,
                                 drvValue,
                                 OBJC_ASSOCIATION_RETAIN);
        ctx.status = PVmGBALinkStatusConnected;
    } else {
        // Driver installation failed (core not ready); tear down.
        free(drv);
        close(sockFD);
        ctx.peerFD = -1;
        [self _clearLinkContext];
        if (error) {
            *error = [NSError errorWithDomain:PVmGBALinkErrorDomain
                                         code:PVmGBALinkErrorNotReady
                                     userInfo:@{ NSLocalizedDescriptionKey:
                                                     @"Core not ready; load a ROM before joining a link session." }];
        }
        return NO;
    }
#else
    ctx.status = PVmGBALinkStatusConnected;
#endif

    return YES;
}

// MARK: - stopLink

- (void)stopLink {
#if PVMGBA_LINK_SIO_AVAILABLE
    // Remove the SIO driver first so no more callbacks fire.
    NSValue *drvValue = objc_getAssociatedObject(self, &kPVmGBALinkDriverKey);
    if (drvValue != nil) {
        PVmGBATCPLinkDriver *drv = (PVmGBATCPLinkDriver *)[drvValue pointerValue];
        // Mark the driver inactive before uninstalling so any in-flight
        // _tcpLinkWriteRegister callback returns early and does not access
        // memory that will be freed by _pvmgba_uninstall_driver.
        if (drv != NULL) { atomic_store(&drv->inactive, true); }
        _pvmgba_uninstall_driver(self, drv);
        objc_setAssociatedObject(self, &kPVmGBALinkDriverKey,
                                 nil, OBJC_ASSOCIATION_RETAIN);
    }
#endif

    PVmGBALinkContext *ctx = [self _linkContext];
    if (ctx == nil) { return; }

    // Clean teardown — clear any previous disconnect error.
    ctx.lastDisconnectError = nil;
    ctx.status = PVmGBALinkStatusIdle;
    ctx.bridge = nil;
    [ctx closeAllSockets];
    [self _clearLinkContext];
}

@end
