//
//  PVMelonDS+Saves.m
//  PVMelonDS
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVMelonDSCore+Saves.h"
#import "PVMelonDSCore.h"

@implementation PVMelonDSCoreBridge (Saves)

#pragma mark - Properties
-(BOOL)supportsSaveStates {
    return NO;
}

#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
    return NO;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    block(nil);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
    return NO;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    block(nil);
}

@end
