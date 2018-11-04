//
//  Created by Cédric Luthi on 25/04/16.
//  Copyright © 2016 Cédric Luthi. All rights reserved.
//

#import "AppDelegate.h"

#import <XCDLumberjackNSLogger/XCDLumberjackNSLogger.h>

@implementation AppDelegate

@synthesize window = _window;

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[XCDLumberjackNSLogger bindToBonjourServiceNameUserDefaultsKey:@"NSLoggerBonjourServiceName" configurationHandler:nil];
	
	DDTTYLogger *ttyLogger = [DDTTYLogger sharedInstance];
	ttyLogger.colorsEnabled = YES;
	[DDLog addLogger:ttyLogger withLevel:DDLogLevelWarning];
	
	return YES;
}

@end
