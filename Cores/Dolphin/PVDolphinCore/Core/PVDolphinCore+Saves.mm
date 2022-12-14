//
//  PVDolphin+Saves.m
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVDolphinCore+Saves.h"
#import "PVDolphinCore.h"

@implementation PVDolphinCore (Saves)

#pragma mark - Properties
-(BOOL)supportsSaveStates {
    return YES;
}

#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
		// we need to make sure we are initialized before attempting to save a state
//		while (! _isInitialized)
//			usleep (1000);
//
//		block(dol_host->SaveState([fileName UTF8String]),nil);
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    block(NO, nil);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
//	if (!_isInitialized)
//	{
//		//Start a separate thread to load
//		autoLoadStatefileName = fileName;
//
//		[NSThread detachNewThreadSelector:@selector(autoloadWaitThread) toTarget:self withObject:nil];
//		block(true, nil);
//	} else {
//		block(dol_host->LoadState([fileName UTF8String]),nil);
//	}
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    block(NO, nil);
}

- (void)autoloadWaitThread
{
//	@autoreleasepool
//	{
//		//Wait here until we get the signal for full initialization
//		while (!_isInitialized)
//			usleep (100);
//
//		dol_host->LoadState([autoLoadStatefileName UTF8String]);
//	}
}


@end
