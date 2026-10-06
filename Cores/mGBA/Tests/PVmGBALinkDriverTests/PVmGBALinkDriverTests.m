//
//  PVmGBALinkDriverTests.m
//  PVCoremGBA
//
//  Two mGBA cores in one process, each on its own thread, linked through
//  PVmGBANetLinkDriver over a loopback PVmGBALink session. Both run a tiny
//  test ROM that does multiplayer-mode transfers and logs what it received.
//

#import <XCTest/XCTest.h>

#include <mgba/core/config.h>
#include <mgba/core/core.h>
#include <mgba/core/log.h>
#include <mgba/gba/core.h>
#include <mgba/internal/gba/gba.h>
#include <mgba/internal/gba/sio.h>
#include <mgba-util/image.h>
#include <mgba-util/vfs.h>

#include "PVmGBALink.h"
#include "PVmGBANetLinkDriver.h"

#include <stdatomic.h>

/// Transfers the ROM does before it stops.
static const uint32_t kTransfers = 32;
static const size_t kROMSize = 0x400;
static const uint32_t kROMEntryBranch = 0xEA00002E; // b 0x080000C0
static const size_t kROMCodeOffset = 0xC0;
static const int kFrameWaitBudgetMs = 12;
static const NSTimeInterval kRunTimeout = 30;

/// The test ROM, ARM mode, assembled from:
///
///   main:  RCNT = 0; SIOCNT = 0x2003 (multiplayer, 115200 baud)
///          log = 0x02000000; count = 0; log[0] = 0
///   wait_ready: until SIOCNT.ready; if SIOCNT.slave goto slave
///   master: spin ~1024 iterations (lets the slave update its word)
///          SIOMLT_SEND = 0xA000 + count; SIOCNT |= start
///          until !SIOCNT.busy; RECORD; if count < 32 goto master
///   done:  b done
///   slave: SIOMLT_SEND = 0xB000 + count
///          until SIOCNT.busy; until !SIOCNT.busy; RECORD
///          if count < 32 goto slave; b done
///   RECORD: log[1 + count] = SIOMULTI0 | SIOMULTI1 << 16; count++; log[0] = count
static const uint32_t kLinkTestCode[] = {
    0xe3a00301, // 0C0: mov r0, #0x04000000
    0xe2802c01, // 0C4: add r2, r0, #0x100
    0xe3a01000, // 0C8: mov r1, #0
    0xe1c213b4, // 0CC: strh r1, [r2, #0x34]   RCNT
    0xe3a03a02, // 0D0: mov r3, #0x2000
    0xe3833003, // 0D4: orr r3, r3, #3
    0xe1c232b8, // 0D8: strh r3, [r2, #0x28]   SIOCNT
    0xe3a04402, // 0DC: mov r4, #0x02000000
    0xe3a05000, // 0E0: mov r5, #0
    0xe5845000, // 0E4: str r5, [r4]
    0xe1d262b8, // 0E8: ldrh r6, [r2, #0x28]   wait_ready
    0xe3160008, // 0EC: tst r6, #8
    0x0afffffc, // 0F0: beq wait_ready
    0xe3160004, // 0F4: tst r6, #4
    0x1a000014, // 0F8: bne slave
    0xe3a0ab01, // 0FC: mov r10, #1024          master
    0xe25aa001, // 100: subs r10, r10, #1
    0x1afffffd, // 104: bne 0x100
    0xe2857a0a, // 108: add r7, r5, #0xA000
    0xe1c272ba, // 10C: strh r7, [r2, #0x2A]   SIOMLT_SEND
    0xe1d262b8, // 110: ldrh r6, [r2, #0x28]
    0xe3866080, // 114: orr r6, r6, #0x80
    0xe1c262b8, // 118: strh r6, [r2, #0x28]   start
    0xe1d262b8, // 11C: ldrh r6, [r2, #0x28]
    0xe3160080, // 120: tst r6, #0x80
    0x1afffffc, // 124: bne 0x11C
    0xe1d282b0, // 128: ldrh r8, [r2, #0x20]   RECORD
    0xe1d292b2, // 12C: ldrh r9, [r2, #0x22]
    0xe1888809, // 130: orr r8, r8, r9, lsl #16
    0xe2849004, // 134: add r9, r4, #4
    0xe7898105, // 138: str r8, [r9, r5, lsl #2]
    0xe2855001, // 13C: add r5, r5, #1
    0xe5845000, // 140: str r5, [r4]
    0xe3550020, // 144: cmp r5, #32
    0xbaffffeb, // 148: blt master
    0xeafffffe, // 14C: b done
    0xe2857a0b, // 150: add r7, r5, #0xB000    slave
    0xe1c272ba, // 154: strh r7, [r2, #0x2A]
    0xe1d262b8, // 158: ldrh r6, [r2, #0x28]
    0xe3160080, // 15C: tst r6, #0x80
    0x0afffffc, // 160: beq 0x158
    0xe1d262b8, // 164: ldrh r6, [r2, #0x28]
    0xe3160080, // 168: tst r6, #0x80
    0x1afffffc, // 16C: bne 0x164
    0xe1d282b0, // 170: ldrh r8, [r2, #0x20]   RECORD
    0xe1d292b2, // 174: ldrh r9, [r2, #0x22]
    0xe1888809, // 178: orr r8, r8, r9, lsl #16
    0xe2849004, // 17C: add r9, r4, #4
    0xe7898105, // 180: str r8, [r9, r5, lsl #2]
    0xe2855001, // 184: add r5, r5, #1
    0xe5845000, // 188: str r5, [r4]
    0xe3550020, // 18C: cmp r5, #32
    0xbaffffee, // 190: blt slave
    0xeaffffec, // 194: b done
};

static void _silentLog(struct mLogger *logger, int category, enum mLogLevel level, const char *format, va_list args) {
    (void) logger;
    (void) category;
    (void) level;
    (void) format;
    (void) args;
}

static struct mLogger gSilentLogger = { .log = _silentLog };

/// One emulated GBA running the test ROM.
@interface PVmGBALinkTestGBA : NSObject
@property (nonatomic, readonly) struct mCore *core;
@property (nonatomic, readonly) PVmGBANetLinkDriver *driver;
- (instancetype)initWithSession:(PVGBALinkSession *)session;
/// Transfers the ROM has logged so far.
- (uint32_t)transferCount;
- (uint32_t)loggedWordAt:(uint32_t)index;
@end

@implementation PVmGBALinkTestGBA {
    uint32_t *_rom;
    void *_video;
}

- (instancetype)initWithSession:(PVGBALinkSession *)session {
    if ((self = [super init])) {
        _core = GBACoreCreate();
        mCoreInitConfig(_core, NULL);
        _core->init(_core);

        unsigned width, height;
        _core->baseVideoSize(_core, &width, &height);
        _video = calloc((size_t) width * height, BYTES_PER_PIXEL);
        _core->setVideoBuffer(_core, _video, width);

        _rom = calloc(1, kROMSize);
        _rom[0] = kROMEntryBranch;
        memcpy((uint8_t *) _rom + kROMCodeOffset, kLinkTestCode, sizeof(kLinkTestCode));
        _core->loadROM(_core, VFileFromConstMemory(_rom, kROMSize));
        _core->opts.skipBios = true;
        _core->reset(_core);

        _driver = PVmGBANetLinkDriverCreate(session);
        struct GBA *gba = _core->board;
        GBASIOSetDriver(&gba->sio, PVmGBANetLinkDriverBase(_driver));
    }
    return self;
}

- (void)dealloc {
    struct GBA *gba = _core->board;
    GBASIOSetDriver(&gba->sio, NULL);
    PVmGBANetLinkDriverFree(_driver);
    mCoreConfigDeinit(&_core->config);
    _core->deinit(_core);
    free(_video);
    free(_rom);
}

- (uint32_t)transferCount {
    struct GBA *gba = _core->board;
    return gba->memory.wram[0];
}

- (uint32_t)loggedWordAt:(uint32_t)index {
    struct GBA *gba = _core->board;
    return gba->memory.wram[1 + index];
}

@end

@interface PVmGBALinkDriverTests : XCTestCase
@end

@implementation PVmGBALinkDriverTests {
    PVGBALinkSession *_hostSession;
    PVGBALinkSession *_clientSession;
}

+ (void)setUp {
    mLogSetDefaultLogger(&gSilentLogger);
}

- (void)setUp {
    [super setUp];
    _hostSession = PVGBALinkSessionCreate();
    _clientSession = PVGBALinkSessionCreate();
    uint16_t port = 0;
    XCTAssertEqual(PVGBALinkSessionListen(_hostSession, 0, NULL, &port), PVGBALinkOK);

    __block PVGBALinkResult acceptResult = PVGBALinkErrorState;
    dispatch_semaphore_t accepted = dispatch_semaphore_create(0);
    PVGBALinkSession *host = _hostSession;
    [NSThread detachNewThreadWithBlock:^{
        acceptResult = PVGBALinkSessionAccept(host, 5000);
        dispatch_semaphore_signal(accepted);
    }];
    XCTAssertEqual(PVGBALinkSessionConnect(_clientSession, "127.0.0.1", port, NULL, 5000), PVGBALinkOK);
    dispatch_semaphore_wait(accepted, dispatch_time(DISPATCH_TIME_NOW, 6 * NSEC_PER_SEC));
    XCTAssertEqual(acceptResult, PVGBALinkOK);
    XCTAssertEqual(PVGBALinkSessionStart(_hostSession, NULL, NULL), PVGBALinkOK);
    XCTAssertEqual(PVGBALinkSessionStart(_clientSession, NULL, NULL), PVGBALinkOK);
}

- (void)tearDown {
    PVGBALinkSessionDestroy(_hostSession);
    PVGBALinkSessionDestroy(_clientSession);
    [super tearDown];
}

/// Runs `gba` frame by frame on its own thread until `shouldStop` says so or
/// the timeout passes, sleeping `pauseMicroseconds` between frames. Signals
/// `finished` when it returns.
static void RunOnThread(PVmGBALinkTestGBA *gba, useconds_t pauseMicroseconds, BOOL (^shouldStop)(void),
                        dispatch_semaphore_t finished) {
    [NSThread detachNewThreadWithBlock:^{
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:kRunTimeout];
        while (!shouldStop() && deadline.timeIntervalSinceNow > 0) {
            bool stalled = false;
            PVmGBANetLinkDriverRunFrame(gba.driver, gba.core, kFrameWaitBudgetMs, &stalled);
            if (pauseMicroseconds) {
                usleep(pauseMicroseconds);
            }
        }
        dispatch_semaphore_signal(finished);
    }];
}

/// Links two consoles, runs the ROM to the end on both (the client pausing
/// `clientPause` between frames) and checks every logged transfer.
- (void)runLinkedTransfersWithClientPause:(useconds_t)clientPause {
    PVmGBALinkTestGBA *host = [[PVmGBALinkTestGBA alloc] initWithSession:_hostSession];
    PVmGBALinkTestGBA *client = [[PVmGBALinkTestGBA alloc] initWithSession:_clientSession];

    // Both keep running until both are done: the client can only reach the
    // end of the last transfer once the host's clock has passed it.
    __block atomic_bool hostDone = false;
    __block atomic_bool clientDone = false;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    RunOnThread(host, 0, ^BOOL {
        if (host.transferCount >= kTransfers) { atomic_store(&hostDone, true); }
        return atomic_load(&hostDone) && atomic_load(&clientDone);
    }, finished);
    RunOnThread(client, clientPause, ^BOOL {
        if (client.transferCount >= kTransfers) { atomic_store(&clientDone, true); }
        return atomic_load(&hostDone) && atomic_load(&clientDone);
    }, finished);
    dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);

    XCTAssertEqual(host.transferCount, kTransfers);
    XCTAssertEqual(client.transferCount, kTransfers);
    XCTAssertTrue(PVmGBANetLinkDriverIsLinked(host.driver));
    XCTAssertTrue(PVmGBANetLinkDriverIsLinked(client.driver));
    for (uint32_t i = 0; i < MIN(kTransfers, MIN(host.transferCount, client.transferCount)); ++i) {
        // SIOMULTI0 is the host's word, SIOMULTI1 the client's.
        uint32_t expected = (0xA000 + i) | ((0xB000 + i) << 16);
        XCTAssertEqual([host loggedWordAt:i], expected, @"host, transfer %u", i);
        XCTAssertEqual([client loggedWordAt:i], expected, @"client, transfer %u", i);
    }
}

- (void)testMultiplayerTransfersMatchOnBothConsoles {
    [self runLinkedTransfersWithClientPause:0];
}

/// A client slower than the host: the host runs out of wait budget, returns
/// mid-frame, resumes, and throttles once it is too far ahead.
- (void)testSlowClientStaysInStep {
    static const useconds_t kSlowClientPause = 20000;
    [self runLinkedTransfersWithClientPause:kSlowClientPause];
}

- (void)testHostCarriesOnWhenTheClientLeaves {
    static const uint32_t kClientLeavesAfter = 4;
    PVmGBALinkTestGBA *host = [[PVmGBALinkTestGBA alloc] initWithSession:_hostSession];
    PVmGBALinkTestGBA *client = [[PVmGBALinkTestGBA alloc] initWithSession:_clientSession];

    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    PVGBALinkSession *clientSession = _clientSession;
    RunOnThread(client, 0, ^BOOL {
        if (client.transferCount >= kClientLeavesAfter) {
            PVGBALinkSessionStop(clientSession);
            return YES;
        }
        return NO;
    }, finished);
    RunOnThread(host, 0, ^BOOL {
        return host.transferCount >= kTransfers;
    }, finished);
    dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_wait(finished, DISPATCH_TIME_FOREVER);

    // The host never hangs on a transfer the client will not answer: once
    // the link drops, transfers finish with the line idle (0xFFFF).
    XCTAssertEqual(host.transferCount, kTransfers);
    XCTAssertFalse(PVmGBANetLinkDriverIsLinked(host.driver));
    XCTAssertEqual([host loggedWordAt:0], 0xA000u | (0xB000u << 16));
    XCTAssertEqual([host loggedWordAt:kTransfers - 1] >> 16, 0xFFFFu);
}

@end
