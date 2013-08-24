//
//  PVGame.h
//  Provenance
//
//  Created by James Addyman on 15/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface PVGame : NSManagedObject

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *romPath;
@property (nonatomic, strong) NSString *artworkURL;
@property (nonatomic, strong) NSString *crc32;
@property (nonatomic, strong) NSString *md5;
@property (nonatomic, strong) NSNumber *requiresSync;
@property (nonatomic, strong) NSNumber *isSyncing;

@end
