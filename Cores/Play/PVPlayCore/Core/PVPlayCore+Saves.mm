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

@implementation PVPlayCoreBridge (Saves)

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

- (BOOL)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    const fs::path fsName(fileName.fileSystemRepresentation);
    auto success = _ps2VM->SaveState(fsName);
    success.wait();
    
    if (success.get()) {
        block(nil);
    } else {
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to save state.",
                                   NSLocalizedFailureReasonErrorKey: @"Play! failed to create savestate data.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check that the path is correct and file exists."
                                   };

        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                            userInfo:userInfo];
        block(newError);
    }
    return success.get();
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

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block {
    if (_ps2VM) {
        const fs::path fsName(fileName.fileSystemRepresentation);
        auto success = _ps2VM->LoadState(fsName);
        success.wait();
        
        if (success.get()) {
            block(nil);
        } else {
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to load save state.",
                                       NSLocalizedFailureReasonErrorKey: @"Play! failed to read savestate data.",
                                       NSLocalizedRecoverySuggestionErrorKey: @"Check that the path is correct and file exists."
                                       };

            NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                    code:PVEmulatorCoreErrorCodeCouldNotLoadState
                                                userInfo:userInfo];
            block(newError);
        }
        return success.get();
    }
}

@end
