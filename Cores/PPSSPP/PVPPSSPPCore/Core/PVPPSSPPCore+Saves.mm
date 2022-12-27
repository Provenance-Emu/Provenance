//
//  PVPPSSPP+Saves.m
//  PVPPSSPP
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPPSSPPCore+Saves.h"
#import "PVPPSSPPCore.h"

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
#include "Common/File/VFS/AssetReader.h"
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
#include "Core/Host.h"
#include "Core/MemMap.h"
#include "Core/System.h"
#include "Core/CoreTiming.h"
#include "Core/HW/Display.h"
#include "Core/CwCheat.h"
#include "Core/ELF/ParamSFO.h"
#include "Core/SaveState.h"

extern bool _isInitialized;
NSString *autoLoadStatefileName;

@implementation PVPPSSPPCore (Saves)
#pragma mark - Properties
-(BOOL)supportsSaveStates {
	return YES;
}
#pragma mark - Methods
- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	bool success=false;
	SaveState::Save(Path([fileName fileSystemRepresentation]), 0, 0);
	SaveState::Process();
	success=true;
	return success;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
	bool success=false;
	SaveState::Save(Path([fileName fileSystemRepresentation]), 0, [&block, &success] (SaveState::Status status, const std::string &message, void *data) mutable {
		success = (status != SaveState::Status::FAILURE);
		block(success, nil);
	});
	SaveState::Process();
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
	bool success=false;
	if(_isInitialized) {
		SaveState::Load(Path([fileName fileSystemRepresentation]), 0, 0);
		success=true;
	}
	return success;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
	bool success=false;
	if(_isInitialized && GetUIState() == UISTATE_INGAME) {
		SaveState::Load(Path([fileName fileSystemRepresentation]), 0, 0);
		success=true;
	}
}
@end
