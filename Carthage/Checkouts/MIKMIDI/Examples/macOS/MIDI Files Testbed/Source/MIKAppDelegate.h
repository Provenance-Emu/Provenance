//
//  MIKAppDelegate.h
//  MIDI Files Testbed
//
//  Created by Andrew Madsen on 5/21/14.
//  Copyright (c) 2014 Mixed In Key. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MIKMainWindowController;

@interface MIKAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong) MIKMainWindowController *mainWindowController;

@end
