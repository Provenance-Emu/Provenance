//
//  ServiceProvider.m
//  TopShelf
//
//  Created by David Muzi on 2015-12-15.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "ServiceProvider.h"
#import "PVRecentGame+TopShelf.h"
#import "RLMRealmConfiguration+GroupConfig.h"
@import Realm;

@interface ServiceProvider ()

@end

@implementation ServiceProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        if ([RLMRealmConfiguration supportsAppGroups]) {
            [RLMRealmConfiguration setDefaultConfiguration:[RLMRealmConfiguration appGroupConfig]];
        }
    }
    return self;
}

#pragma mark - TVTopShelfProvider protocol

- (TVTopShelfContentStyle)topShelfStyle {
    // Return desired Top Shelf style.
    return TVTopShelfContentStyleSectioned;
}

- (NSArray *)topShelfItems {
    
    NSMutableArray *topShelfItems = [[NSMutableArray alloc] init];
    
    if ([RLMRealmConfiguration supportsAppGroups]) {
        
        TVContentIdentifier *identifier = [[TVContentIdentifier alloc] initWithIdentifier:@"id" container:nil];
        TVContentItem *recentItems = [[TVContentItem alloc] initWithContentIdentifier:identifier];
        recentItems.title = @"Recently Played";
        
        RLMResults *recents = [PVRecentGame allObjects];
        id <NSFastEnumeration> recentGames = [recents sortedResultsUsingProperty:@"lastPlayedDate" ascending:NO];
        
        NSMutableArray *items = [[NSMutableArray alloc] init];
        
        for (PVRecentGame *game in recentGames) {
            [items addObject:[game contentItemWithIdentifier:identifier]];
        }
        
        recentItems.topShelfItems = items;
        
        [topShelfItems addObject:recentItems];
    }
    
    return topShelfItems;
}

@end
