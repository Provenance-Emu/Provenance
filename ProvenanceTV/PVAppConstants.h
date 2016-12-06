//
//  PVAppConstants.h
//  Provenance
//
//  Created by David Muzi on 2015-12-16.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_TV
#define PVMaxRecentsCount 12
#else
#define PVMaxRecentsCount (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPhone ? 6 : 9)
#endif

extern NSInteger const PVMaxRecentsShortcutCount;

extern NSString *const PVAppGroupId;
extern NSString *const kInterfaceDidChangeNotification;

extern NSString *const PVGameControllerKey;
extern NSString *const PVGameMD5Key;
extern NSString *const PVAppURLKey;

extern float const PVThumbnailMaxResolution;
