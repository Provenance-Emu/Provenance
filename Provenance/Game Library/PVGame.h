//
//  PVGame.h
//  Provenance
//
//  Created by James Addyman on 15/04/2013.
//  Copyright (c) 2013 JamSoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Realm/Realm.h>

@interface PVGame : RLMObject

@property NSString *title;
@property NSString *romPath;
@property NSString *customArtworkURL;
@property NSString *originalArtworkURL;

@property NSString *md5Hash;

@property BOOL requiresSync;
@property NSString *systemIdentifier;

@property BOOL isFavorite;

@end
