//
//  PVmGBANetLinkDriver.c
//  PVCoremGBA
//
//  Network link cable for mGBA. Modelled on upstream's in-process lockstep
//  (src/gba/sio/lockstep.c), with the other GBA on another device.
//
//  Why not upstream's lockstep.c itself: it assumes every player shares one
//  process. Players write straight into each other's event queues and wake
//  each other through mLockstepUser while holding the coordinator mutex, and
//  under DISABLE_THREADING (this build) that mutex is a no-op.
//
//  How the two GBAs stay in step
//  ─────────────────────────────
//  Both sides count a 64-bit "link clock" in GBA cycles. The host (player 0)
//  owns it:
//    - The host runs freely and sends ADVANCE(time) every 16384 cycles and
//      at the end of each frame. Every host message carries a time and moves
//      the client's horizon to it.
//    - The client may never run past the host's horizon. It handles the
//      host's events at exactly their timestamps, so a transfer starts on
//      both GBAs at the same emulated cycle.
//    - The client reports its clock (SYNC). If the client falls more than
//      three frames behind, the host waits for it.
//
//  A multiplayer transfer (the mode trading and battles use)
//  ─────────────────────────────────────────────────────────
//    1. The host's game starts a transfer at T. The host sends
//       TRANSFER_START(T, finish F, its word) and waits.
//    2. The client reaches T, latches its own word, marks itself busy,
//       schedules completion at F and sends TRANSFER_ACK(its word).
//    3. With every client's word in, the host sends TRANSFER_DATA (all
//       words) and carries on. TCP ordering delivers it to the client
//       before any horizon past T, so the client always has it by F.
//    4. Both GBAs finish at F with the same four words.
//  Each multiplayer transfer therefore costs the host about one round trip,
//  plus however far the client is behind. Normal-mode transfers never make
//  the host wait: the host's received word is always 0xFF (as upstream).
//
//  Waiting never blocks inside mGBA. "Sleeping" stops the CPU at the next
//  instruction boundary (as upstream does through mCoreThread), and
//  PVmGBANetLinkDriverRunFrame, which replaces core->runFrame, waits for
//  messages between runLoop calls.
//
//  The protocol carries player numbers and four data words. Only two players
//  are implemented: the session accepts one client. Three or four would need
//  the host to relay clients' modes and to wait for every client.
//

#include "PVmGBANetLinkDriver.h"

#include <mgba-util/common.h>

#include <mgba/core/core.h>
#include <mgba/core/timing.h>
#include <mgba/internal/arm/arm.h>
#include <mgba/internal/gba/gba.h>
#include <mgba/internal/gba/io.h>
#include <mgba/internal/gba/sio.h>
#include <mgba/internal/gba/video.h>

#include <stdlib.h>
#include <string.h>
#include <time.h>

/// Cycles between driver services: upstream's LOCKSTEP_INTERVAL.
#define LINK_SERVICE_INTERVAL 4096
/// Host: cycles between clock advances sent to the client (~2 ms emulated).
/// The end of every frame sends one too.
#define LINK_ADVANCE_INTERVAL 32768
/// Client: cycles between clock reports to the host.
#define LINK_SYNC_INTERVAL 65536
/// Host: how far ahead of the slowest client it may run before waiting.
#define LINK_MAX_LEAD ((int64_t) VIDEO_TOTAL_LENGTH * 3)
/// Client: initial room for host events received but not yet due. Grows;
/// the host's lead limit is what normally bounds it.
#define LINK_INITIAL_PENDING 16
/// Client: more host events than this waiting means something is wrong.
#define LINK_MAX_PENDING 4096
/// "PVLk"
#define LINK_DRIVER_ID 0x6B4C5650u

enum LinkSleep {
    LINK_AWAKE = 0,
    /// Client: reached the host's clock (or hasn't heard from the host yet).
    LINK_WAIT_HOST,
    /// Host: waiting for the clients' words for a multiplayer transfer.
    LINK_WAIT_TRANSFER,
    /// Host: too far ahead of a client.
    LINK_WAIT_CLIENTS,
};

struct PVmGBANetLinkDriver {
    struct GBASIODriver d; // first: GBASIODriver* casts to the driver
    struct mTimingEvent event;
    PVGBALinkSession *session;

    int playerId;
    int playerCount;
    bool linked;
    PVmGBANetLinkFailure failure;
    enum LinkSleep sleep;

    // Link clock: mTiming's 32-bit counter widened to 64 bits.
    int32_t lastRawTime;
    int64_t clock;

    // Host
    int64_t lastAdvance;
    int64_t peerTime[MAX_GBAS];
    bool peerReported[MAX_GBAS];
    uint32_t waitingAcks;
    int64_t transferTime;

    // Client
    bool clockAdopted;
    bool hasHorizon;
    int64_t horizon;
    int64_t lastSync;
    PVGBALinkMessage *pending;
    size_t pendingCapacity;
    size_t pendingHead;
    size_t pendingCount;

    // Both
    enum GBASIOMode mode;
    enum GBASIOMode otherModes[MAX_GBAS];
    enum GBASIOMode transferMode;
    bool transferActive;
    bool dataReceived;
    uint16_t multiData[MAX_GBAS];
    uint32_t normalData[MAX_GBAS];
};

// MARK: - Clock

static int64_t _now(PVmGBANetLinkDriver *link) {
    int32_t raw = mTimingCurrentTime(&link->d.p->p->timing);
    int32_t delta = (int32_t) ((uint32_t) raw - (uint32_t) link->lastRawTime);
    // A reset rewinds mTiming; the link clock never runs backwards.
    if (delta > 0) {
        link->clock += delta;
    }
    link->lastRawTime = raw;
    return link->clock;
}

static uint64_t _monotonicMs(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t) ts.tv_sec * 1000u + (uint64_t) ts.tv_nsec / 1000000u;
}

// MARK: - Link state

static void _updateReady(PVmGBANetLinkDriver *link) {
    if (link->mode != GBA_SIO_MULTI) {
        return;
    }
    // Unlinked, act like no driver at all: mGBA's dummy reports ready.
    bool ready = true;
    if (link->linked) {
        for (int i = 0; i < link->playerCount; ++i) {
            ready = ready && link->otherModes[i] == link->mode;
        }
    }
    struct GBASIO *sio = link->d.p;
    sio->siocnt = GBASIOMultiplayerSetReady(sio->siocnt, ready);
    sio->rcnt = GBASIORegisterRCNTSetSd(sio->rcnt, ready);
}

static void _abortTransfer(PVmGBANetLinkDriver *link) {
    link->transferActive = false;
    link->waitingAcks = 0;
    link->dataReceived = false;
    if (link->sleep == LINK_WAIT_TRANSFER) {
        link->sleep = LINK_AWAKE;
    }
}

/// From now on behave like an unplugged cable. A transfer in flight
/// finishes with 0xFFFF, so the game still gets its IRQ.
static void _linkLost(PVmGBANetLinkDriver *link, PVmGBANetLinkFailure failure) {
    if (!link->linked) {
        return;
    }
    link->linked = false;
    link->failure = failure;
    link->sleep = LINK_AWAKE;
    link->pendingCount = 0;
    _abortTransfer(link);
    _updateReady(link);
}

/// Stops the CPU after the current instruction, as upstream's lockstep does,
/// so runLoop returns and the frame loop can wait.
static void _sleep(PVmGBANetLinkDriver *link, enum LinkSleep reason, bool interruptCPU) {
    link->sleep = reason;
    if (interruptCPU) {
        struct GBA *gba = link->d.p->p;
        gba->cpu->nextEvent = 0;
        GBAInterrupt(gba);
    }
}

static void _send(PVmGBANetLinkDriver *link, PVGBALinkMessageType type, int64_t time, int64_t finish,
                  enum GBASIOMode mode, const uint32_t *data) {
    if (!link->linked) {
        return;
    }
    PVGBALinkMessage message = {
        .type = (uint8_t) type,
        .player = (uint8_t) link->playerId,
        .mode = (int8_t) mode,
        .time = (uint64_t) time,
        .finish = (uint64_t) finish,
    };
    if (data) {
        memcpy(message.data, data, sizeof(message.data));
    }
    if (PVGBALinkSessionSend(link->session, &message) != PVGBALinkOK) {
        _linkLost(link, PVmGBANetLinkFailureConnection);
    }
}

static void _sendAdvance(PVmGBANetLinkDriver *link, int64_t now) {
    _send(link, PVGBALinkMessageAdvance, now, 0, -1, NULL);
    link->lastAdvance = now;
}

static void _sendSync(PVmGBANetLinkDriver *link, int64_t now) {
    _send(link, PVGBALinkMessageSync, now, 0, -1, NULL);
    link->lastSync = now;
}

static bool _tooFarAhead(const PVmGBANetLinkDriver *link, int64_t now) {
    for (int i = 1; i < link->playerCount; ++i) {
        // Don't throttle against a client that hasn't started its emulator.
        if (link->peerReported[i] && now - link->peerTime[i] > LINK_MAX_LEAD) {
            return true;
        }
    }
    return false;
}

static uint32_t _ownWord(PVmGBANetLinkDriver *link, enum GBASIOMode mode) {
    const uint16_t *io = link->d.p->p->memory.io;
    switch (mode) {
    case GBA_SIO_MULTI:
        return io[GBA_REG(SIOMLT_SEND)];
    case GBA_SIO_NORMAL_8:
        return io[GBA_REG(SIODATA8)] & 0xFF;
    case GBA_SIO_NORMAL_32:
        return io[GBA_REG(SIODATA32_LO)] | ((uint32_t) io[GBA_REG(SIODATA32_HI)] << 16);
    default:
        return 0xFFFFFFFF;
    }
}

static void _storeWord(PVmGBANetLinkDriver *link, int player, uint32_t word) {
    if (link->transferMode == GBA_SIO_MULTI) {
        link->multiData[player] = (uint16_t) word;
    } else {
        link->normalData[player] = word;
    }
}

static void _resetTransferData(PVmGBANetLinkDriver *link, enum GBASIOMode mode) {
    link->transferMode = mode;
    link->dataReceived = false;
    memset(link->multiData, 0xFF, sizeof(link->multiData));
    memset(link->normalData, 0xFF, sizeof(link->normalData));
}

// MARK: - Host

/// Every client's word is in: share them all and carry on.
static void _hostTransferComplete(PVmGBANetLinkDriver *link) {
    uint32_t words[MAX_GBAS];
    for (int i = 0; i < MAX_GBAS; ++i) {
        words[i] = link->transferMode == GBA_SIO_MULTI ? link->multiData[i] : link->normalData[i];
    }
    link->transferActive = false;
    link->dataReceived = true;
    _send(link, PVGBALinkMessageTransferData, link->transferTime, 0, link->transferMode, words);
    if (link->sleep == LINK_WAIT_TRANSFER) {
        link->sleep = LINK_AWAKE;
    }
}

static void _hostApply(PVmGBANetLinkDriver *link, const PVGBALinkMessage *message) {
    int player = message->player;
    if (player <= 0 || player >= link->playerCount) {
        return;
    }
    int64_t time = (int64_t) message->time;
    // Only syncs and acks carry the client's adopted clock; a mode message
    // can predate the adoption.
    if (message->type == PVGBALinkMessageSync || message->type == PVGBALinkMessageTransferAck) {
        if (!link->peerReported[player] || time > link->peerTime[player]) {
            link->peerTime[player] = time;
        }
        link->peerReported[player] = true;
    }

    switch (message->type) {
    case PVGBALinkMessageMode:
        link->otherModes[player] = (enum GBASIOMode) message->mode;
        if (link->transferActive && link->otherModes[player] != link->transferMode) {
            _abortTransfer(link);
        }
        _updateReady(link);
        break;
    case PVGBALinkMessageTransferAck:
        if (link->transferActive && (link->waitingAcks & (1u << player)) && time == link->transferTime) {
            _storeWord(link, player, message->data[0]);
            link->waitingAcks &= ~(1u << player);
            if (!link->waitingAcks) {
                _hostTransferComplete(link);
            }
        }
        break;
    default:
        break;
    }
}

// MARK: - Client

/// Queues a host event for its timestamp. false if the queue is full or out
/// of memory.
static bool _pushPending(PVmGBANetLinkDriver *link, const PVGBALinkMessage *message) {
    if (link->pendingCount >= LINK_MAX_PENDING) {
        return false;
    }
    if (link->pendingCount == link->pendingCapacity) {
        size_t capacity = link->pendingCapacity ? link->pendingCapacity * 2 : LINK_INITIAL_PENDING;
        PVGBALinkMessage *pending = malloc(capacity * sizeof(*pending));
        if (!pending) {
            return false;
        }
        for (size_t i = 0; i < link->pendingCount; ++i) {
            pending[i] = link->pending[(link->pendingHead + i) % link->pendingCapacity];
        }
        free(link->pending);
        link->pending = pending;
        link->pendingCapacity = capacity;
        link->pendingHead = 0;
    }
    link->pending[(link->pendingHead + link->pendingCount) % link->pendingCapacity] = *message;
    link->pendingCount += 1;
    return true;
}

static void _clientApply(PVmGBANetLinkDriver *link, const PVGBALinkMessage *message) {
    if (message->player != 0) {
        return;
    }
    int64_t time = (int64_t) message->time;
    if (!link->hasHorizon || time > link->horizon) {
        link->horizon = time;
        link->hasHorizon = true;
    }
    switch (message->type) {
    case PVGBALinkMessageMode:
    case PVGBALinkMessageTransferStart:
        if (!_pushPending(link, message)) {
            _linkLost(link, PVmGBANetLinkFailureOverflow);
        }
        break;
    case PVGBALinkMessageTransferData:
        for (int i = 0; i < MAX_GBAS; ++i) {
            _storeWord(link, i, message->data[i]);
        }
        link->dataReceived = true;
        break;
    default:
        break;
    }
}

/// A host transfer reached this GBA: latch our word, go busy, finish at the
/// host's finish cycle.
static void _clientStartTransfer(PVmGBANetLinkDriver *link, const PVGBALinkMessage *message, int64_t now) {
    struct GBASIO *sio = link->d.p;
    _resetTransferData(link, (enum GBASIOMode) message->mode);
    uint32_t own = _ownWord(link, link->transferMode);
    _storeWord(link, 0, message->data[0]);
    _storeWord(link, link->playerId, own);
    // Normal mode only needs the host's word, which just arrived.
    link->dataReceived = link->transferMode != GBA_SIO_MULTI;

    sio->siocnt |= 0x80;
    int64_t untilFinish = (int64_t) message->finish - now;
    mTimingDeschedule(&sio->p->timing, &sio->completeEvent);
    mTimingSchedule(&sio->p->timing, &sio->completeEvent, untilFinish > 0 ? (int32_t) untilFinish : 0);

    uint32_t words[MAX_GBAS] = { own };
    _send(link, PVGBALinkMessageTransferAck, (int64_t) message->time, 0, link->transferMode, words);
}

static void _clientRunDueEvents(PVmGBANetLinkDriver *link, int64_t now) {
    while (link->linked && link->pendingCount > 0) {
        PVGBALinkMessage message = link->pending[link->pendingHead];
        if ((int64_t) message.time > now) {
            break;
        }
        link->pendingHead = (link->pendingHead + 1) % link->pendingCapacity;
        link->pendingCount -= 1;
        if (message.type == PVGBALinkMessageMode) {
            link->otherModes[0] = (enum GBASIOMode) message.mode;
            _updateReady(link);
        } else {
            _clientStartTransfer(link, &message, now);
        }
    }
}

// MARK: - Service

/// Applies queued messages, waiting up to `timeoutMs` for the first one.
static void _pump(PVmGBANetLinkDriver *link, int timeoutMs) {
    PVGBALinkMessage message;
    while (link->linked) {
        int result = PVGBALinkSessionReceive(link->session, &message, timeoutMs);
        timeoutMs = 0;
        if (result < 0) {
            _linkLost(link, PVmGBANetLinkFailureConnection);
        }
        if (result != 1) {
            break;
        }
        if (link->playerId == 0) {
            _hostApply(link, &message);
        } else {
            _clientApply(link, &message);
        }
    }
}

/// Exchanges clock information and decides whether to sleep. Returns the
/// cycles until the next service.
static int32_t _service(PVmGBANetLinkDriver *link, bool interruptCPU) {
    _pump(link, 0);
    if (!link->linked) {
        return LINK_SERVICE_INTERVAL;
    }
    int64_t now = _now(link);

    if (link->playerId == 0) {
        if (link->sleep == LINK_WAIT_CLIENTS && !_tooFarAhead(link, now)) {
            link->sleep = LINK_AWAKE;
        }
        if (now - link->lastAdvance >= LINK_ADVANCE_INTERVAL) {
            _sendAdvance(link, now);
        }
        if (link->sleep == LINK_AWAKE && _tooFarAhead(link, now)) {
            if (link->lastAdvance != now) {
                _sendAdvance(link, now);
            }
            _sleep(link, LINK_WAIT_CLIENTS, interruptCPU);
        }
        return LINK_SERVICE_INTERVAL;
    }

    if (!link->clockAdopted) {
        if (!link->hasHorizon) {
            _sleep(link, LINK_WAIT_HOST, interruptCPU);
            return LINK_SERVICE_INTERVAL;
        }
        // First word from the host: take its clock, so this GBA doesn't
        // trail by however long the host ran before we connected.
        link->clock = link->horizon;
        link->clockAdopted = true;
        now = link->clock;
        _sendSync(link, now);
    }

    _clientRunDueEvents(link, now);
    if (!link->linked) {
        return LINK_SERVICE_INTERVAL;
    }
    if (now - link->lastSync >= LINK_SYNC_INTERVAL) {
        _sendSync(link, now);
    }
    int64_t limit = link->horizon;
    if (link->pendingCount > 0 && (int64_t) link->pending[link->pendingHead].time < limit) {
        limit = (int64_t) link->pending[link->pendingHead].time;
    }
    if (limit <= now) {
        _sleep(link, LINK_WAIT_HOST, interruptCPU);
        return LINK_SERVICE_INTERVAL;
    }
    int64_t until = limit - now;
    return until < LINK_SERVICE_INTERVAL ? (int32_t) until : LINK_SERVICE_INTERVAL;
}

static void _serviceEvent(struct mTiming *timing, void *context, uint32_t cyclesLate) {
    UNUSED(cyclesLate);
    PVmGBANetLinkDriver *link = context;
    int32_t next = _service(link, true);
    mTimingSchedule(timing, &link->event, next > 0 ? next : 1);
}

/// Frame loop, CPU stopped: wait for messages and wake if they allow it.
static void _wait(PVmGBANetLinkDriver *link, int timeoutMs) {
    _pump(link, timeoutMs);
    if (!link->linked) {
        link->sleep = LINK_AWAKE;
        return;
    }
    switch (link->sleep) {
    case LINK_WAIT_CLIENTS:
        if (!_tooFarAhead(link, _now(link))) {
            link->sleep = LINK_AWAKE;
        }
        break;
    case LINK_WAIT_HOST: {
        link->sleep = LINK_AWAKE;
        int32_t next = _service(link, false);
        if (link->sleep == LINK_AWAKE) {
            // Next service exactly at the new limit, so we never overshoot it.
            struct mTiming *timing = &link->d.p->p->timing;
            mTimingDeschedule(timing, &link->event);
            mTimingSchedule(timing, &link->event, next);
        }
        break;
    }
    case LINK_WAIT_TRANSFER:
    case LINK_AWAKE:
        break;
    }
}

// MARK: - GBASIODriver

static void _driverReset(struct GBASIODriver *driver) {
    PVmGBANetLinkDriver *link = (PVmGBANetLinkDriver *) driver;
    struct GBASIO *sio = driver->p;
    // A reset clears mTiming: rebase the clock and reschedule the service.
    link->lastRawTime = mTimingCurrentTime(&sio->p->timing);
    if (link->transferActive) {
        _abortTransfer(link);
    }
    if (link->sleep != LINK_WAIT_HOST) {
        link->sleep = LINK_AWAKE;
    }
    link->mode = sio->mode;
    link->otherModes[link->playerId] = sio->mode;
    _send(link, PVGBALinkMessageMode, _now(link), 0, sio->mode, NULL);
    _updateReady(link);
    if (!mTimingIsScheduled(&sio->p->timing, &link->event)) {
        mTimingSchedule(&sio->p->timing, &link->event, 0);
    }
}

static bool _driverInit(struct GBASIODriver *driver) {
    _driverReset(driver);
    return true;
}

/// The cable comes out: a transfer still in flight ends now, as if nobody
/// were on the line, rather than later with no driver to supply the data.
static void _finishTransferUnplugged(struct GBASIO *sio) {
    struct mTiming *timing = &sio->p->timing;
    if (!mTimingIsScheduled(timing, &sio->completeEvent)) {
        return;
    }
    mTimingDeschedule(timing, &sio->completeEvent);
    switch (sio->mode) {
    case GBA_SIO_MULTI: {
        uint16_t idle[MAX_GBAS] = { 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF };
        GBASIOMultiplayerFinishTransfer(sio, idle, 0);
        break;
    }
    case GBA_SIO_NORMAL_8:
        GBASIONormal8FinishTransfer(sio, 0xFF, 0);
        break;
    case GBA_SIO_NORMAL_32:
        GBASIONormal32FinishTransfer(sio, 0xFFFFFFFF, 0);
        break;
    default:
        break;
    }
}

static void _driverDeinit(struct GBASIODriver *driver) {
    PVmGBANetLinkDriver *link = (PVmGBANetLinkDriver *) driver;
    mTimingDeschedule(&driver->p->p->timing, &link->event);
    link->sleep = LINK_AWAKE;
    _finishTransferUnplugged(driver->p);
}

static uint32_t _driverId(const struct GBASIODriver *driver) {
    UNUSED(driver);
    return LINK_DRIVER_ID;
}

static void _driverSetMode(struct GBASIODriver *driver, enum GBASIOMode mode) {
    PVmGBANetLinkDriver *link = (PVmGBANetLinkDriver *) driver;
    if (mode == link->mode) {
        return;
    }
    link->mode = mode;
    link->otherModes[link->playerId] = mode;
    if (link->transferActive && mode != link->transferMode) {
        _abortTransfer(link);
    }
    _send(link, PVGBALinkMessageMode, _now(link), 0, mode, NULL);
    _updateReady(link);
}

static bool _driverHandlesMode(struct GBASIODriver *driver, enum GBASIOMode mode) {
    UNUSED(driver);
    UNUSED(mode);
    return true;
}

static int _driverConnectedDevices(struct GBASIODriver *driver) {
    PVmGBANetLinkDriver *link = (PVmGBANetLinkDriver *) driver;
    return link->linked ? link->playerCount - 1 : 0;
}

static int _driverDeviceId(struct GBASIODriver *driver) {
    PVmGBANetLinkDriver *link = (PVmGBANetLinkDriver *) driver;
    return link->linked ? link->playerId : 0;
}

static uint16_t _driverWriteRegister(struct GBASIODriver *driver, uint16_t value) {
    UNUSED(driver);
    return value;
}

static bool _driverStart(struct GBASIODriver *driver) {
    PVmGBANetLinkDriver *link = (PVmGBANetLinkDriver *) driver;
    if (!link->linked) {
        // Unplugged: let mGBA finish the transfer with nobody on the line.
        return true;
    }
    if (link->playerId != 0) {
        // As upstream: only the host drives the clock. The transfer stays
        // busy until the host starts one.
        return false;
    }
    struct GBASIO *sio = driver->p;
    int64_t now = _now(link);
    int32_t duration = GBASIOTransferCycles(sio->mode, sio->siocnt, link->playerCount - 1);
    _resetTransferData(link, sio->mode);
    uint32_t own = _ownWord(link, sio->mode);
    _storeWord(link, 0, own);
    link->transferTime = now;

    uint32_t words[MAX_GBAS] = { own };
    _send(link, PVGBALinkMessageTransferStart, now, now + duration, sio->mode, words);
    link->lastAdvance = now;
    if (link->linked && sio->mode == GBA_SIO_MULTI) {
        link->transferActive = true;
        link->waitingAcks = ((1u << link->playerCount) - 1) & ~1u;
        _sleep(link, LINK_WAIT_TRANSFER, true);
    }
    return true;
}

static void _driverFinishMultiplayer(struct GBASIODriver *driver, uint16_t data[4]) {
    PVmGBANetLinkDriver *link = (PVmGBANetLinkDriver *) driver;
    if (link->dataReceived && link->transferMode == GBA_SIO_MULTI) {
        memcpy(data, link->multiData, sizeof(link->multiData));
    } else {
        memset(data, 0xFF, sizeof(uint16_t) * MAX_GBAS);
    }
    link->dataReceived = false;
}

/// Normal mode chains the consoles: each one receives the previous player's
/// word, and the host receives 0xFF, as upstream.
static uint32_t _normalWord(PVmGBANetLinkDriver *link, enum GBASIOMode mode, uint32_t idle) {
    uint32_t word = idle;
    if (link->dataReceived && link->transferMode == mode && link->playerId > 0) {
        word = link->normalData[link->playerId - 1];
    }
    link->dataReceived = false;
    return word;
}

static uint8_t _driverFinishNormal8(struct GBASIODriver *driver) {
    return (uint8_t) _normalWord((PVmGBANetLinkDriver *) driver, GBA_SIO_NORMAL_8, 0xFF);
}

static uint32_t _driverFinishNormal32(struct GBASIODriver *driver) {
    return _normalWord((PVmGBANetLinkDriver *) driver, GBA_SIO_NORMAL_32, 0xFFFFFFFF);
}

// MARK: - Public

PVmGBANetLinkDriver *PVmGBANetLinkDriverCreate(PVGBALinkSession *session) {
    int playerId = PVGBALinkSessionPlayerId(session);
    int playerCount = PVGBALinkSessionPlayerCount(session);
    if (playerId < 0 || playerId >= MAX_GBAS || playerCount < 2 || playerCount > MAX_GBAS) {
        return NULL;
    }
    PVmGBANetLinkDriver *link = calloc(1, sizeof(*link));
    if (!link) {
        return NULL;
    }
    link->d.init = _driverInit;
    link->d.deinit = _driverDeinit;
    link->d.reset = _driverReset;
    link->d.driverId = _driverId;
    link->d.setMode = _driverSetMode;
    link->d.handlesMode = _driverHandlesMode;
    link->d.connectedDevices = _driverConnectedDevices;
    link->d.deviceId = _driverDeviceId;
    link->d.writeSIOCNT = _driverWriteRegister;
    link->d.writeRCNT = _driverWriteRegister;
    link->d.start = _driverStart;
    link->d.finishMultiplayer = _driverFinishMultiplayer;
    link->d.finishNormal8 = _driverFinishNormal8;
    link->d.finishNormal32 = _driverFinishNormal32;
    // No saveState/loadState: save-state loads are blocked while linked.

    link->event.context = link;
    link->event.callback = _serviceEvent;
    link->event.name = "Provenance network link";
    link->event.priority = 0x80;

    link->session = session;
    link->playerId = playerId;
    link->playerCount = playerCount;
    link->linked = !PVGBALinkSessionIsClosed(session);
    link->mode = (enum GBASIOMode) -1;
    for (int i = 0; i < MAX_GBAS; ++i) {
        link->otherModes[i] = (enum GBASIOMode) -1;
    }
    _resetTransferData(link, (enum GBASIOMode) -1);
    return link;
}

void PVmGBANetLinkDriverFree(PVmGBANetLinkDriver *driver) {
    if (driver) {
        free(driver->pending);
    }
    free(driver);
}

struct GBASIODriver *PVmGBANetLinkDriverBase(PVmGBANetLinkDriver *driver) {
    return &driver->d;
}

bool PVmGBANetLinkDriverIsLinked(const PVmGBANetLinkDriver *driver) {
    return driver->linked;
}

PVmGBANetLinkFailure PVmGBANetLinkDriverFailure(const PVmGBANetLinkDriver *driver) {
    return driver->failure;
}

bool PVmGBANetLinkDriverRunFrame(PVmGBANetLinkDriver *link, struct mCore *core, int waitBudgetMs,
                                 bool *outStalled) {
    struct GBA *gba = core->board;
    uint32_t frame = gba->video.frameCounter;
    int32_t startCycle = mTimingCurrentTime(&gba->timing);
    uint64_t deadline = _monotonicMs() + (uint64_t) (waitBudgetMs > 0 ? waitBudgetMs : 0);
    *outStalled = false;

    // Same bounds as _GBACoreRunFrame, so a game with the LCD off can't spin
    // here forever.
    while (gba->video.frameCounter == frame &&
           mTimingCurrentTime(&gba->timing) - startCycle < VIDEO_TOTAL_LENGTH + VIDEO_HORIZONTAL_LENGTH) {
        if (link->sleep != LINK_AWAKE) {
            uint64_t now = _monotonicMs();
            if (now >= deadline) {
                *outStalled = true;
                break;
            }
            _wait(link, (int) (deadline - now));
            continue;
        }
        core->runLoop(core);
    }

    // Host: hand over the end of the frame now rather than up to
    // LINK_ADVANCE_INTERVAL cycles later. (The client's syncs only feed the
    // host's lead limit, which is far coarser, so they keep their interval.)
    if (link->linked && link->sleep == LINK_AWAKE && link->playerId == 0) {
        int64_t now = _now(link);
        if (link->lastAdvance != now) {
            _sendAdvance(link, now);
        }
    }
    return gba->video.frameCounter != frame;
}
