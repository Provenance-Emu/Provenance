//
//  PVPlay+Saves.m
//  PVPlay
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPlayCore+Saves.h"
#import "PVPlayCore.h"

@implementation PVPlayCore (Saves)

#pragma mark - Properties
-(BOOL)supportsSaveStates {
    return NO;
}

#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
    return NO;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
//	const fs::path fsName(fileName.fileSystemRepresentation);
//	  auto success = _ps2VM.SaveState(fsName);
//	  success.wait();
//	  block(success.get(), nil);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
    return NO;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
//	//FIXME: load save state at launch fails.
//	const fs::path fsName(fileName.fileSystemRepresentation);
//	auto success = _ps2VM.LoadState(fsName);
//	success.wait();
//	block(success.get(), nil)
}

@end
