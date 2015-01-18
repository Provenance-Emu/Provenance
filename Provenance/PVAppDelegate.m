//
//  PVAppDelegate.m
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVAppDelegate.h"
#import "PVSettingsModel.h"

@interface PVAppDelegate ()

@end

@implementation PVAppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:[[PVSettingsModel sharedInstance] disableAutoLock]];
	
	return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
	if (url && [url isFileURL])
	{
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
		
		NSString *sourcePath = [url path];
		NSString *filename = [sourcePath lastPathComponent];
		NSString *destinationPath = [documentsDirectory stringByAppendingPathComponent:filename];
		
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSError *error = nil;
		BOOL success = [fileManager moveItemAtPath:sourcePath toPath:destinationPath error:&error];
		if (!success || error)
		{
			DLog(@"Unable to move file from %@ to %@ because %@", sourcePath, destinationPath, [error localizedDescription]);
		}
	}
	
	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
