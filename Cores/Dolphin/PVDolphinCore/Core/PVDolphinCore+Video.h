//
//  PVDolphin+Video.h
//  PVDolphin
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#if SWIFT_PACKAGE
#import "PVDolphinCore.h"
#else
#import <PVDolphin/PVDolphinCore.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface PVDolphinCoreBridge (Video)

- (void)videoInterrupt;

@end

NS_ASSUME_NONNULL_END
