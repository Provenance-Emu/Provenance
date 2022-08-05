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

#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>

#define SAMPLERATE 44100
#define SIZESOUNDBUFFER 44100 / 60 * 4
#define OpenEmu 1

#pragma mark - Private
@interface PVGMECore() {

}

@end

#pragma mark - PVGMECore Begin

@implementation PVGMECore
{
}

- (instancetype)init {
	if (self = [super init]) {
        pitch_shift = 2;
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

#pragma mark - Running
#pragma mark - Options
- (void *)getVariable:(const char *)variable {
    ILOG(@"%s", variable);
    
#define V(x) strcmp(variable, x) == 0
    ELOG(@"Unprocessed var: %s", variable);
#undef V
    return NULL;
}


@end
