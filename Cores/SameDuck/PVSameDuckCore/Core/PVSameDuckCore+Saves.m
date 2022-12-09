//
//  PVSameDuck+Saves.m
//  PVSameDuck
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVSameDuckCore+Saves.h"
#import "PVSameDuckCore.h"

@implementation PVSameDuckCore (Saves)

#pragma mark - Properties
-(BOOL)supportsSaveStates {
    return YES;
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
