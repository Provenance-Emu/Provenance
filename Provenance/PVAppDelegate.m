//
//  PVAppDelegate.m
//  Provenance
//
//  Created by James Addyman on 07/08/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVAppDelegate.h"
#import "PVSettingsModel.h"
#import "PVControllerManager.h"

@interface PVAppDelegate ()

@end

@implementation PVAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:[[PVSettingsModel sharedInstance] disableAutoLock]];
#if !TARGET_OS_TV
    if (NSClassFromString(@"UIApplicationShortcutItem")) {
        UIApplicationShortcutItem *shortcut = launchOptions[UIApplicationLaunchOptionsShortcutItemKey];
        if (shortcut)
        {
            self.shortcutItem = shortcut;
        }
    }
#endif
	return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
	if (url && [url isFileURL])
	{
#if TARGET_OS_TV
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
		NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
        NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
		
		NSString *sourcePath = [url path];
		NSString *filename = [sourcePath lastPathComponent];
		NSString *destinationPath = [[documentsDirectory stringByAppendingPathComponent:@"roms"] stringByAppendingPathComponent:filename];
		
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

#if !TARGET_OS_TV
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(nonnull void (^)(BOOL))completionHandler {
    self.shortcutItem = shortcutItem;
    completionHandler(YES);
}
#endif

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
