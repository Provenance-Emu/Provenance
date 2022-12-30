//
//  PVFlycast+Saves.m
//  PVFlycast
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//
#ifndef LIBRETRO

#import "PVFlycastCore+Saves.h"
#import "PVFlycastCore.h"

@implementation PVFlycastCore (Saves)

#pragma mark - Properties
-(BOOL)supportsSaveStates {
    return NO;
}

#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
    return NO;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    block(NO, nil);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
    return NO;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    block(NO, nil);
}

@end
#endif
