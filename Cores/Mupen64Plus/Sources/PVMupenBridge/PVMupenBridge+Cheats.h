//
//  PVMupenBridge+Cheats.h
//  PVMupen64Plus
//
//  Created by Joseph Mattiello on 1/26/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVMupenBridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVMupenBridge (Cheats)
- (BOOL)setCheatWithCode:(NSString *)code type:(NSString *)type codeType:(NSString *)codeType cheatIndex:(uint8_t)cheatIndex enabled:(BOOL)enabled;
- (NSArray<NSString *> *)cheatCodeTypes;
- (BOOL)supportsCheatCode;
- (void)resetCheatCodes;
@end

NS_ASSUME_NONNULL_END
