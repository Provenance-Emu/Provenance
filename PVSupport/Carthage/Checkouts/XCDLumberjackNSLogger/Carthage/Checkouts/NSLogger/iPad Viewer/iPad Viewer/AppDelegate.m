/*
 *
 * Modified BSD license.
 *
 * Copyright (c) 2012-2013 Sung-Taek, Kim <stkim1@colorfulglue.com> All Rights
 * Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of Sung-Tae
 * k Kim nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 *
 */


#import "AppDelegate.h"
#import "LoggerTransportManager.h"
#import "ICloudSupport.h"
#import "LoggerMessageViewController.h"

@implementation AppDelegate
- (void)dealloc
{
    self.window = nil;
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// block whole document directory being backed-up
	NSArray *paths = \
		NSSearchPathForDirectoriesInDomains(NSDocumentDirectory
											,NSUserDomainMask, YES);
	NSString *docDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
	[ICloudSupport disableFilepathFromiCloudSync:docDirectory];
	
	[[LoggerDataStorage sharedDataStorage] appStarted];
	[[LoggerDataManager sharedDataManager] appStarted];
	[[LoggerTransportManager sharedTransportManager] appStarted];
	
	// prevent screen to go sleep. Fine control over this property will be added later
	application.idleTimerDisabled  = YES;
	
	LoggerMessageViewController *root = \
		[[LoggerMessageViewController alloc]
		 initWithNibName:@"LoggerMessageViewController"
		 bundle:[NSBundle mainBundle]];

	[root setDataManager:[LoggerDataManager sharedDataManager]];

	self.window.rootViewController = root;
	[root release],root = nil;

	[self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	application.idleTimerDisabled  = NO;
	[[LoggerTransportManager sharedTransportManager] appResignActive];
	[[LoggerDataManager sharedDataManager] appResignActive];
	[[LoggerDataStorage sharedDataStorage] appResignActive];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	application.idleTimerDisabled  = YES;
	[[LoggerDataStorage sharedDataStorage] appBecomeActive];
	[[LoggerDataManager sharedDataManager] appBecomeActive];
	[[LoggerTransportManager sharedTransportManager] appBecomeActive];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	[[LoggerTransportManager sharedTransportManager] appWillTerminate];
	[[LoggerDataManager sharedDataManager] appWillTerminate];
	[[LoggerDataStorage sharedDataStorage] appWillTerminate];
}

@end
