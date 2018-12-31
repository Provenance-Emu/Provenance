//
//  PVTGBDualCore+Audio.mm
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVTGBDualCore+Audio.h"

@implementation PVTGBDualCore (Audio)

- (NSTimeInterval)frameInterval {
    return 59.7275005696;
}

- (NSUInteger)channelCount {
    return 2;
}

- (double)audioSampleRate {
    return _sampleRate;
}

@end
