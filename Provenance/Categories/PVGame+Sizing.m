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

CGFloat const PVGameBoxArtAspectRatioSquare = 1.0;
CGFloat const PVGameBoxArtAspectRatioWide = 1.45;
CGFloat const PVGameBoxArtAspectRatioTall = 0.7;

- (CGFloat)boxartAspectRatio
{
    CGFloat imageAspectRatio = PVGameBoxArtAspectRatioSquare;
    
    if ([self.systemIdentifier isEqualToString:PVSNESSystemIdentifier]) {
        imageAspectRatio = PVGameBoxArtAspectRatioWide;
    }
    else if ([self.systemIdentifier isEqualToString:PVNESSystemIdentifier] ||
             [self.systemIdentifier isEqualToString:PVGenesisSystemIdentifier]) {
        imageAspectRatio = PVGameBoxArtAspectRatioTall;
    }
    
    return imageAspectRatio;
}

@end
