//  PVEmuThree+Saves.m
//  Copyright © 2023 Provenance. All rights reserved.

#import "PVEmuThreeCoreBridge+Saves.h"
#import "PVEmuThreeCoreBridge.h"
#import "../emuThree/CitraWrapper.h"

extern bool _isInitialized;
NSString *autoLoadStatefileName;
@implementation PVEmuThreeCoreBridge (Saves)
#pragma mark - Properties
-(BOOL)supportsSaveStates {
	return YES;
}
#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
	if( _isInitialized)
        [CitraWrapper.sharedInstance requestSave:fileName];
	return true;
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
	bool success=false;
	if( _isInitialized) {
        [CitraWrapper.sharedInstance requestSave:fileName];
		success=true;
	}
    if (success) {
        block(nil);
    } else {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to save save state.",
                                   NSLocalizedFailureReasonErrorKey: @"emuThree failed to save savestate data.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check that the path is correct and file exists."
                                   };

        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                            userInfo:userInfo];
        block(newError);
    }
    return success;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
	if (!_isInitialized) {
		//Start a separate thread to load
		autoLoadStatefileName = fileName;
		[NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
	} else {
        [CitraWrapper.sharedInstance requestLoad:fileName];
	}
    return true;
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    [CitraWrapper.sharedInstance requestLoad:fileName];
	bool success=true;
    
    if (success) {
        block(nil);
    } else {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load save state.",
                                   NSLocalizedFailureReasonErrorKey: @"emuThree failed to read savestate data.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check that the path is correct and file exists."
                                   };

        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                            userInfo:userInfo];
        block(newError);
    }
    return success;
}

- (void)autoloadWaitThread
{
	@autoreleasepool
	{
		//Wait here until we get the signal for full initialization
		while (!_isInitialized)
            usleep(1000);
        [CitraWrapper.sharedInstance requestLoad:autoLoadStatefileName];
    }
}
@end
