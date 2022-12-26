//
//  PVSNESGameCore.h
//  PVSNES
//
//  Created by Stuart Carnie on 30/11/2022.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <PVRuntime/PVRuntime.h>
#import <PVSupport/PVSupport-Swift.h>
// @import PVRuntime;

NS_ASSUME_NONNULL_BEGIN

@interface PVSNESGameCore : OEGameCore<PVSNESSystemResponderClient>

# pragma CheatCodeSupport
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
