//
//  PVAppConstants.m
//  Provenance
//
//  Created by David Muzi on 2015-12-16.
//  Copyright © 2015 James Addyman. All rights reserved.
//

#import "PVAppConstants.h"

NSInteger const PVMaxRecentsShortcutCount = 4;

NSString *const PVAppGroupId = @"group.provenance-emu.provenance";
NSString *const kInterfaceDidChangeNotification = @"kInterfaceDidChangeNotification";

NSString *const PVGameControllerKey = @"PlayController";
NSString *const PVGameMD5Key = @"md5";
NSString *const PVAppURLKey = @"provenance";

#if TARGET_OS_TV
    float const PVThumbnailMaxResolution = 400.0;
#else
    float const PVThumbnailMaxResolution = 200.0;
#endif
