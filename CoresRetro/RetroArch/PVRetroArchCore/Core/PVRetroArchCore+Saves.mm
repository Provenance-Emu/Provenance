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
#include "core_info.h"

@import PVCoreBridge;
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

extern bool _isInitialized;
bool firstLoad = true;
NSString *autoLoadStatefileName;
@implementation PVRetroArchCore (Saves)
#pragma mark - Properties
-(BOOL)supportsSaveStates {
	return core_info_current_supports_savestate();
}
#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	return content_save_state(fileName.UTF8String, true);
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
	bool success=false;
	if (_isInitialized) {
		content_save_state(fileName.UTF8String, true);
		success=true;
	}
    if (!success) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to save state.",
                                   NSLocalizedFailureReasonErrorKey: @"This core either doesn't support save states or failed to create one.",
                                   NSLocalizedRecoverySuggestionErrorKey: @""
                                   };

        NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                            userInfo:userInfo];
        block(newError);
    } else {
        block(nil);
    }
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
    BOOL success = NO;
	if (!_isInitialized) {
		autoLoadStatefileName = fileName;
		[NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
	} else {
        success = content_load_state(fileName.UTF8String, false, true);
	}
    return success;
}

#define LOAD_WAIT_INTERVAL 1
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    NSLog(@"Loading State: Loading...\n");
    bool success = false;
    while (!_isInitialized)
        sleep(LOAD_WAIT_INTERVAL);
    if (firstLoad && [self.coreIdentifier containsString:@"opera"]) {
        autoLoadStatefileName = fileName;
        success = content_load_state(autoLoadStatefileName.UTF8String, true, true);
        [NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
    } else {
        success = content_load_state(fileName.UTF8String, false, true);
    }
    
    if (!success) {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to save state.",
                                   NSLocalizedFailureReasonErrorKey: @"This core either doesn't support save states or failed to create one.",
                                   NSLocalizedRecoverySuggestionErrorKey: @""
                                   };

        NSError *newError = [NSError errorWithDomain:CoreError.PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotSaveState
                                            userInfo:userInfo];
        block(newError);
    } else {
        block(nil);
    }
}

#define START_WAIT_TIME 15
- (void)autoloadWaitThread
{
	@autoreleasepool
	{
		//Wait here until we get the signal for full initialization
        NSLog(@"Loading State: Waiting while loading\n");
        // Opera needs around 15 second lead time to fill memory the 1st time it loads
        sleep(START_WAIT_TIME);
        NSLog(@"Loading State: Waited while loading\n");
		content_load_state(autoLoadStatefileName.UTF8String, false, true);
        firstLoad=false;
	}
}


@end
