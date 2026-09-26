//
//  PVDolphin+Saves.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore+Saves.h"
#import <PVLogging/PVLoggingObjC.h>

#include <atomic>
#include <cstdio>
#include <cstring>
#include <memory>

#include "Common/CPUDetect.h"
#include "Common/CommonPaths.h"
#include "Common/CommonTypes.h"
#include "Common/FileUtil.h"
#include "Common/IniFile.h"
#include "Common/Logging/LogManager.h"
#include "Common/MsgHandler.h"
#include "Common/Thread.h"
#include "Common/Version.h"

#include "Core/ConfigManager.h"
#include "Core/Core.h"
#include "Core/State.h"
#include "Core/System.h"

extern bool _isInitialized;

static NSString *const kPVDolphinSaveStateErrorDomain = @"PVDolphinCore";

typedef NS_ENUM(NSInteger, PVDolphinSaveStateError) {
    PVDolphinSaveStateErrorSaveNotInitialized = 1001,
    PVDolphinSaveStateErrorSaveException = 1002,
    PVDolphinSaveStateErrorLoadNotInitialized = 1003,
    PVDolphinSaveStateErrorLoadException = 1004,
    PVDolphinSaveStateErrorSaveNotWritten = 1005,
    PVDolphinSaveStateErrorLoadFileMissing = 1006,
    PVDolphinSaveStateErrorLoadIncompatibleVersion = 1007,
    PVDolphinSaveStateErrorLoadWrongGame = 1008,
    PVDolphinSaveStateErrorLoadRejected = 1009,
    PVDolphinSaveStateErrorLoadTimedOut = 1010,
};

/// Upper bound on how long a save state may take to reach disk. Dolphin states
/// are tens of MB and compress on a background thread; this only bounds the
/// failure path, a normal save returns as soon as the file stops growing.
static const NSTimeInterval kPVSaveStateWriteTimeout = 10.0;

/// Upper bound on the time a requested load waits while Dolphin has not even
/// started booting (Core state not `Starting` yet). Launching "from a save state"
/// asks for the load moments after the emulator view appears; Dolphin only begins
/// booting on its own thread once that view has laid out.
static const NSTimeInterval kPVLoadStateBootStartTimeout = 30.0;

/// Upper bound on the whole wait for boot. Deliberately long: with "Wait for
/// Shaders" enabled, video-backend init compiles every cached shader before the
/// core leaves `Starting`, which can take minutes on a cold cache.
static const NSTimeInterval kPVLoadStateBootTimeout = 300.0;

/// Upper bound on waiting for the CPU thread to apply a queued load (decompress
/// tens of MB + DoState). Only bounds the failure path.
static const NSTimeInterval kPVLoadStateApplyTimeout = 20.0;

/// Poll interval for the save-file and boot waits.
static const NSTimeInterval kPVStatePollInterval = 0.02;

/// State.cpp's COOKIE_BASE, which is file-local there. A state file's version
/// cookie is `COOKIE_BASE + STATE_VERSION`; State::GetVersion() is STATE_VERSION.
static constexpr u32 kPVStateCookieBase = 0xBAADBABEu;

/// Number of game-ID characters State.cpp's ValidateHeaders compares.
static constexpr size_t kPVStateGameIDLength = sizeof(State::StateHeaderLegacy::game_id);

// Thread safety helper class similar to Android's HostThreadLock
class ProvenanceHostThreadLock {
public:
    ProvenanceHostThreadLock() : m_lock(s_host_mutex) {
        Core::DeclareAsHostThread();
    }

    ~ProvenanceHostThreadLock() {
        if (m_lock.owns_lock()) {
            Core::UndeclareAsHostThread();
        }
    }

private:
    static std::mutex s_host_mutex;
    std::unique_lock<std::mutex> m_lock;
};

std::mutex ProvenanceHostThreadLock::s_host_mutex;

static NSError *PVMakeSaveStateError(PVDolphinSaveStateError code, NSString *description) {
    return [NSError errorWithDomain:kPVDolphinSaveStateErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: description}];
}

/// Blocks until a save state actually lands on disk, or `timeout` elapses.
///
/// Upstream made Save/Load non-blocking for the caller (dolphin 2322437f96, which
/// also dropped SaveAs's `wait` argument): SaveAs schedules the state capture on
/// the CPU thread and the compress-and-dump thread writes the file afterwards. A
/// bare fileExistsAtPath check right after the call therefore reports a false
/// failure for a save that is merely still in flight.
///
/// Waits for the size to stop growing, not just for the file to appear, so a
/// partially written state is never reported as a successful save.
///
/// `previousModificationDate` is the file's mtime from BEFORE SaveAs was called (nil
/// if there was no file). When a save overwrites an existing slot, the old file is
/// already on disk with a stable size, so without this the wait would return
/// immediately — reporting success before the new state was written. Only a file
/// modified after that date counts.
static BOOL PVWaitForSaveStateFile(NSString *path,
                                   NSDate *_Nullable previousModificationDate,
                                   NSTimeInterval timeout) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSTimeInterval waited = 0;
    unsigned long long lastSize = 0;
    BOOL sawFile = NO;

    while (waited < timeout) {
        NSDictionary<NSFileAttributeKey, id> *attributes =
            [fileManager attributesOfItemAtPath:path error:nil];
        NSDate *modified = [attributes fileModificationDate];
        const BOOL isNewWrite = attributes != nil
            && (previousModificationDate == nil
                || (modified != nil && [modified compare:previousModificationDate] == NSOrderedDescending));
        if (isNewWrite) {
            const unsigned long long size = [attributes fileSize];
            if (sawFile && size > 0 && size == lastSize) {
                return YES;
            }
            sawFile = YES;
            lastSize = size;
        }
        usleep((useconds_t)(kPVStatePollInterval * USEC_PER_SEC));
        waited += kPVStatePollInterval;
    }

    return sawFile && lastSize > 0;
}

/// Reads the two fixed-size headers at the start of a state file. State::ReadHeader
/// is file-local in the pinned core, so read them directly (same approach as iCube's
/// TVEmulationBridge stateFileIsCompatibleAtPath:).
static BOOL PVReadStateHeader(NSString *path, State::StateHeader &header) {
    FILE *file = fopen(path.fileSystemRepresentation, "rb");
    if (file == nullptr) {
        return NO;
    }
    const bool ok = fread(&header.legacy_header, sizeof(header.legacy_header), 1, file) == 1 &&
                    fread(&header.version_header, sizeof(header.version_header), 1, file) == 1;
    fclose(file);
    return ok ? YES : NO;
}

/// Blocks until Dolphin's CPU thread is up (Core state Running — which also covers
/// Paused). Gives up when the core is being torn down, when the boot failed, when
/// booting has not started within kPVLoadStateBootStartTimeout, or after
/// kPVLoadStateBootTimeout overall.
///
/// `_isInitialized` alone is not enough: startDolphin sets it as soon as the core
/// leaves `Starting`, which includes a failed boot dropping straight back to
/// `Uninitialized`.
static BOOL PVWaitForDolphinRunning(PVDolphinCoreBridge *bridge) {
    auto& system = Core::System::GetInstance();
    NSTimeInterval waited = 0;
    NSTimeInterval waitedWithoutBooting = 0;
    while (!(_isInitialized && Core::IsRunning(system))) {
        const bool bootFailed = _isInitialized && Core::IsUninitialized(system);
        if (bridge.shouldStop || bootFailed || waited >= kPVLoadStateBootTimeout ||
            waitedWithoutBooting >= kPVLoadStateBootStartTimeout) {
            return NO;
        }
        usleep((useconds_t)(kPVStatePollInterval * USEC_PER_SEC));
        waited += kPVStatePollInterval;
        if (Core::GetState(system) != Core::State::Starting) {
            waitedWithoutBooting += kPVStatePollInterval;
        }
    }
    return YES;
}

@implementation PVDolphinCoreBridge (Saves)
#pragma mark - Properties
-(BOOL)supportsSaveStates {
	return YES;
}
#pragma mark - Protocol Methods

// Protocol-required synchronous methods with error handling
- (BOOL)saveStateToFileAtPath:(NSString *)path error:(NSError **)error {
    if (!_isInitialized) {
        if (error) {
            *error = PVMakeSaveStateError(PVDolphinSaveStateErrorSaveNotInitialized, @"Core not initialized");
        }
        return NO;
    }

    @try {
        ProvenanceHostThreadLock guard;
        auto& system = Core::System::GetInstance();
        // Diagnostic trail for the "saves are finicky" reports: log core state going
        // in and whether the file actually landed. SaveAs returns before the state is
        // written (see PVWaitForSaveStateFile), so a miss here is either the init gate
        // above or the file never being written at all.
        ILOG(@"💾 SaveState -> %@ (core state=%d)", path, (int)Core::GetState(system));
        NSDate *previousModificationDate =
            [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileModificationDate];
        State::SaveAs(system, [path UTF8String]);
        const bool exists = PVWaitForSaveStateFile(path, previousModificationDate, kPVSaveStateWriteTimeout);
        ILOG(@"💾 SaveState done: fileExists=%d", exists);
        if (!exists) {
            if (error) {
                *error = PVMakeSaveStateError(PVDolphinSaveStateErrorSaveNotWritten, @"Save state file was not written");
            }
            return NO;
        }
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = PVMakeSaveStateError(PVDolphinSaveStateErrorSaveException, exception.reason ?: @"Unknown save error");
        }
        return NO;
    }
}

/// Loads a state and, off the main thread, only returns once it has been applied.
///
/// State::LoadAs is fire-and-forget since upstream 2322437f96: it queues the load as
/// a CPU-thread job and returns before anything is read, and it silently drops the
/// request when the core is not Running yet (CheckIfStateLoadIsAllowed). Provenance
/// requests the launch-from-save load right after the emulator view appears, while
/// Dolphin is still booting, so that request used to be rejected outright; a mid-game
/// load was reported as done before it applied.
///
/// iCube (same core) waits for the core to leave `Starting` and only then issues
/// LoadAs (EmulationCoordinator.mm waits out Starting before posting
/// DOLEmulationDidStartNotification; SaveStateService then loads). This does the same,
/// then waits for the CPU thread to actually run the load.
///
/// On the main thread nothing here blocks on boot or on the CPU thread: the load is
/// issued only if the core is already running and success means "queued".
- (BOOL)loadStateFromFileAtPath:(NSString *)path error:(NSError **)error {
    @try {
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            ILOG(@"💾 LoadState MISSING file: %@", path);
            if (error) {
                *error = PVMakeSaveStateError(PVDolphinSaveStateErrorLoadFileMissing, @"Save state file does not exist");
            }
            return NO;
        }

        // Mirror State.cpp ValidateHeaders, which otherwise rejects a state with nothing
        // but an on-screen message while the caller is told the load succeeded.
        State::StateHeader header;
        const bool versionMatches = PVReadStateHeader(path, header) &&
            header.version_header.version_cookie - kPVStateCookieBase == State::GetVersion();
        if (!versionMatches) {
            ILOG(@"💾 LoadState incompatible version: %@", path);
            if (error) {
                *error = PVMakeSaveStateError(PVDolphinSaveStateErrorLoadIncompatibleVersion,
                                              @"This save state was created by an incompatible version of the Dolphin core");
            }
            return NO;
        }

        const bool mayBlock = ![NSThread isMainThread];
        auto& system = Core::System::GetInstance();
        const bool running = mayBlock ? PVWaitForDolphinRunning(self)
                                      : (_isInitialized && Core::IsRunning(system));
        if (!running) {
            ILOG(@"💾 LoadState core not running (core state=%d, stopping=%d)",
                 (int)Core::GetState(system), (int)self.shouldStop);
            if (error) {
                *error = PVMakeSaveStateError(PVDolphinSaveStateErrorLoadNotInitialized, @"Core not initialized");
            }
            return NO;
        }

        // The game ID is only known once the disc has booted, so this can't move up.
        if (strncmp(SConfig::GetInstance().GetGameID().c_str(), header.legacy_header.game_id,
                    kPVStateGameIDLength) != 0) {
            ILOG(@"💾 LoadState belongs to a different game: %@", path);
            if (error) {
                *error = PVMakeSaveStateError(PVDolphinSaveStateErrorLoadWrongGame,
                                              @"This save state belongs to a different game");
            }
            return NO;
        }

        ProvenanceHostThreadLock guard;
        std::string statePath([path fileSystemRepresentation]);
        ILOG(@"💾 LoadState <- %@ (core state=%d)", path, (int)Core::GetState(system));

        if (!mayBlock) {
            WLOG(@"💾 LoadState called on the main thread; queued without confirming it applied");
            State::LoadAs(system, statePath);
            return YES;
        }

        // Issue the load as our own CPU-thread job. On the CPU thread LoadAs runs
        // LoadAsFromCore inline instead of queueing yet another job, so `applied` is
        // signalled only after the state is in. The after-load callback only fires if
        // LoadAsFromCore actually ran, which tells a load apart from the silent
        // netplay / RetroAchievements-hardcore rejection in CheckIfStateLoadIsAllowed.
        // Everything the job touches is owned by the job (the semaphore is retained,
        // the flag is shared), so a waiter that timed out and returned before the job
        // runs leaves nothing dangling.
        dispatch_semaphore_t applied = dispatch_semaphore_create(0);
        auto loadRan = std::make_shared<std::atomic<bool>>(false);
        Core::RunOnCPUThread(system, [&system, statePath, applied, loadRan]() {
            State::SetOnAfterLoadCallback([loadRan] { loadRan->store(true); });
            State::LoadAs(system, statePath);
            State::SetOnAfterLoadCallback(nullptr);
            dispatch_semaphore_signal(applied);
        });

        const dispatch_time_t deadline =
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPVLoadStateApplyTimeout * NSEC_PER_SEC));
        if (dispatch_semaphore_wait(applied, deadline) != 0) {
            ELOG(@"💾 LoadState timed out waiting for the CPU thread to apply %@", path);
            if (error) {
                *error = PVMakeSaveStateError(PVDolphinSaveStateErrorLoadTimedOut,
                                              @"Timed out waiting for the save state to load");
            }
            return NO;
        }
        if (!loadRan->load()) {
            ILOG(@"💾 LoadState rejected by the core (netplay or RetroAchievements hardcore)");
            if (error) {
                *error = PVMakeSaveStateError(PVDolphinSaveStateErrorLoadRejected,
                                              @"Loading save states is disabled during netplay and RetroAchievements hardcore mode");
            }
            return NO;
        }
        ILOG(@"💾 LoadState applied");
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = PVMakeSaveStateError(PVDolphinSaveStateErrorLoadException, exception.reason ?: @"Unknown load error");
        }
        return NO;
    }
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(SaveStateCompletion)block {
    NSString *path = [fileName copy];
    dispatch_async(_callbackQueue, ^{
        NSError *error = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        const BOOL loaded = [self loadStateFromFileAtPath:path error:&error];
#pragma clang diagnostic pop
        block(loaded ? nil : error);
    });
}

@end
