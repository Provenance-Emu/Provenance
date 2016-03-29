//
//  PVGame+Sizing.m
//  Provenance
//
//  Created by David Muzi on 2016-03-29.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVGame+Sizing.h"
#import "PVEmulatorConstants.h"

@implementation PVGame (Sizing)

- (CGSize)boxartSize
{
    CGFloat imageAspectRatio = 1.0;
    CGFloat width = 280.0;
    
    if ([self.systemIdentifier isEqualToString:PVSNESSystemIdentifier]) {
        imageAspectRatio = 1.40;
    }
    else if ([self.systemIdentifier isEqualToString:PVNESSystemIdentifier] ||
             [self.systemIdentifier isEqualToString:PVGenesisSystemIdentifier]) {
        imageAspectRatio = 0.70;
    }
    return CGSizeMake(width, width/imageAspectRatio);
}

@end
