//
//  PVPPSSPP+Saves.m
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPPSSPPCore+Saves.h"
#import "PVPPSSPPCore.h"
#import <PVLogging/PVLogging.h>

/* PPSSPP Includes */
#import <dlfcn.h>
#import <pthread.h>
#import <signal.h>
#import <string>
#import <stdio.h>
#import <stdlib.h>
#import <sys/syscall.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <mach/machine.h>

#import <AudioToolbox/AudioToolbox.h>

#include "Common/MemoryUtil.h"
#include "Common/Profiler/Profiler.h"
#include "Common/CPUDetect.h"
#include "Common/Log.h"
#include "Common/LogManager.h"
#include "Common/TimeUtil.h"
#include "Common/File/FileUtil.h"
#include "Common/Serialize/Serializer.h"
#include "Common/ConsoleListener.h"
#include "Common/Input/InputState.h"
#include "Common/Input/KeyCodes.h"
#include "Common/Thread/ThreadUtil.h"
#include "Common/Thread/ThreadManager.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Data/Text/I18n.h"
#include "Common/StringUtils.h""
#include "Common/System/Display.h"
#include "Common/System/NativeApp.h"
#include "Common/System/System.h"
#include "Common/GraphicsContext.h"
#include "Common/Net/Resolve.h"
#include "Common/UI/Screen.h"
#include "Common/GPU/thin3d.h"
#include "Common/GPU/thin3d_create.h"
#include "Common/GPU/OpenGL/GLRenderManager.h"
#include "Common/GPU/OpenGL/GLFeatures.h"
#include "Common/System/NativeApp.h"
#include "Common/File/VFS/VFS.h"
#include "Common/Log.h"
#include "Common/TimeUtil.h"
#include "Common/GraphicsContext.h"

#include "GPU/GPUState.h"
#include "GPU/GPUInterface.h""

#include "Core/Config.h"
#include "Core/ConfigValues.h"
#include "Core/Core.h"
#include "Core/CoreParameter.h"
#include "Core/HLE/sceCtrl.h"
#include "Core/HLE/sceUtility.h"
#include "Core/HW/MemoryStick.h"
#include "Core/MemMap.h"
#include "Core/System.h"
#include "Core/CoreTiming.h"
#include "Core/HW/Display.h"
#include "Core/CwCheat.h"
#include "Core/ELF/ParamSFO.h"
#include "Core/SaveState.h"
#define MAX_WAIT 1000
#define WAIT_INTERVAL 100

extern bool _isInitialized;
NSString *autoLoadStatefileName;
static bool isComplete;
static bool success;
static int waited=0;
static bool processed;

@implementation PVPPSSPPCore (Saves)
#pragma mark - Properties
-(BOOL)supportsSaveStates {
	return YES;
}
#pragma mark - Methods

- (bool) saveComplete:(void (^)(BOOL, NSError *))block {
    while (!isComplete && processed) {
        sleep_ms(WAIT_INTERVAL);
    }
    block(success, nil);
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	SaveState::Save(Path([fileName fileSystemRepresentation]), 0, [] (SaveState::Status status, const std::string &message, void *userdata) mutable {
        PVPPSSPPCore* core = (__bridge PVPPSSPPCore*)userdata;
        success=status != SaveState::Status::FAILURE;
        isComplete=true;
    }, (__bridge void *)self);
    processed=false;
    if (isPaused) {
        NSLog(@"Processing Save (Should only happen when paused)\n");
        SaveState::Process();
        processed=true;
    } else {
        success=true;
    }
    while (!isComplete && processed) {
        sleep_ms(WAIT_INTERVAL);
    }
    return success;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    success=false;
    isComplete=false;
    SaveState::Save(Path([fileName fileSystemRepresentation]), 0, [&block] (SaveState::Status status, const std::string &message, void *userdata) mutable {
        PVPPSSPPCore* core = (__bridge PVPPSSPPCore*)userdata;
        success=status != SaveState::Status::FAILURE;
        isComplete=true;
    }, (__bridge void *)self);
    processed=false;
    if (isPaused) {
        NSLog(@"Processing Save (Should only happen when paused)\n");
        SaveState::Process();
        processed=true;
    } else {
        success=true;
    }
    [self saveComplete:block];
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
    bool success=false;
    if (!_isInitialized || GetUIState() != UISTATE_INGAME) {
        autoLoadStatefileName = fileName;
        [NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
    } else {
        SaveState::Load(Path([fileName fileSystemRepresentation]), 0, 0, (__bridge void*)self);
        success=true;
    }
    return true;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    bool success=false;
    if (!_isInitialized || GetUIState() != UISTATE_INGAME) {
        autoLoadStatefileName = fileName;
        [NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
    } else {
        SaveState::Load(Path([fileName fileSystemRepresentation]), 0, 0, (__bridge void*)self);
        success=true;
    }
    block(true, nil);
}


- (void)autoloadWaitThread
{
    @autoreleasepool
    {
        //Wait here until we get the signal for full initialization
        while (!_isInitialized || GetUIState() != UISTATE_INGAME) {
            sleep_ms(WAIT_INTERVAL);
        }
        if(_isInitialized && GetUIState() == UISTATE_INGAME) {
            SaveState::Load(Path([autoLoadStatefileName fileSystemRepresentation]), 0, 0, (__bridge void*)self);
        }
    }
}
@end
