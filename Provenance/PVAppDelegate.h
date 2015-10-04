//
//  PVAppDelegate.h
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PVAppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, strong) UIWindow *window;
#if !TARGET_OS_TV
@property (nonatomic, strong) UIApplicationShortcutItem *shortcutItem;
#endif
@end
