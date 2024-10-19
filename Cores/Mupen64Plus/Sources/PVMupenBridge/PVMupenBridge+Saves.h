//
//  MupenGameCore+Controls.h
//  MupenGameCore
//
//  Created by Joseph Mattiello on 1/26/22.
//  Copyright © 2022 Provenance. All rights reserved.
//

#import "PVMupenBridge.h"

NS_ASSUME_NONNULL_BEGIN

@interface PVMupenBridge (Saves)
- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error;
- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block;
- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error;
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(NSError *))block;

@end

NS_ASSUME_NONNULL_END
