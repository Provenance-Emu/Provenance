//  PVEmuThree+Saves.m
//  Copyright © 2023 Provenance. All rights reserved.

#import "PVEmuThreeCore+Saves.h"
#import "PVEmuThreeCore.h"
#import "../emuThree/CitraWrapper.h"

extern bool _isInitialized;
NSString *autoLoadStatefileName;
@implementation PVEmuThreeCore (Saves)
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

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
	bool success=false;
	if( _isInitialized) {
        [CitraWrapper.sharedInstance requestSave:fileName];
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
        [CitraWrapper.sharedInstance requestLoad:fileName];
	}
    return true;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    [CitraWrapper.sharedInstance requestLoad:fileName];
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
        [CitraWrapper.sharedInstance requestLoad:autoLoadStatefileName];
    }
}
@end
