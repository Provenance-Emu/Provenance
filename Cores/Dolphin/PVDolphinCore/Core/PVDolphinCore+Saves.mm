//
//  PVDolphin+Saves.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore+Saves.h"
#import "PVDolphinCore.h"

#include "Common/CPUDetect.h"
#include "Common/CommonPaths.h"
#include "Common/CommonTypes.h"
#include "Common/FileUtil.h"
#include "Common/IniFile.h"
#include "Common/Logging/LogManager.h"
#include "Common/MsgHandler.h"
#include "Common/Thread.h"
#include "Common/Version.h"

#include "Core/State.h"

extern bool _isInitialized;
NSString *autoLoadStatefileName;
@implementation PVDolphinCore (Saves)
#pragma mark - Properties
-(BOOL)supportsSaveStates {
	return YES;
}
#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	// we need to make sure we are initialized before attempting to save a state
	if( _isInitialized)
		State::SaveAs([fileName UTF8String]);
	//block(dol_host->SaveState([fileName UTF8String]),nil);
    return true;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
	bool success=false;
	if( _isInitialized) {
		State::SaveAs([fileName UTF8String]);
		success=true;
	}
	block(success, nil);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
	if (!_isInitialized) {
		//Start a separate thread to load
		autoLoadStatefileName = fileName;
		[NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
	} else {
		State::LoadAs([fileName UTF8String]);
		//block(dol_host->LoadState([fileName UTF8String]),nil);
	}
    return true;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
	State::LoadAs([fileName UTF8String]);
	bool success=true;
	block(success, nil);
}

- (void)autoloadWaitThread
{
	@autoreleasepool
	{
		//Wait here until we get the signal for full initialization
		while (!_isInitialized)
				Common::SleepCurrentThread(1000);
		State::LoadAs([autoLoadStatefileName UTF8String]);
		//dol_host->LoadState([autoLoadStatefileName UTF8String]);
	}
}


@end
