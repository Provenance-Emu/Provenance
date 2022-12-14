//
//  PVPlay+Saves.m
//  PVPlay
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import "PVPlayCore+Saves.h"
#import "PVPlayCore.h"

#include "PH_Generic.h"
#include "PS2VM.h"
#include "CGSH_Provenance_OGL.h"

extern CGSH_Provenance_OGL *gsHandler;
extern CPH_Generic *padHandler;
extern UIView *m_view;
extern CPS2VM *_ps2VM;

@implementation PVPlayCore (Saves)

#pragma mark - Properties
-(BOOL)supportsSaveStates {
    return YES;
}

#pragma mark - Methods

- (BOOL)saveStateToFileAtPath:(NSString *)fileName {
    const fs::path fsName(fileName.fileSystemRepresentation);
    auto success = _ps2VM->SaveState(fsName);
    success.wait();
    return YES;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    const fs::path fsName(fileName.fileSystemRepresentation);
    auto success = _ps2VM->SaveState(fsName);
    success.wait();
    block(success.get(), nil);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName {
    if (_ps2VM) {
        const fs::path fsName(fileName.fileSystemRepresentation);
        auto success = _ps2VM->LoadState(fsName);
        success.wait();
        return YES;
    }
    return NO;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block {
    if (_ps2VM) {
        const fs::path fsName(fileName.fileSystemRepresentation);
        auto success = _ps2VM->LoadState(fsName);
        success.wait();
        block(success.get(), nil);
    }
}

@end
