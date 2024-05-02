//
//  PVAltKitService.m
//  Provenance
//
//  Created by Joseph Mattiello on 7/30/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

#if !TARGET_OS_OSX && !TARGET_OS_MACCATALYST && !TARGET_OS_TV
#import "PVAltKitService.h"
@import PVSupport;
@import AltKit;

@implementation PVAltKitService

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static PVAltKitService *sharedManager = nil;
    dispatch_once(&onceToken, ^{
        sharedManager = [PVAltKitService new];
    });
    return sharedManager;
}

- (void)start {
#if !TARGET_IPHONE_SIMULATOR
    [[ALTServerManager sharedManager] startDiscovering];

    [[ALTServerManager sharedManager]
        autoconnectWithCompletionHandler:^(ALTServerConnection *connection,
                                           NSError *error) {
          if (error) {
            return ELOG(@"Could not auto-connect to server. %@", error);
          }

          [connection enableUnsignedCodeExecutionWithCompletionHandler:^(
                          BOOL success, NSError *error) {
            if (success) {
              ILOG(@"Successfully enabled JIT compilation!");
              [[ALTServerManager sharedManager] stopDiscovering];
            } else {
              WLOG(@"Could not enable JIT compilation. %@", error);
            }

            [connection disconnect];
          }];
        }];
#endif
}

@end
#endif
