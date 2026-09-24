//
//  PVDolphin+Saves.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore+Saves.h"
#import <PVLogging/PVLoggingObjC.h>

#include "Common/CPUDetect.h"
#include "Common/CommonPaths.h"
#include "Common/CommonTypes.h"
#include "Common/FileUtil.h"
#include "Common/IniFile.h"
#include "Common/Logging/LogManager.h"
#include "Common/MsgHandler.h"
#include "Common/Thread.h"
#include "Common/Version.h"

#include "Core/Core.h"
#include "Core/State.h"
#include "Core/System.h"

extern bool _isInitialized;

// Thread safety helper class similar to Android's HostThreadLock
/// Upper bound on how long a save state may take to reach disk. Dolphin states
/// are tens of MB and compress on a background thread; this only bounds the
/// failure path, a normal save returns as soon as the file stops growing.
static const NSTimeInterval kPVSaveStateWriteTimeout = 10.0;

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
static BOOL PVWaitForSaveStateFile(NSString *path, NSTimeInterval timeout) {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    const NSTimeInterval pollInterval = 0.02;
    NSTimeInterval waited = 0;
    unsigned long long lastSize = 0;
    BOOL sawFile = NO;

    while (waited < timeout) {
        NSDictionary<NSFileAttributeKey, id> *attributes =
            [fileManager attributesOfItemAtPath:path error:nil];
        if (attributes != nil) {
            const unsigned long long size = [attributes fileSize];
            if (sawFile && size > 0 && size == lastSize) {
                return YES;
            }
            sawFile = YES;
            lastSize = size;
        }
        usleep((useconds_t)(pollInterval * USEC_PER_SEC));
        waited += pollInterval;
    }

    return sawFile && lastSize > 0;
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
            *error = [NSError errorWithDomain:@"PVDolphinCore" code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Core not initialized"}];
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
        State::SaveAs(system, [path UTF8String]);
        const bool exists = PVWaitForSaveStateFile(path, kPVSaveStateWriteTimeout);
        ILOG(@"💾 SaveState done: fileExists=%d", exists);
        if (!exists) {
            if (error) {
                *error = [NSError errorWithDomain:@"PVDolphinCore" code:1005
                                         userInfo:@{NSLocalizedDescriptionKey: @"Save state file was not written"}];
            }
            return NO;
        }
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVDolphinCore" code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Unknown save error"}];
        }
        return NO;
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)path error:(NSError **)error {
    if (!_isInitialized) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVDolphinCore" code:1003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Core not initialized"}];
        }
        return NO;
    }

    @try {
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            ILOG(@"💾 LoadState MISSING file: %@", path);
            if (error) {
                *error = [NSError errorWithDomain:@"PVDolphinCore" code:1006
                                         userInfo:@{NSLocalizedDescriptionKey: @"Save state file does not exist"}];
            }
            return NO;
        }
        ProvenanceHostThreadLock guard;
        auto& system = Core::System::GetInstance();
        ILOG(@"💾 LoadState <- %@ (core state=%d)", path, (int)Core::GetState(system));
        State::LoadAs(system, [path UTF8String]);
        ILOG(@"💾 LoadState done");
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"PVDolphinCore" code:1004
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Unknown load error"}];
        }
        return NO;
    }
}

#pragma mark - Legacy Methods

//- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
//    // Validate inputs first
//    if (!block) {
//        NSLog(@"[PVDolphin] Save state completion handler is nil");
//        return;
//    }
//
//    if (!fileName || fileName.length == 0) {
//        NSError *error = [NSError errorWithDomain:@"PVDolphinCore" code:1000
//                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid file path"}];
//        block(NO, error);
//        return;
//    }
//
//    if (!_isInitialized) {
//        NSError *error = [NSError errorWithDomain:@"PVDolphinCore" code:1001
//                                         userInfo:@{NSLocalizedDescriptionKey: @"Core not initialized"}];
//        block(NO, error);
//        return;
//    }
//
//    // Perform save operation synchronously to avoid block retention issues
//    BOOL success = NO;
//    NSError *error = nil;
//
//    @try {
//        ProvenanceHostThreadLock guard;
//        State::SaveAs(Core::System::GetInstance(), [fileName UTF8String], true); // wait=true for synchronous save
//        success = YES;
//    } @catch (NSException *exception) {
//        error = [NSError errorWithDomain:@"PVDolphinCore" code:1002
//                                userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Unknown save error"}];
//        success = NO;
//    }
//
//    // Call completion handler immediately
//    block(success, error);
//}

//- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
//    // Validate inputs first
//    if (!block) {
//        NSLog(@"[PVDolphin] Load state completion handler is nil");
//        return;
//    }
//
//    if (!fileName || fileName.length == 0) {
//        NSError *error = [NSError errorWithDomain:@"PVDolphinCore" code:1000
//                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid file path"}];
//        block(NO, error);
//        return;
//    }
//
//    if (!_isInitialized) {
//        NSError *error = [NSError errorWithDomain:@"PVDolphinCore" code:1003
//                                         userInfo:@{NSLocalizedDescriptionKey: @"Core not initialized"}];
//        block(NO, error);
//        return;
//    }
//
//    // Perform load operation synchronously to avoid block retention issues
//    BOOL success = NO;
//    NSError *error = nil;
//
//    @try {
//        ProvenanceHostThreadLock guard;
//        State::LoadAs(Core::System::GetInstance(), [fileName UTF8String]);
//        success = YES;
//    } @catch (NSException *exception) {
//        error = [NSError errorWithDomain:@"PVDolphinCore" code:1004
//                                userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Unknown load error"}];
//        success = NO;
//    }
//
//    // Call completion handler immediately
//    block(success, error);
//}

// Removed autoloadWaitThread - using proper synchronous loading instead

@end
