//
//  PVGMECore.m
//  PVGME
//
//  Created by Joseph Mattiello on 6/15/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVGMECore.h"
#include <stdatomic.h>
#import "PVGMECore+Controls.h"
#import "PVGMECore+Audio.h"
#import "PVGMECore+Video.h"

#import "PVGMECore+Audio.h"
#import "player.h"

#import <Foundation/Foundation.h>
@import PVCoreBridge;
@import PVLoggingObjC;

#define SAMPLERATE 48000
#define SIZESOUNDBUFFER 48000 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVGMECoreBridge() {

}

@end

#pragma mark - PVGMECore Begin

@implementation PVGMECoreBridge
{
}

- (instancetype)init {
	if (self = [super init]) {
//        pitch_shift = 1;
	}

	_current = self;
	return self;
}

- (void)dealloc {
	_current = nil;
}

#pragma mark - PVEmulatorCore
//- (BOOL)loadFileAtPath:(NSString *)path error:(NSError**)error {
//    BOOL loaded = [super loadFileAtPath:path completionHandler:error];
//
//    return loaded;
//}

- (void)resetEmulation {
    [super resetEmulation];
    start_track(0);
}

- (void)stopEmulation {
    close_file();
    // TODO: This crashes
    [super stopEmulation];
}

#pragma mark - Running
#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);
    
    ELOG(@"Unprocessed var: %s", variable);
    return NULL;
}


@end
