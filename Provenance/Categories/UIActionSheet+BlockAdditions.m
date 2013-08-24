//
//  UIActionSheet+BlockAdditions.m
//  Provenance
//
//  Created by James Addyman on 06/04/2013.
//  Copyright (c) 2012 JamSoft. All rights reserved.
//

#import "UIActionSheet+BlockAdditions.h"
#import <objc/runtime.h>

NSString * const PVUIActionSheetActionsArrayKey = @"PVUIActionSheetActionsArrayKey";
NSString * const PVUIActionSheetDefaultActionKey = @"PVUIActionSheetDefaultActionKey";

@implementation UIActionSheet (PVBlockAdditions)

- (NSMutableArray *)PV_actions
{
	[self setDelegate:(id <UIActionSheetDelegate>)self];
	
	NSMutableArray *actions = objc_getAssociatedObject(self, (__bridge const void *)(PVUIActionSheetActionsArrayKey));
	if (!actions)
	{
		actions = [[NSMutableArray alloc] init];
		objc_setAssociatedObject(self, (__bridge const void *)(PVUIActionSheetActionsArrayKey), actions, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	
	return actions;
}

- (void)PV_setDefaultAction:(PVUIActionSheetAction)action
{
	objc_setAssociatedObject(self, (__bridge const void *)PVUIActionSheetDefaultActionKey, action, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (PVUIActionSheetAction)PV_defaultAction
{
	return objc_getAssociatedObject(self, (__bridge const void *)(PVUIActionSheetDefaultActionKey));
}

- (void)PV_addButtonWithTitle:(NSString *)title action:(PVUIActionSheetAction)action
{
	[self addButtonWithTitle:title];
	if (action)
	{
		PVUIActionSheetAction blockCopy = [action copy];
		[[self PV_actions] addObject:blockCopy];
	}
	else
	{
		[[self PV_actions] addObject:[NSNull null]];
	}
}

- (void)PV_addCancelButtonWithTitle:(NSString *)title action:(PVUIActionSheetAction)action
{
	NSInteger index = [self addButtonWithTitle:title];
	[self setCancelButtonIndex:index];
	if (action)
	{
		PVUIActionSheetAction blockCopy = [action copy];
		[[self PV_actions] addObject:blockCopy];
	}
	else
	{
		[[self PV_actions] addObject:[NSNull null]];
	}
}

- (void)PV_addDestructiveButtonWithTitle:(NSString *)title action:(PVUIActionSheetAction)action
{
	NSInteger index = [self addButtonWithTitle:title];
	[self setDestructiveButtonIndex:index];
	if (action)
	{
		PVUIActionSheetAction blockCopy = [action copy];
		[[self PV_actions] addObject:blockCopy];
	}
	else
	{
		[[self PV_actions] addObject:[NSNull null]];
	}
}

- (void)actionSheet:(UIActionSheet *)sheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	if (buttonIndex < [[self PV_actions] count])
	{
		PVUIActionSheetAction action = [[self PV_actions] objectAtIndex:buttonIndex];
		if ([action isKindOfClass:[NSNull class]] == NO)
		{
			action();
		}
		
		objc_setAssociatedObject(self, (__bridge const void *)(PVUIActionSheetActionsArrayKey), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	else
	{
		PVUIActionSheetAction action = [self PV_defaultAction];
		if (action)
		{
			action();
		}
	}
}

@end
