//
//  RLMRealmConfiguration+GroupConfig.m
//  Provenance
//
//  Created by David Muzi on 2015-12-16.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "RLMRealmConfiguration+GroupConfig.h"
#import "PVAppConstants.h"

@implementation RLMRealmConfiguration (GroupConfig)

+ (RLMRealmConfiguration *)appGroupConfig
{
    RLMRealmConfiguration *config = [RLMRealmConfiguration defaultConfiguration];
    config.path = [self.appGroupPath stringByAppendingPathComponent:@"default.realm"];

    return config;
}

+ (BOOL)supportsAppGroups
{
    return PVAppGroupId.length && [self appGroupContainer];
}

+ (NSURL *)appGroupContainer
{
    return [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:PVAppGroupId];
}

+ (NSString *)appGroupPath
{
    return [self.appGroupContainer.path stringByAppendingPathComponent:@"Library/Caches/"];
}

@end
