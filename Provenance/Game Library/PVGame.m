//
//  PVGame.m
//  Provenance
//
//  Created by James Addyman on 15/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import "PVGame.h"
#import "PVEmulatorConstants.h"

@implementation PVGame

+ (NSDictionary *)defaultPropertyValues
{
    return @{@"title" : @"",
             @"romPath" : @"",
             @"customArtworkURL" : @"",
             @"originalArtworkURL" : @"",
             @"md5Hash" : @"",
             @"requiresSync" : @YES,
             @"systemIdentifier" : @"",};
}

+ (NSArray<NSString *> *)requiredProperties
{
	// All properties are required
	return @[@"title",
			 @"romPath",
			 @"customArtworkURL",
			 @"originalArtworkURL",
			 @"md5Hash",
			 @"systemIdentifier"];
}

- (NSString *)placeholderImageName {
    
    // TODO: to be replaced with the correct system placeholder
    
    NSString *systemImageName = @"UNKNONW";
    
    if ([self.systemIdentifier isEqualToString:PVGenesisSystemIdentifier]) {
        return systemImageName = @"GENESIS";
    } else if ([self.systemIdentifier isEqualToString:PVGameGearSystemIdentifier]) {
        return systemImageName = @"GAME GEAR";
    } else if ([self.systemIdentifier isEqualToString:PVMasterSystemSystemIdentifier]) {
        return systemImageName = @"MASTER SYSTEM";
    } else if ([self.systemIdentifier isEqualToString:PVSegaCDSystemIdentifier]) {
        return systemImageName = @"SEGA CD";
    } else if ([self.systemIdentifier isEqualToString:PVSG1000SystemIdentifier]) {
        return systemImageName = @"SG 1000";
    } else if ([self.systemIdentifier isEqualToString:PVSNESSystemIdentifier]) {
        return systemImageName = @"SNES";
    } else if ([self.systemIdentifier isEqualToString:PVNESSystemIdentifier]) {
        return systemImageName = @"NES";
    } else if ([self.systemIdentifier isEqualToString:PVFDSSystemIdentifier]) {
        return systemImageName = @"FAMICOM";
    } else if ([self.systemIdentifier isEqualToString:PVGBASystemIdentifier]) {
        return systemImageName = @"GAME BOY ADVANCE";
    } else if ([self.systemIdentifier isEqualToString:PVGBCSystemIdentifier]) {
        return systemImageName = @"GAME BOY COLOR";;
    } else if ([self.systemIdentifier isEqualToString:PVGBSystemIdentifier]) {
        return systemImageName = @"GAME BOY";;
    }

    return systemImageName;
}

@end
