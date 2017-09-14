//
//  RLMRealmConfiguration+GroupConfig.h
//  Provenance
//
//  Created by David Muzi on 2015-12-16.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import <Realm/Realm.h>

@interface RLMRealmConfiguration (Config)

+ (void)setRealmConfig;

+ (BOOL)supportsAppGroups;

+ (NSString *)appGroupPath;

@end
