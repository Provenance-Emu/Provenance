//
//  ORSSplitViewManager.m
//  MIDI Soundboard
//
//  Created by Andrew Madsen on 6/2/13.
//  Copyright (c) 2013 Open Reel Software. All rights reserved.
//

#import "ORSSplitViewManager.h"
#import "ORSAvailableDevicesTableViewController.h"
#import "ORSSoundboardViewController.h"

@implementation ORSSplitViewManager

- (void)awakeFromNib
{
	[super awakeFromNib];
	
	if ([self.splitViewController.viewControllers count] < 2) return;
	ORSAvailableDevicesTableViewController *availableDevicesController = (ORSAvailableDevicesTableViewController *)[(UINavigationController *)self.splitViewController.viewControllers[0] topViewController];
	ORSSoundboardViewController *soundboardController = self.splitViewController.viewControllers[1];
	availableDevicesController.delegate = soundboardController;
}

- (void)splitViewController:(UISplitViewController *)splitViewController willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)pc
{
	if ([splitViewController.viewControllers count] < 2) return;
	ORSSoundboardViewController *soundboardController = splitViewController.viewControllers[1];
	barButtonItem.title = NSLocalizedString(@"MIDI Devices", @"MIDI Devices");
	[soundboardController.navigationBar.topItem setLeftBarButtonItem:barButtonItem animated:NO];
}

- (void)splitViewController:(UISplitViewController *)splitViewController willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
	if ([splitViewController.viewControllers count] < 2) return;
	ORSSoundboardViewController *soundboardController = splitViewController.viewControllers[1];
	[soundboardController.navigationBar.topItem setLeftBarButtonItem:nil animated:NO];
}

@end
