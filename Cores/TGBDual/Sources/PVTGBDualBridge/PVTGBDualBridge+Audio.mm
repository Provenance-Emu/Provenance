//
//  PVTGBDualCore+Audio.mm
//  PVTGBDual
//
//  Created by error404-na on 12/31/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

#import "PVTGBDualBridge+Audio.h"

@implementation PVTGBDualBridge (Audio)

- (NSUInteger)channelCount {
    return 2;
}

- (double)audioSampleRate {
    return self->_sampleRate ? self->_sampleRate : 44100.0f;
}

@end
