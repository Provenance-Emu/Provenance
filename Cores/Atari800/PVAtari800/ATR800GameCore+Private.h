//
//  ATR800GameCore.h
//  PVAtari800
//
//  Created by Joseph Mattiello on 1/20/19.
//  Copyright © 2019 Provenance Emu. All rights reserved.
//

@import Foundation;
@import PVSupport;
#import <PVAtari800/PVAtari800-Swift.h>

extern __weak ATR800GameCore * _currentCore;

@interface ATR800GameCore (ObjC)
- (void) renderToBuffer;
@end
