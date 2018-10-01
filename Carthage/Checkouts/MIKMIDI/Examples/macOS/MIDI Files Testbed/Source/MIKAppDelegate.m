//
//  MIKAppDelegate.m
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import "MIKAppDelegate.h"
#import "MIKMainWindowController.h"

@import MIKMIDI;

@implementation MIKAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	self.mainWindowController = [MIKMainWindowController windowController];
	[self.mainWindowController showWindow:nil];
}

@end
