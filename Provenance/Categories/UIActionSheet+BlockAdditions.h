//
//  UIActionSheet+BlockAdditions.h
//  Provenance
//
//  Created by James Addyman on 06/04/2013.
//  Copyright (c) 2012 JamSoft. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^PVUIActionSheetAction)(void);

extern NSString * const PVUIActionSheetActionsArrayKey;
extern NSString * const PVUIActionSheetDefaultActionKey;

@interface UIActionSheet (PVBlockAdditions)

- (void)PV_addButtonWithTitle:(NSString *)title action:(PVUIActionSheetAction)action;
- (void)PV_addCancelButtonWithTitle:(NSString *)title action:(PVUIActionSheetAction)action;
- (void)PV_addDestructiveButtonWithTitle:(NSString *)title action:(PVUIActionSheetAction)action;

- (void)PV_setDefaultAction:(PVUIActionSheetAction)action;
- (PVUIActionSheetAction)PV_defaultAction;

- (NSMutableArray *)PV_actions;

@end
