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

// Synchronous save/load. Loading blocks until the state has been applied on the CPU
// thread when called off the main thread; see PVDolphinCore+Saves.mm.
- (BOOL)saveStateToFileAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)loadStateFromFileAtPath:(NSString *)path error:(NSError **)error;

// Backs Swift's `loadState(fromFileAtPath:) async throws`. Overridden so the (possibly
// multi-second) wait for boot + apply runs on the bridge's own serial queue instead of
// whichever thread the caller happens to be on.
- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(SaveStateCompletion)block;

@end

NS_ASSUME_NONNULL_END
