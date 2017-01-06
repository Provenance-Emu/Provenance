//
//  RLMRealmConfiguration+GroupConfig.m
//  Provenance
//
//  Created by David Muzi on 2015-12-16.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "RLMRealmConfiguration+Config.h"
#import "PVAppConstants.h"

@implementation RLMRealmConfiguration (GroupConfig)

+ (void)setRealmConfig
{
    RLMRealmConfiguration *config = [[RLMRealmConfiguration alloc] init];
#if TARGET_OS_TV
    NSString *path = nil;
    if ([RLMRealmConfiguration supportsAppGroups]) {
        path = [RLMRealmConfiguration appGroupPath];
    }
    else {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        path = paths.firstObject;
    }
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = paths.firstObject;
#endif
    [config setPath:[path stringByAppendingPathComponent:@"default.realm"]];
    
    // Bump schema version to migrate new PVGame property, isFavorite
    config.schemaVersion = 1;
    config.migrationBlock = ^(RLMMigration *migration, uint64_t oldSchemaVersion) {
        // Nothing to do, Realm handles migration automatically when we set an empty migration block
    };
    
    [RLMRealmConfiguration setDefaultConfiguration:config];
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
