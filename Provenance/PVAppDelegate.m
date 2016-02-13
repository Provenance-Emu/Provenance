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

#if TARGET_OS_TV
#import "PVAppConstants.h"
#endif

@interface PVAppDelegate ()

@end

@implementation PVAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:[[PVSettingsModel sharedInstance] disableAutoLock]];
#if !TARGET_OS_TV
    if (NSClassFromString(@"UIApplicationShortcutItem")) {
        UIApplicationShortcutItem *shortcut = launchOptions[UIApplicationLaunchOptionsShortcutItemKey];
        if ([[shortcut type] isEqualToString:@"kRecentGameShortcut"])
        {
            self.shortcutItemMD5 = (NSString *)[shortcut userInfo][@"PVGameHash"];
        }
    }
#endif
    
	return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];

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
#if TARGET_OS_TV
    else if ([components.path isEqualToString:PVGameControllerKey] &&
             [components.queryItems.firstObject.name isEqualToString:PVGameMD5Key])
    {
        self.shortcutItemMD5 = components.queryItems.firstObject.value;
    }
#endif
    
    return YES;
}

#if !TARGET_OS_TV
- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(nonnull void (^)(BOOL))completionHandler {
    
    if ([[shortcutItem type] isEqualToString:@"kRecentGameShortcut"])
    {
        self.shortcutItemMD5 = (NSString *)[shortcutItem userInfo][@"PVGameHash"];
    }
    
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
