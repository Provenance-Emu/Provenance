//
//  PVAltKitService.h
//  Provenance
//
//  Created by Joseph Mattiello on 7/30/21.
//  Copyright © 2021 Provenance Emu. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface PVAltKitService : NSObject

@property (class, nonatomic, strong, readonly, nonnull) PVAltKitService * sharedInstance NS_SWIFT_NAME(shared);
- (void)start;

@end

NS_ASSUME_NONNULL_END
