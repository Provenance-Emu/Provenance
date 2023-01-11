//
//  PVRetroArch+Saves.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVRetroArchCore+Saves.h"
#import "PVRetroArchCore.h"
#include "content.h"

extern bool _isInitialized;
NSString *autoLoadStatefileName;
@implementation PVRetroArchCore (Saves)
#pragma mark - Properties
-(BOOL)supportsSaveStates {
	return YES;
}
#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	content_save_state(fileName.UTF8String, true, true);
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
	bool success=false;
	if (_isInitialized) {
		content_save_state(fileName.UTF8String, true, true);
		success=true;
	}
	block(success, nil);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
	if (!_isInitialized) {
		autoLoadStatefileName = fileName;
		[NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
	} else {
		content_load_state(fileName.UTF8String, false, true);
	}

}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
	content_load_state(fileName.UTF8String, false, true);
	bool success=true;
	block(success, nil);
}

- (void)autoloadWaitThread
{
	@autoreleasepool
	{
		//Wait here until we get the signal for full initialization
		while (!_isInitialized)
			usleep(1000);
		content_load_state(autoLoadStatefileName.UTF8String, true, true);
	}
}


@end
