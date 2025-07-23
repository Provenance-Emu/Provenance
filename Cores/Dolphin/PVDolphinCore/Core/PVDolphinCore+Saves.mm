//
//  PVDolphin+Saves.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore+Saves.h"
#import "PVDolphinCore.h"
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
        State::SaveAs(Core::System::GetInstance(), [path UTF8String], true);
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
        ProvenanceHostThreadLock guard;
        State::LoadAs(Core::System::GetInstance(), [path UTF8String]);
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
