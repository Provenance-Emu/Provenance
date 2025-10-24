//
//  PVDolphin+Saves.h
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <PVDolphin/PVDolphinCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface PVDolphinCoreBridge (Saves)

// Protocol-required synchronous methods
- (BOOL)saveStateToFileAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)loadStateToFileAtPath:(NSString *)path error:(NSError **)error;

// Legacy methods for compatibility
- (BOOL)saveStateToFileAtPath:(NSString *)fileName;
- (BOOL)loadStateFromFileAtPath:(NSString *)fileName;
- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block;
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block;

@end

NS_ASSUME_NONNULL_END
