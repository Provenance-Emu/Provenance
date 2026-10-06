//
//  PVmGBALink.c
//  PVCoremGBA
//
//  TCP transport for the mGBA network link cable. See PVmGBALink.h.
//
//  Wire format (protocol version 1). Every message is 36 bytes, little-endian:
//
//    offset  size  field
//    0       1     type
//    1       1     player
//    2       1     mode (signed)
//    3       1     reserved
//    4       8     time
//    12      8     finish
//    20      16    data[4]
//
//  Handshake: the client sends HELLO (data[0] = magic "PVGL", data[1] =
//  protocol version, time = password hash). The host answers WELCOME
//  (player = the client's player number, data[0] = player count) or REJECT
//  (data[0] = reason).
//

#include "PVmGBALink.h"

#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

// Session-internal message types (never reach the inbox).
enum {
    kMessageHello = 1,
    kMessageWelcome = 2,
    kMessageReject = 3,
    kMessageHeartbeat = 4,
    kMessageBye = 5,
};

enum {
    kRejectVersion = 1,
    kRejectPassword = 2,
    kRejectFull = 3,
};

/// "PVGL", little-endian.
static const uint32_t kProtocolMagic = 0x4C475650u;

static const int kHeartbeatIntervalMs = 1000;
static const int kPeerTimeoutMs = 5000;
static const int kHandshakeTimeoutMs = 5000;
/// Longest single poll(), so deadlines are checked regularly.
static const int kPollSliceMs = 250;
static const int kSendTimeoutMs = 2000;
static const int kListenBacklog = 4;
static const size_t kInitialInboxCapacity = 64;
/// Received messages not yet taken. Clock messages coalesce, so only a peer
/// that floods transfers or mode changes can reach this; the session closes.
static const size_t kMaxInboxMessages = 4096;
/// Bytes queued for a peer that has stopped reading before the link is
/// declared lost.
#define kMaxOutboxBytes (64 * 1024)
/// How long to wait for a host name to resolve.
static const int kResolveTimeoutMs = 5000;
/// Bytes the I/O thread reads at once: a whole number of messages.
#define kReadBufferMessages 64

/// The host plus one client.
static const int kSupportedPlayers = 2;

struct PVGBALinkSession {
    pthread_mutex_t lock;     // fds, state, inbox
    pthread_cond_t cond;      // inbox or state changed
    pthread_mutex_t sendLock; // outbox
    pthread_mutex_t stopLock; // one Stop at a time

    int listenFD;
    int peerFD;
    int wakeRead;   // readable once Stop is called
    int wakeWrite;
    int kickRead;   // "the outbox has data" for the I/O thread
    int kickWrite;

    atomic_bool stopping;
    bool stopped;
    bool handshakeDone;
    bool threadStarted;
    pthread_t thread;
    bool closed;
    PVGBALinkCloseReason closeReason;
    atomic_int lastErrno;

    int playerId;
    int playerCount;
    uint64_t passwordHash;

    PVGBALinkMessage *inbox;
    size_t inboxCapacity;
    size_t inboxHead;
    size_t inboxCount;

    PVGBALinkClosedCallback callback;
    void *callbackContext;

    _Atomic uint64_t lastSendMs;

    uint8_t outbox[kMaxOutboxBytes];
    size_t outboxLength;
};

// MARK: - Helpers

static uint64_t _nowMs(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t) ts.tv_sec * 1000u + (uint64_t) ts.tv_nsec / 1000000u;
}

static uint64_t _passwordHash(const char *password) {
    if (!password || !password[0]) {
        return 0;
    }
    // FNV-1a, 64-bit.
    uint64_t hash = 0xcbf29ce484222325ull;
    for (const unsigned char *p = (const unsigned char *) password; *p; ++p) {
        hash ^= *p;
        hash *= 0x100000001b3ull;
    }
    return hash ? hash : 1;
}

static void _put32(uint8_t *buffer, uint32_t value) {
    for (int i = 0; i < 4; ++i) {
        buffer[i] = (uint8_t) (value >> (8 * i));
    }
}

static void _put64(uint8_t *buffer, uint64_t value) {
    for (int i = 0; i < 8; ++i) {
        buffer[i] = (uint8_t) (value >> (8 * i));
    }
}

static uint32_t _get32(const uint8_t *buffer) {
    uint32_t value = 0;
    for (int i = 0; i < 4; ++i) {
        value |= (uint32_t) buffer[i] << (8 * i);
    }
    return value;
}

static uint64_t _get64(const uint8_t *buffer) {
    uint64_t value = 0;
    for (int i = 0; i < 8; ++i) {
        value |= (uint64_t) buffer[i] << (8 * i);
    }
    return value;
}

void PVGBALinkEncode(const PVGBALinkMessage *message, uint8_t *buffer) {
    buffer[0] = message->type;
    buffer[1] = message->player;
    buffer[2] = (uint8_t) message->mode;
    buffer[3] = message->reserved;
    _put64(buffer + 4, message->time);
    _put64(buffer + 12, message->finish);
    for (int i = 0; i < PVGBALINK_MAX_PLAYERS; ++i) {
        _put32(buffer + 20 + 4 * i, message->data[i]);
    }
}

void PVGBALinkDecode(const uint8_t *buffer, PVGBALinkMessage *message) {
    message->type = buffer[0];
    message->player = buffer[1];
    message->mode = (int8_t) buffer[2];
    message->reserved = buffer[3];
    message->time = _get64(buffer + 4);
    message->finish = _get64(buffer + 12);
    for (int i = 0; i < PVGBALINK_MAX_PLAYERS; ++i) {
        message->data[i] = _get32(buffer + 20 + 4 * i);
    }
}

static int _remainingMs(uint64_t deadline) {
    if (!deadline) {
        return kPollSliceMs;
    }
    uint64_t now = _nowMs();
    if (now >= deadline) {
        return 0;
    }
    uint64_t remaining = deadline - now;
    return remaining > (uint64_t) kPollSliceMs ? kPollSliceMs : (int) remaining;
}

/// poll() on `fd` and the wake pipe. 1 = ready, 0 = timed out,
/// -1 = PVGBALinkSessionStop was called, -2 = error.
static int _pollWithWake(PVGBALinkSession *session, int fd, short events, int timeoutMs) {
    if (atomic_load(&session->stopping)) {
        return -1;
    }
    struct pollfd fds[2] = {
        { .fd = fd, .events = events },
        { .fd = session->wakeRead, .events = POLLIN },
    };
    int result = poll(fds, 2, timeoutMs);
    if (atomic_load(&session->stopping) || (result > 0 && fds[1].revents)) {
        return -1;
    }
    if (result < 0) {
        if (errno == EINTR) {
            return 0;
        }
        atomic_store(&session->lastErrno, errno);
        return -2;
    }
    return result > 0 ? 1 : 0;
}

static bool _writeAll(PVGBALinkSession *session, int fd, const uint8_t *buffer, size_t length) {
    size_t sent = 0;
    while (sent < length) {
        ssize_t n = send(fd, buffer + sent, length - sent, 0);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            atomic_store(&session->lastErrno, errno);
            return false;
        }
        sent += (size_t) n;
    }
    return true;
}

/// Blocking send, for the handshake only (before the I/O thread exists).
static bool _sendRaw(PVGBALinkSession *session, int fd, const PVGBALinkMessage *message) {
    uint8_t buffer[PVGBALINK_WIRE_SIZE];
    PVGBALinkEncode(message, buffer);
    pthread_mutex_lock(&session->sendLock);
    bool ok = _writeAll(session, fd, buffer, sizeof(buffer));
    pthread_mutex_unlock(&session->sendLock);
    if (ok) {
        atomic_store(&session->lastSendMs, _nowMs());
    }
    return ok;
}

/// Reads one message during the handshake, giving up at `deadline`.
static PVGBALinkResult _readMessage(PVGBALinkSession *session, int fd, PVGBALinkMessage *message,
                                    uint64_t deadline) {
    uint8_t buffer[PVGBALINK_WIRE_SIZE];
    size_t have = 0;
    while (have < sizeof(buffer)) {
        int slice = _remainingMs(deadline);
        if (slice == 0) {
            return PVGBALinkErrorTimeout;
        }
        int ready = _pollWithWake(session, fd, POLLIN, slice);
        if (ready == -1) {
            return PVGBALinkErrorCancelled;
        }
        if (ready == -2) {
            return PVGBALinkErrorSocket;
        }
        if (ready == 0) {
            continue;
        }
        ssize_t n = recv(fd, buffer + have, sizeof(buffer) - have, 0);
        if (n == 0) {
            return PVGBALinkErrorClosed;
        }
        if (n < 0) {
            if (errno == EINTR || errno == EAGAIN) {
                continue;
            }
            atomic_store(&session->lastErrno, errno);
            return PVGBALinkErrorSocket;
        }
        have += (size_t) n;
    }
    PVGBALinkDecode(buffer, message);
    return PVGBALinkOK;
}

/// Blocking I/O with bounded sends, no SIGPIPE and no Nagle delay.
static void _configurePeerSocket(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags >= 0) {
        fcntl(fd, F_SETFL, flags & ~O_NONBLOCK);
    }
    int one = 1;
    setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
#ifdef SO_NOSIGPIPE
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
#endif
    struct timeval sendTimeout = {
        .tv_sec = kSendTimeoutMs / 1000,
        .tv_usec = (kSendTimeoutMs % 1000) * 1000,
    };
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &sendTimeout, sizeof(sendTimeout));
}

static void _setNonBlocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags >= 0) {
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
}

// MARK: - Lifecycle

PVGBALinkSession *PVGBALinkSessionCreate(void) {
    PVGBALinkSession *session = calloc(1, sizeof(*session));
    if (!session) {
        return NULL;
    }
    int wakeFDs[2];
    int kickFDs[2];
    if (pipe(wakeFDs) != 0) {
        free(session);
        return NULL;
    }
    if (pipe(kickFDs) != 0) {
        close(wakeFDs[0]);
        close(wakeFDs[1]);
        free(session);
        return NULL;
    }
    int pipes[4] = { wakeFDs[0], wakeFDs[1], kickFDs[0], kickFDs[1] };
    for (int i = 0; i < 4; ++i) {
        _setNonBlocking(pipes[i]);
        fcntl(pipes[i], F_SETFD, FD_CLOEXEC);
    }

    pthread_mutex_init(&session->lock, NULL);
    pthread_mutex_init(&session->sendLock, NULL);
    pthread_mutex_init(&session->stopLock, NULL);
    pthread_cond_init(&session->cond, NULL);
    session->listenFD = -1;
    session->peerFD = -1;
    session->wakeRead = wakeFDs[0];
    session->wakeWrite = wakeFDs[1];
    session->kickRead = kickFDs[0];
    session->kickWrite = kickFDs[1];
    session->playerId = -1;
    atomic_init(&session->stopping, false);
    atomic_init(&session->lastErrno, 0);
    atomic_init(&session->lastSendMs, 0);
    return session;
}

void PVGBALinkSessionDestroy(PVGBALinkSession *session) {
    if (!session) {
        return;
    }
    PVGBALinkSessionStop(session);
    if (session->peerFD >= 0) {
        close(session->peerFD);
    }
    if (session->listenFD >= 0) {
        close(session->listenFD);
    }
    close(session->wakeRead);
    close(session->wakeWrite);
    close(session->kickRead);
    close(session->kickWrite);
    pthread_cond_destroy(&session->cond);
    pthread_mutex_destroy(&session->stopLock);
    pthread_mutex_destroy(&session->sendLock);
    pthread_mutex_destroy(&session->lock);
    free(session->inbox);
    free(session);
}

// MARK: - Host

static int _bindListener(int family, uint16_t port) {
    int fd = socket(family, SOCK_STREAM, 0);
    if (fd < 0) {
        return -1;
    }
    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    int result;
    if (family == AF_INET6) {
        int off = 0;
        setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &off, sizeof(off));
        struct sockaddr_in6 address = {
            .sin6_family = AF_INET6,
            .sin6_port = htons(port),
            .sin6_addr = in6addr_any,
        };
#ifdef SIN6_LEN
        address.sin6_len = sizeof(address);
#endif
        result = bind(fd, (struct sockaddr *) &address, sizeof(address));
    } else {
        struct sockaddr_in address = {
            .sin_family = AF_INET,
            .sin_port = htons(port),
            .sin_addr.s_addr = htonl(INADDR_ANY),
        };
#ifdef SIN6_LEN
        address.sin_len = sizeof(address);
#endif
        result = bind(fd, (struct sockaddr *) &address, sizeof(address));
    }
    if (result != 0 || listen(fd, kListenBacklog) != 0) {
        int savedErrno = errno;
        close(fd);
        errno = savedErrno;
        return -1;
    }
    _setNonBlocking(fd);
    fcntl(fd, F_SETFD, FD_CLOEXEC);
    return fd;
}

PVGBALinkResult PVGBALinkSessionListen(PVGBALinkSession *session, uint16_t port,
                                       const char *password, uint16_t *outPort) {
    pthread_mutex_lock(&session->lock);
    bool busy = session->listenFD >= 0 || session->peerFD >= 0 || session->handshakeDone;
    pthread_mutex_unlock(&session->lock);
    if (busy || atomic_load(&session->stopping)) {
        return PVGBALinkErrorState;
    }

    // Dual-stack IPv6 takes IPv4 clients as v4-mapped addresses.
    int fd = _bindListener(AF_INET6, port);
    if (fd < 0) {
        fd = _bindListener(AF_INET, port);
    }
    if (fd < 0) {
        atomic_store(&session->lastErrno, errno);
        return PVGBALinkErrorSocket;
    }

    struct sockaddr_storage bound;
    socklen_t length = sizeof(bound);
    uint16_t boundPort = port;
    if (getsockname(fd, (struct sockaddr *) &bound, &length) == 0) {
        if (bound.ss_family == AF_INET6) {
            boundPort = ntohs(((struct sockaddr_in6 *) &bound)->sin6_port);
        } else if (bound.ss_family == AF_INET) {
            boundPort = ntohs(((struct sockaddr_in *) &bound)->sin_port);
        }
    }

    pthread_mutex_lock(&session->lock);
    session->listenFD = fd;
    session->passwordHash = _passwordHash(password);
    pthread_mutex_unlock(&session->lock);
    if (outPort) {
        *outPort = boundPort;
    }
    return PVGBALinkOK;
}

static void _reject(PVGBALinkSession *session, int fd, uint32_t reason) {
    PVGBALinkMessage reject = { .type = kMessageReject, .mode = -1 };
    reject.data[0] = reason;
    _sendRaw(session, fd, &reject);
}

PVGBALinkResult PVGBALinkSessionAccept(PVGBALinkSession *session, int timeoutMs) {
    pthread_mutex_lock(&session->lock);
    int listenFD = session->listenFD;
    uint64_t passwordHash = session->passwordHash;
    pthread_mutex_unlock(&session->lock);
    if (listenFD < 0) {
        return PVGBALinkErrorState;
    }
    uint64_t deadline = timeoutMs < 0 ? 0 : _nowMs() + (uint64_t) timeoutMs;

    while (true) {
        int slice = _remainingMs(deadline);
        if (slice == 0) {
            return PVGBALinkErrorTimeout;
        }
        int ready = _pollWithWake(session, listenFD, POLLIN, slice);
        if (ready == -1) {
            return PVGBALinkErrorCancelled;
        }
        if (ready == -2) {
            return PVGBALinkErrorSocket;
        }
        if (ready == 0) {
            continue;
        }
        int fd = accept(listenFD, NULL, NULL);
        if (fd < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR || errno == ECONNABORTED) {
                continue;
            }
            atomic_store(&session->lastErrno, errno);
            return PVGBALinkErrorSocket;
        }
        fcntl(fd, F_SETFD, FD_CLOEXEC);
        _configurePeerSocket(fd);

        PVGBALinkMessage hello;
        PVGBALinkResult result = _readMessage(session, fd, &hello, _nowMs() + (uint64_t) kHandshakeTimeoutMs);
        if (result == PVGBALinkErrorCancelled) {
            close(fd);
            return result;
        }
        if (result != PVGBALinkOK || hello.type != kMessageHello || hello.data[0] != kProtocolMagic) {
            // Not one of ours (or gave up mid-handshake); keep waiting.
            close(fd);
            continue;
        }
        if (hello.data[1] != PVGBALINK_PROTOCOL_VERSION) {
            _reject(session, fd, kRejectVersion);
            close(fd);
            continue;
        }
        if (passwordHash && hello.time != passwordHash) {
            _reject(session, fd, kRejectPassword);
            close(fd);
            continue;
        }

        PVGBALinkMessage welcome = { .type = kMessageWelcome, .player = 1, .mode = -1 };
        welcome.data[0] = (uint32_t) kSupportedPlayers;
        if (!_sendRaw(session, fd, &welcome)) {
            close(fd);
            continue;
        }

        pthread_mutex_lock(&session->lock);
        if (atomic_load(&session->stopping)) {
            pthread_mutex_unlock(&session->lock);
            close(fd);
            return PVGBALinkErrorCancelled;
        }
        session->peerFD = fd;
        session->playerId = 0;
        session->playerCount = kSupportedPlayers;
        session->handshakeDone = true;
        // Two players: nobody else can join, so stop listening.
        close(session->listenFD);
        session->listenFD = -1;
        pthread_mutex_unlock(&session->lock);
        return PVGBALinkOK;
    }
}

// MARK: - Client

/// A getaddrinfo running on its own thread, so a slow DNS lookup can be
/// abandoned on a deadline or by Stop. Whichever side lets go last frees it.
typedef struct PVGBALinkResolve {
    atomic_int references;
    pthread_mutex_t lock;
    pthread_cond_t cond;
    bool done;
    int status;
    struct addrinfo *addresses;
    char host[256];
    char port[8];
} PVGBALinkResolve;

static void _releaseResolve(PVGBALinkResolve *resolve) {
    if (atomic_fetch_sub(&resolve->references, 1) != 1) {
        return;
    }
    if (resolve->addresses) {
        freeaddrinfo(resolve->addresses);
    }
    pthread_cond_destroy(&resolve->cond);
    pthread_mutex_destroy(&resolve->lock);
    free(resolve);
}

static const struct addrinfo kResolveHints = {
    .ai_family = AF_UNSPEC,
    .ai_socktype = SOCK_STREAM,
    .ai_protocol = IPPROTO_TCP,
    .ai_flags = AI_NUMERICSERV,
};

static void *_resolveThread(void *argument) {
    PVGBALinkResolve *resolve = argument;
    struct addrinfo *addresses = NULL;
    int status = getaddrinfo(resolve->host, resolve->port, &kResolveHints, &addresses);
    pthread_mutex_lock(&resolve->lock);
    resolve->status = status;
    resolve->addresses = addresses;
    resolve->done = true;
    pthread_cond_broadcast(&resolve->cond);
    pthread_mutex_unlock(&resolve->lock);
    _releaseResolve(resolve);
    return NULL;
}

/// Resolves `host`. Numeric addresses resolve at once; names go to a helper
/// thread that is abandoned after kResolveTimeoutMs or on Stop.
static PVGBALinkResult _resolve(PVGBALinkSession *session, const char *host, uint16_t port,
                                struct addrinfo **outAddresses) {
    char portString[8];
    snprintf(portString, sizeof(portString), "%u", (unsigned) port);
    struct addrinfo numericHints = kResolveHints;
    numericHints.ai_flags |= AI_NUMERICHOST;
    if (getaddrinfo(host, portString, &numericHints, outAddresses) == 0 && *outAddresses) {
        return PVGBALinkOK;
    }
    if (strlen(host) >= sizeof(((PVGBALinkResolve *) 0)->host)) {
        return PVGBALinkErrorResolve;
    }

    PVGBALinkResolve *resolve = calloc(1, sizeof(*resolve));
    if (!resolve) {
        return PVGBALinkErrorResolve;
    }
    atomic_init(&resolve->references, 2);
    pthread_mutex_init(&resolve->lock, NULL);
    pthread_cond_init(&resolve->cond, NULL);
    strcpy(resolve->host, host);
    strcpy(resolve->port, portString);
    pthread_t thread;
    if (pthread_create(&thread, NULL, _resolveThread, resolve) != 0) {
        resolve->references = 1;
        _releaseResolve(resolve);
        return PVGBALinkErrorResolve;
    }
    pthread_detach(thread);

    uint64_t deadline = _nowMs() + (uint64_t) kResolveTimeoutMs;
    PVGBALinkResult result = PVGBALinkErrorTimeout;
    pthread_mutex_lock(&resolve->lock);
    while (!resolve->done && !atomic_load(&session->stopping)) {
        int slice = _remainingMs(deadline);
        if (slice == 0) {
            break;
        }
        struct timespec wait = { .tv_sec = 0, .tv_nsec = (long) slice * 1000000L };
#ifdef __APPLE__
        pthread_cond_timedwait_relative_np(&resolve->cond, &resolve->lock, &wait);
#else
        struct timespec absolute;
        clock_gettime(CLOCK_REALTIME, &absolute);
        absolute.tv_nsec += wait.tv_nsec;
        if (absolute.tv_nsec >= 1000000000L) {
            absolute.tv_sec += 1;
            absolute.tv_nsec -= 1000000000L;
        }
        pthread_cond_timedwait(&resolve->cond, &resolve->lock, &absolute);
#endif
    }
    if (resolve->done) {
        if (resolve->status == 0 && resolve->addresses) {
            *outAddresses = resolve->addresses;
            resolve->addresses = NULL; // ours now
            result = PVGBALinkOK;
        } else {
            result = PVGBALinkErrorResolve;
        }
    } else if (atomic_load(&session->stopping)) {
        result = PVGBALinkErrorCancelled;
    }
    pthread_mutex_unlock(&resolve->lock);
    _releaseResolve(resolve);
    return result;
}

/// Tries each address in turn. Each gets an equal share of the time left, so
/// a black-holed IPv6 address doesn't use up the IPv4 one's chance.
static PVGBALinkResult _connectSocket(PVGBALinkSession *session, const char *host, uint16_t port,
                                      uint64_t deadline, int *outFD) {
    struct addrinfo *addresses = NULL;
    PVGBALinkResult result = _resolve(session, host, port, &addresses);
    if (result != PVGBALinkOK) {
        return result;
    }

    size_t remainingAddresses = 0;
    for (struct addrinfo *ai = addresses; ai; ai = ai->ai_next) {
        remainingAddresses += 1;
    }
    result = PVGBALinkErrorSocket;
    for (struct addrinfo *ai = addresses; ai; ai = ai->ai_next, --remainingAddresses) {
        uint64_t now = _nowMs();
        if (now >= deadline) {
            result = PVGBALinkErrorTimeout;
            break;
        }
        uint64_t addressDeadline = now + (deadline - now) / remainingAddresses;

        int fd = socket(ai->ai_family, ai->ai_socktype, ai->ai_protocol);
        if (fd < 0) {
            atomic_store(&session->lastErrno, errno);
            continue;
        }
        fcntl(fd, F_SETFD, FD_CLOEXEC);
        _setNonBlocking(fd);
        if (connect(fd, ai->ai_addr, ai->ai_addrlen) == 0) {
            *outFD = fd;
            result = PVGBALinkOK;
            break;
        }
        if (errno != EINPROGRESS) {
            atomic_store(&session->lastErrno, errno);
            close(fd);
            continue;
        }
        int ready = 0;
        while (ready == 0) {
            int slice = _remainingMs(addressDeadline);
            if (slice == 0) {
                break;
            }
            ready = _pollWithWake(session, fd, POLLOUT, slice);
        }
        if (ready == -1) {
            close(fd);
            result = PVGBALinkErrorCancelled;
            break;
        }
        if (ready == 0) {
            // This address timed out; try the next.
            close(fd);
            result = PVGBALinkErrorTimeout;
            continue;
        }
        int socketError = 0;
        socklen_t length = sizeof(socketError);
        if (ready < 0 || getsockopt(fd, SOL_SOCKET, SO_ERROR, &socketError, &length) != 0 || socketError) {
            atomic_store(&session->lastErrno, socketError ? socketError : errno);
            close(fd);
            continue;
        }
        *outFD = fd;
        result = PVGBALinkOK;
        break;
    }
    freeaddrinfo(addresses);
    return result;
}

PVGBALinkResult PVGBALinkSessionConnect(PVGBALinkSession *session, const char *host, uint16_t port,
                                        const char *password, int timeoutMs) {
    if (!host || !host[0]) {
        return PVGBALinkErrorResolve;
    }
    pthread_mutex_lock(&session->lock);
    bool busy = session->listenFD >= 0 || session->peerFD >= 0 || session->handshakeDone;
    pthread_mutex_unlock(&session->lock);
    if (busy || atomic_load(&session->stopping)) {
        return PVGBALinkErrorState;
    }
    uint64_t deadline = _nowMs() + (uint64_t) (timeoutMs > 0 ? timeoutMs : kHandshakeTimeoutMs);

    int fd = -1;
    PVGBALinkResult result = _connectSocket(session, host, port, deadline, &fd);
    if (result != PVGBALinkOK) {
        return result;
    }
    _configurePeerSocket(fd);

    PVGBALinkMessage hello = { .type = kMessageHello, .mode = -1, .time = _passwordHash(password) };
    hello.data[0] = kProtocolMagic;
    hello.data[1] = PVGBALINK_PROTOCOL_VERSION;
    if (!_sendRaw(session, fd, &hello)) {
        close(fd);
        return PVGBALinkErrorSocket;
    }

    PVGBALinkMessage reply;
    result = _readMessage(session, fd, &reply, deadline);
    if (result != PVGBALinkOK) {
        close(fd);
        return result;
    }
    if (reply.type == kMessageReject) {
        close(fd);
        switch (reply.data[0]) {
        case kRejectPassword:
            return PVGBALinkErrorWrongPassword;
        case kRejectVersion:
            return PVGBALinkErrorVersionMismatch;
        case kRejectFull:
            return PVGBALinkErrorSessionFull;
        default:
            return PVGBALinkErrorProtocol;
        }
    }
    if (reply.type != kMessageWelcome || reply.player == 0 || reply.player >= PVGBALINK_MAX_PLAYERS ||
        reply.data[0] < 2 || reply.data[0] > PVGBALINK_MAX_PLAYERS) {
        close(fd);
        return PVGBALinkErrorProtocol;
    }

    pthread_mutex_lock(&session->lock);
    if (atomic_load(&session->stopping)) {
        pthread_mutex_unlock(&session->lock);
        close(fd);
        return PVGBALinkErrorCancelled;
    }
    session->peerFD = fd;
    session->playerId = reply.player;
    session->playerCount = (int) reply.data[0];
    session->handshakeDone = true;
    pthread_mutex_unlock(&session->lock);
    return PVGBALinkOK;
}

// MARK: - I/O thread

/// Queues a received message. Consecutive clock messages of the same kind
/// collapse into the latest one (ADVANCE after ADVANCE, SYNC after SYNC):
/// only the newest clock matters and nothing is reordered. false when the
/// inbox is full or out of memory; the session then closes.
static bool _pushInbox(PVGBALinkSession *session, const PVGBALinkMessage *message) {
    bool isClock = message->type == PVGBALinkMessageAdvance || message->type == PVGBALinkMessageSync;
    if (isClock && session->inboxCount > 0) {
        size_t tail = (session->inboxHead + session->inboxCount - 1) % session->inboxCapacity;
        PVGBALinkMessage *last = &session->inbox[tail];
        if (last->type == message->type && last->player == message->player) {
            if (message->time > last->time) {
                last->time = message->time;
            }
            return true;
        }
    }
    if (session->inboxCount >= kMaxInboxMessages) {
        return false;
    }
    if (session->inboxCount == session->inboxCapacity) {
        size_t capacity = session->inboxCapacity ? session->inboxCapacity * 2 : kInitialInboxCapacity;
        PVGBALinkMessage *inbox = malloc(capacity * sizeof(*inbox));
        if (!inbox) {
            return false;
        }
        for (size_t i = 0; i < session->inboxCount; ++i) {
            inbox[i] = session->inbox[(session->inboxHead + i) % session->inboxCapacity];
        }
        free(session->inbox);
        session->inbox = inbox;
        session->inboxCapacity = capacity;
        session->inboxHead = 0;
    }
    size_t tail = (session->inboxHead + session->inboxCount) % session->inboxCapacity;
    session->inbox[tail] = *message;
    session->inboxCount += 1;
    return true;
}

/// Writes as much of the outbox as the socket takes without blocking.
/// Caller holds sendLock. false on a socket error.
static bool _flushOutboxLocked(PVGBALinkSession *session, int fd) {
    while (session->outboxLength > 0) {
        ssize_t n = send(fd, session->outbox, session->outboxLength, MSG_DONTWAIT);
        if (n < 0) {
            if (errno == EINTR) {
                continue;
            }
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                return true;
            }
            atomic_store(&session->lastErrno, errno);
            return false;
        }
        memmove(session->outbox, session->outbox + n, session->outboxLength - (size_t) n);
        session->outboxLength -= (size_t) n;
        atomic_store(&session->lastSendMs, _nowMs());
    }
    return true;
}

/// Sends without ever blocking: whatever the socket won't take now goes to
/// the outbox for the I/O thread. false on a socket error or a full outbox
/// (the peer stopped reading).
static bool _enqueueSend(PVGBALinkSession *session, int fd, const PVGBALinkMessage *message) {
    uint8_t buffer[PVGBALINK_WIRE_SIZE];
    PVGBALinkEncode(message, buffer);
    bool ok = true;
    bool kick = false;
    pthread_mutex_lock(&session->sendLock);
    if (session->outboxLength + sizeof(buffer) > kMaxOutboxBytes) {
        ok = false;
    } else {
        memcpy(session->outbox + session->outboxLength, buffer, sizeof(buffer));
        session->outboxLength += sizeof(buffer);
        ok = _flushOutboxLocked(session, fd);
        kick = ok && session->outboxLength > 0;
    }
    pthread_mutex_unlock(&session->sendLock);
    if (kick) {
        ssize_t written = write(session->kickWrite, "k", 1);
        (void) written;
    }
    return ok;
}

static bool _hasOutbox(PVGBALinkSession *session) {
    pthread_mutex_lock(&session->sendLock);
    bool pending = session->outboxLength > 0;
    pthread_mutex_unlock(&session->sendLock);
    return pending;
}

static void *_ioThread(void *argument) {
    PVGBALinkSession *session = argument;
#ifdef __APPLE__
    pthread_setname_np("com.provenance.mgba.link");
#endif

    uint8_t buffer[PVGBALINK_WIRE_SIZE * kReadBufferMessages];
    size_t have = 0;
    uint64_t lastReceive = _nowMs();
    PVGBALinkCloseReason reason = PVGBALinkCloseNone;
    int fd = session->peerFD;

    while (reason == PVGBALinkCloseNone && !atomic_load(&session->stopping)) {
        struct pollfd fds[3] = {
            { .fd = fd, .events = (short) (POLLIN | (_hasOutbox(session) ? POLLOUT : 0)) },
            { .fd = session->wakeRead, .events = POLLIN },
            { .fd = session->kickRead, .events = POLLIN },
        };
        int ready = poll(fds, 3, kPollSliceMs);
        if (atomic_load(&session->stopping) || (ready > 0 && fds[1].revents)) {
            break;
        }
        if (ready < 0 && errno != EINTR) {
            atomic_store(&session->lastErrno, errno);
            reason = PVGBALinkClosePeerLost;
            break;
        }
        uint64_t now = _nowMs();

        if (ready > 0 && fds[2].revents) {
            char drain[64];
            while (read(session->kickRead, drain, sizeof(drain)) > 0) {
            }
        }
        if (ready > 0 && (fds[0].revents & POLLOUT || fds[2].revents)) {
            pthread_mutex_lock(&session->sendLock);
            bool flushed = _flushOutboxLocked(session, fd);
            pthread_mutex_unlock(&session->sendLock);
            if (!flushed) {
                reason = PVGBALinkClosePeerLost;
                break;
            }
        }

        if (ready > 0 && fds[0].revents & (POLLIN | POLLHUP | POLLERR)) {
            ssize_t n = recv(fd, buffer + have, sizeof(buffer) - have, 0);
            if (n == 0) {
                reason = PVGBALinkClosePeerLost;
                break;
            }
            if (n < 0) {
                if (errno != EINTR && errno != EAGAIN) {
                    atomic_store(&session->lastErrno, errno);
                    reason = PVGBALinkClosePeerLost;
                }
                continue;
            }
            have += (size_t) n;
            lastReceive = now;

            size_t offset = 0;
            pthread_mutex_lock(&session->lock);
            while (have - offset >= PVGBALINK_WIRE_SIZE) {
                PVGBALinkMessage message;
                PVGBALinkDecode(buffer + offset, &message);
                offset += PVGBALINK_WIRE_SIZE;
                if (message.type == kMessageHeartbeat) {
                    continue;
                }
                if (message.type == kMessageBye) {
                    reason = PVGBALinkClosePeerLeft;
                    break;
                }
                if (message.type < PVGBALinkMessageAdvance || message.type > PVGBALinkMessageTransferData ||
                    !_pushInbox(session, &message)) {
                    reason = PVGBALinkCloseProtocolError;
                    break;
                }
            }
            pthread_cond_broadcast(&session->cond);
            pthread_mutex_unlock(&session->lock);
            memmove(buffer, buffer + offset, have - offset);
            have -= offset;
            if (reason != PVGBALinkCloseNone) {
                break;
            }
        }

        if (now - lastReceive > (uint64_t) kPeerTimeoutMs) {
            reason = PVGBALinkCloseTimeout;
            break;
        }
        if (now - atomic_load(&session->lastSendMs) >= (uint64_t) kHeartbeatIntervalMs && !_hasOutbox(session)) {
            PVGBALinkMessage heartbeat = { .type = kMessageHeartbeat, .mode = -1 };
            if (!_enqueueSend(session, fd, &heartbeat)) {
                reason = PVGBALinkClosePeerLost;
                break;
            }
        }
    }

    if (reason == PVGBALinkCloseNone || atomic_load(&session->stopping)) {
        return NULL;
    }
    bool notify = false;
    pthread_mutex_lock(&session->lock);
    if (!session->closed) {
        session->closed = true;
        session->closeReason = reason;
        notify = true;
    }
    pthread_cond_broadcast(&session->cond);
    pthread_mutex_unlock(&session->lock);
    shutdown(fd, SHUT_RDWR);
    if (notify && session->callback) {
        session->callback(session->callbackContext, reason);
    }
    return NULL;
}

PVGBALinkResult PVGBALinkSessionStart(PVGBALinkSession *session, PVGBALinkClosedCallback callback,
                                      void *context) {
    pthread_mutex_lock(&session->lock);
    if (!session->handshakeDone || session->threadStarted || session->closed) {
        pthread_mutex_unlock(&session->lock);
        return PVGBALinkErrorState;
    }
    if (atomic_load(&session->stopping)) {
        pthread_mutex_unlock(&session->lock);
        return PVGBALinkErrorCancelled;
    }
    session->callback = callback;
    session->callbackContext = context;
    if (pthread_create(&session->thread, NULL, _ioThread, session) != 0) {
        atomic_store(&session->lastErrno, errno);
        pthread_mutex_unlock(&session->lock);
        return PVGBALinkErrorSocket;
    }
    session->threadStarted = true;
    pthread_mutex_unlock(&session->lock);
    return PVGBALinkOK;
}

// MARK: - Messaging

PVGBALinkResult PVGBALinkSessionSend(PVGBALinkSession *session, const PVGBALinkMessage *message) {
    pthread_mutex_lock(&session->lock);
    int fd = session->peerFD;
    bool usable = session->handshakeDone && session->threadStarted && !session->closed && fd >= 0;
    pthread_mutex_unlock(&session->lock);
    if (!usable || atomic_load(&session->stopping)) {
        return PVGBALinkErrorClosed;
    }
    if (!_enqueueSend(session, fd, message)) {
        // The I/O thread sees the shutdown and closes the session.
        shutdown(fd, SHUT_RDWR);
        return PVGBALinkErrorClosed;
    }
    return PVGBALinkOK;
}

int PVGBALinkSessionReceive(PVGBALinkSession *session, PVGBALinkMessage *outMessage, int timeoutMs) {
    pthread_mutex_lock(&session->lock);
    if (session->inboxCount == 0 && !session->closed && timeoutMs > 0) {
        uint64_t deadline = _nowMs() + (uint64_t) timeoutMs;
        while (session->inboxCount == 0 && !session->closed) {
            uint64_t now = _nowMs();
            if (now >= deadline) {
                break;
            }
            uint64_t remaining = deadline - now;
            struct timespec wait = {
                .tv_sec = (time_t) (remaining / 1000u),
                .tv_nsec = (long) (remaining % 1000u) * 1000000L,
            };
#ifdef __APPLE__
            pthread_cond_timedwait_relative_np(&session->cond, &session->lock, &wait);
#else
            struct timespec absolute;
            clock_gettime(CLOCK_REALTIME, &absolute);
            absolute.tv_sec += wait.tv_sec;
            absolute.tv_nsec += wait.tv_nsec;
            if (absolute.tv_nsec >= 1000000000L) {
                absolute.tv_sec += 1;
                absolute.tv_nsec -= 1000000000L;
            }
            pthread_cond_timedwait(&session->cond, &session->lock, &absolute);
#endif
        }
    }
    int result;
    if (session->inboxCount > 0) {
        *outMessage = session->inbox[session->inboxHead];
        session->inboxHead = (session->inboxHead + 1) % session->inboxCapacity;
        session->inboxCount -= 1;
        result = 1;
    } else {
        result = session->closed ? -1 : 0;
    }
    pthread_mutex_unlock(&session->lock);
    return result;
}

void PVGBALinkSessionStop(PVGBALinkSession *session) {
    if (!session) {
        return;
    }
    // Serialises concurrent Stops: a second caller returns only once the
    // first has joined the I/O thread and closed the session.
    pthread_mutex_lock(&session->stopLock);
    if (session->stopped) {
        pthread_mutex_unlock(&session->stopLock);
        return;
    }
    atomic_store(&session->stopping, true);
    // Wakes every poll() on this session, now and later.
    ssize_t written = write(session->wakeWrite, "x", 1);
    (void) written;

    pthread_mutex_lock(&session->lock);
    int peerFD = session->peerFD;
    int listenFD = session->listenFD;
    bool sayGoodbye = session->handshakeDone && !session->closed && peerFD >= 0;
    bool joinThread = session->threadStarted;
    pthread_mutex_unlock(&session->lock);

    if (joinThread && !pthread_equal(pthread_self(), session->thread)) {
        pthread_join(session->thread, NULL);
    }
    if (sayGoodbye) {
        // The I/O thread is gone: send what is still queued, then goodbye.
        // Blocking, bounded by the socket's send timeout.
        PVGBALinkMessage bye = { .type = kMessageBye, .mode = -1 };
        uint8_t buffer[PVGBALINK_WIRE_SIZE];
        PVGBALinkEncode(&bye, buffer);
        pthread_mutex_lock(&session->sendLock);
        if (_writeAll(session, peerFD, session->outbox, session->outboxLength)) {
            _writeAll(session, peerFD, buffer, sizeof(buffer));
        }
        session->outboxLength = 0;
        pthread_mutex_unlock(&session->sendLock);
    }
    if (peerFD >= 0) {
        shutdown(peerFD, SHUT_RDWR);
    }
    if (listenFD >= 0) {
        shutdown(listenFD, SHUT_RDWR);
    }

    pthread_mutex_lock(&session->lock);
    if (!session->closed) {
        session->closed = true;
        session->closeReason = PVGBALinkCloseLocal;
    }
    pthread_cond_broadcast(&session->cond);
    pthread_mutex_unlock(&session->lock);

    session->stopped = true;
    pthread_mutex_unlock(&session->stopLock);
}

// MARK: - State

int PVGBALinkSessionPlayerId(const PVGBALinkSession *session) {
    return session->playerId;
}

int PVGBALinkSessionPlayerCount(const PVGBALinkSession *session) {
    return session->playerCount;
}

bool PVGBALinkSessionIsClosed(PVGBALinkSession *session) {
    pthread_mutex_lock(&session->lock);
    bool closed = session->closed;
    pthread_mutex_unlock(&session->lock);
    return closed;
}

PVGBALinkCloseReason PVGBALinkSessionCloseReason(PVGBALinkSession *session) {
    pthread_mutex_lock(&session->lock);
    PVGBALinkCloseReason reason = session->closeReason;
    pthread_mutex_unlock(&session->lock);
    return reason;
}

int PVGBALinkSessionLastErrno(const PVGBALinkSession *session) {
    return atomic_load(&session->lastErrno);
}
