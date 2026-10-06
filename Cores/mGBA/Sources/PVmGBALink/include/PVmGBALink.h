//
//  PVmGBALink.h
//  PVCoremGBA
//
//  TCP transport for the mGBA network link cable.
//
//  This target knows nothing about mGBA. It moves fixed-size messages between
//  a host and one client:
//
//    - Host: PVGBALinkSessionListen, then PVGBALinkSessionAccept.
//      The listener is IPv6 dual-stack (falls back to IPv4), port 0 picks a
//      free port, and the bound port is reported back.
//    - Client: PVGBALinkSessionConnect (getaddrinfo, so IPv4, IPv6 and names
//      all work; a name lookup is abandoned after 5 seconds, and each
//      address gets an equal share of the connect timeout).
//    - Both sides run a handshake (protocol version + shared-secret check),
//      then PVGBALinkSessionStart spawns an I/O thread. That thread reads
//      messages into an inbox, writes out what senders queued, sends a
//      heartbeat every second, and closes the session when the peer leaves
//      or goes quiet for 5 seconds.
//    - PVGBALinkSessionSend / PVGBALinkSessionReceive are thread-safe, and
//      Send never blocks: what the socket won't take goes to a 64 KB outbox
//      for the I/O thread. A full outbox closes the session.
//    - Consecutive ADVANCE (or SYNC) messages coalesce into the newest one
//      in the inbox. More than 4096 waiting messages close the session.
//    - PVGBALinkSessionStop interrupts a blocked accept, connect, handshake or
//      receive from any thread.
//
//  The password check sends a 64-bit FNV-1a hash of the password. That keeps
//  strangers on the LAN out; it is not encryption and the traffic is
//  plaintext.
//
//  The wire format is protocol version 1: every message is 36 bytes,
//  little-endian (see PVmGBALink.c).
//

#ifndef PVMGBALINK_H
#define PVMGBALINK_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Bumped whenever the wire format or message semantics change.
#define PVGBALINK_PROTOCOL_VERSION 1u

/// The GBA link cable connects at most four consoles.
#define PVGBALINK_MAX_PLAYERS 4

/// Message types the session hands to its user. Handshake, heartbeat and
/// goodbye messages are handled inside the session and never reach the inbox.
typedef enum PVGBALinkMessageType {
    /// Host → clients: the host's link clock reached `time`.
    PVGBALinkMessageAdvance = 16,
    /// Client → host: the client's link clock reached `time`.
    PVGBALinkMessageSync = 17,
    /// Any → any: `player` switched its serial mode to `mode` at `time`.
    PVGBALinkMessageMode = 18,
    /// Host → clients: transfer starting at `time`, ending at `finish`, in
    /// `mode`. `data[0]` is the host's outgoing word.
    PVGBALinkMessageTransferStart = 19,
    /// Client → host: `player` latched `data[0]` for the transfer at `time`.
    PVGBALinkMessageTransferAck = 20,
    /// Host → clients: every player's word for the transfer at `time`.
    PVGBALinkMessageTransferData = 21,
} PVGBALinkMessageType;

typedef struct PVGBALinkMessage {
    uint8_t type;      ///< PVGBALinkMessageType
    uint8_t player;    ///< Sender's player number (0 = host)
    int8_t mode;       ///< Serial mode, -1 when unused
    uint8_t reserved;
    uint64_t time;     ///< Link clock, in GBA cycles
    uint64_t finish;   ///< Transfer end, in GBA cycles
    uint32_t data[PVGBALINK_MAX_PLAYERS];
} PVGBALinkMessage;

typedef enum PVGBALinkResult {
    PVGBALinkOK = 0,
    /// A socket call failed; PVGBALinkSessionLastErrno has the errno.
    PVGBALinkErrorSocket = -1,
    /// PVGBALinkSessionStop was called.
    PVGBALinkErrorCancelled = -2,
    PVGBALinkErrorTimeout = -3,
    PVGBALinkErrorWrongPassword = -4,
    PVGBALinkErrorVersionMismatch = -5,
    /// The peer sent something that is not this protocol.
    PVGBALinkErrorProtocol = -6,
    /// getaddrinfo could not resolve the host.
    PVGBALinkErrorResolve = -7,
    /// The call does not fit the session's state (e.g. Accept before Listen).
    PVGBALinkErrorState = -8,
    /// The session is closed.
    PVGBALinkErrorClosed = -9,
    /// The host already has its players.
    PVGBALinkErrorSessionFull = -10,
} PVGBALinkResult;

typedef enum PVGBALinkCloseReason {
    PVGBALinkCloseNone = 0,
    /// PVGBALinkSessionStop on this side.
    PVGBALinkCloseLocal = 1,
    /// The peer said goodbye.
    PVGBALinkClosePeerLeft = 2,
    /// The connection dropped (EOF or socket error).
    PVGBALinkClosePeerLost = 3,
    /// Nothing heard from the peer, not even a heartbeat, for 5 seconds.
    PVGBALinkCloseTimeout = 4,
    /// The peer sent a malformed message.
    PVGBALinkCloseProtocolError = 5,
} PVGBALinkCloseReason;

typedef struct PVGBALinkSession PVGBALinkSession;

/// Called once, on the session's I/O thread, when the connection ends for
/// any reason other than PVGBALinkSessionStop. Must not call
/// PVGBALinkSessionStop or PVGBALinkSessionDestroy.
typedef void (*PVGBALinkClosedCallback)(void *context, PVGBALinkCloseReason reason);

PVGBALinkSession *PVGBALinkSessionCreate(void);

/// Stops the session if needed and frees it. Must not be called from the
/// closed callback.
void PVGBALinkSessionDestroy(PVGBALinkSession *session);

/// Host: bind and listen on `port` (0 = any free port). `password` may be
/// NULL or empty for an open session. On success `outPort` gets the port that
/// was actually bound.
PVGBALinkResult PVGBALinkSessionListen(PVGBALinkSession *session, uint16_t port,
                                       const char *password, uint16_t *outPort);

/// Host: wait for a client and run the handshake. A client with the wrong
/// password or protocol version is turned away and the wait continues.
/// `timeoutMs` < 0 waits until PVGBALinkSessionStop.
PVGBALinkResult PVGBALinkSessionAccept(PVGBALinkSession *session, int timeoutMs);

/// Client: connect to `host` (numeric IPv4/IPv6 or a name) and run the
/// handshake, giving up after `timeoutMs`.
PVGBALinkResult PVGBALinkSessionConnect(PVGBALinkSession *session, const char *host, uint16_t port,
                                        const char *password, int timeoutMs);

/// After Accept or Connect succeeded: start the I/O thread. `callback` may be
/// NULL.
PVGBALinkResult PVGBALinkSessionStart(PVGBALinkSession *session, PVGBALinkClosedCallback callback,
                                      void *context);

/// Thread-safe and never blocks. Fails with PVGBALinkErrorClosed once the
/// session closed or before PVGBALinkSessionStart.
PVGBALinkResult PVGBALinkSessionSend(PVGBALinkSession *session, const PVGBALinkMessage *message);

/// Thread-safe. Pops the oldest inbox message, waiting up to `timeoutMs`
/// (0 = don't wait). Returns 1 with a message, 0 on timeout, -1 when the
/// session is closed and the inbox is empty.
int PVGBALinkSessionReceive(PVGBALinkSession *session, PVGBALinkMessage *outMessage, int timeoutMs);

/// Thread-safe and idempotent. Wakes every blocked call on the session, joins
/// the I/O thread, then flushes queued messages and says goodbye (blocking,
/// up to the 2-second send timeout, so keep it off the main thread). A
/// concurrent second call returns once the first has finished.
void PVGBALinkSessionStop(PVGBALinkSession *session);

/// 0 for the host, 1+ for clients. -1 before the handshake.
int PVGBALinkSessionPlayerId(const PVGBALinkSession *session);

/// Players on the link, including this one. 0 before the handshake.
int PVGBALinkSessionPlayerCount(const PVGBALinkSession *session);

bool PVGBALinkSessionIsClosed(PVGBALinkSession *session);
PVGBALinkCloseReason PVGBALinkSessionCloseReason(PVGBALinkSession *session);

/// errno of the last failed socket call.
int PVGBALinkSessionLastErrno(const PVGBALinkSession *session);

/// Wire encoding, exposed for tests. `buffer` must hold
/// PVGBALINK_WIRE_SIZE bytes.
#define PVGBALINK_WIRE_SIZE 36
void PVGBALinkEncode(const PVGBALinkMessage *message, uint8_t *buffer);
void PVGBALinkDecode(const uint8_t *buffer, PVGBALinkMessage *message);

#ifdef __cplusplus
}
#endif

#endif /* PVMGBALINK_H */
