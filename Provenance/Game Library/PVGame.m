//
//  PVGame.m
//  Provenance
//
//  Created by James Addyman on 15/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import "PVGame.h"

@implementation PVGame

+ (NSDictionary *)defaultPropertyValues
{
    return @{@"title" : @"",
             @"romPath" : @"",
             @"customArtworkURL" : @"",
             @"originalArtworkURL" : @"",
             @"md5Hash" : @"",
             @"requiresSync" : @YES,
             @"systemIdentifier" : @"",
             @"isFavorite": @NO};
}

+ (NSArray<NSString *> *)requiredProperties
{
	// All properties are required
	return @[@"title",
			 @"romPath",
			 @"customArtworkURL",
			 @"originalArtworkURL",
			 @"md5Hash",
			 @"systemIdentifier",
             @"isFavorite"];
}

@end
