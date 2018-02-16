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
    
    if ([self.systemIdentifier isEqualToString:PVSNESSystemIdentifier] ||
        [self.systemIdentifier isEqualToString:PVN64SystemIdentifier]) {
        imageAspectRatio = PVGameBoxArtAspectRatioWide;
    }
    else if ([self.systemIdentifier isEqualToString:PVNESSystemIdentifier] ||
             [self.systemIdentifier isEqualToString:PVGenesisSystemIdentifier] ||
             [self.systemIdentifier isEqualToString:PV32XSystemIdentifier] ||
             [self.systemIdentifier isEqualToString:PV2600SystemIdentifier] ||
             [self.systemIdentifier isEqualToString:PV5200SystemIdentifier] ||
             [self.systemIdentifier isEqualToString:PV7800SystemIdentifier] ||
             [self.systemIdentifier isEqualToString:PVWonderSwanSystemIdentifier])
    {
        imageAspectRatio = PVGameBoxArtAspectRatioTall;
    }
    
    return imageAspectRatio;
}

@end
