//
//  PVCocoaLumberJackLogging.m
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

#import "PVCocoaLumberJackLogging.h"
@import CocoaLumberjack;
@import NSLogger;
@import XCDLumberjackNSLogger;

//#import "DDFileLogger.h"
//#import "DDTTYLogger.h"
//#import "DDASLLogger.h"
//#import "DMLogFormatter.h"
//#import "KFLogFormatter.h"

@interface PVCocoaLumberJackLogging   ()
@property (nonatomic, strong) DDFileLogger *fileLogger;
@end

@implementation PVCocoaLumberJackLogging

- (instancetype)init
{
    self = [super init];
    if (self) {

//        NSObject<DDLogFormatter> *kfFormatter = [KFLogFormatter new];

            // - Start Cocoa lumber jack
            // https://github.com/CocoaLumberjack/CocoaLumberjack/wiki/GettingStarted

            // Only log to console if we're running non-appstore build
            // For speed. File logging only is the fastest (async flushing)
#ifdef DEBUG
            // Always enable for debug builds
        [self initDebugLogging];
#else
		[self initReleaseLogging];
#endif

		[self initFileLogger];
    }

    return self;
}

- (void)initFileLogger {

	// File logger
//	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES); // cache area (not backed up)
//	NSString *logPath = [paths[0] stringByAppendingPathComponent:@"/Logs"];
//
//	[[NSFileManager defaultManager] createDirectoryAtPath:logPath
//							  withIntermediateDirectories:TRUE
//											   attributes:nil
//													error:nil];
//
//
//	DDLogFileManagerDefault *logFileManager = [[DDLogFileManagerDefault alloc] initWithLogsDirectory:logPath];
//
//	_fileLogger = [[DDFileLogger alloc] initWithLogFileManager:logFileManager];
	_fileLogger = [[DDFileLogger alloc] init];
	_fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
	_fileLogger.doNotReuseLogFiles = YES;
	_fileLogger.logFileManager.maximumNumberOfLogFiles = 5;

	//        [_fileLogger setLogFormatter:kfFormatter];

	[DDLog addLogger:_fileLogger];
}

- (void)initDebugLogging {
//    NSObject<DDLogFormatter> *dmFormatter = [DMLogFormatter new];

        // Apple system Logger - Console.app
//    [DDLog addLogger:[DDASLLogger sharedInstance]];

        // TTY Logger - The Debug console output
    [DDLog addLogger:[DDTTYLogger sharedInstance] withLevel:DDLogLevelDebug];
//    [[DDTTYLogger sharedInstance] setLogFormatter:dmFormatter];

        // Enable colors in console. XCode colors is required
        // https://github.com/robbiehanson/XcodeColors
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];

        // NSLogger binding - network logging
        // https://cocoapods.org/?q=XCDLumberjackNSLogger
    [DDLog addLogger:[XCDLumberjackNSLogger new]];
}

- (void)initReleaseLogging {
	// TTY Logger - The Debug console output
	// Release uses only extreme levels
	[DDLog addLogger:[DDTTYLogger sharedInstance] withLevel:DDLogLevelWarning];
//	[[DDTTYLogger sharedInstance] setLogFormatter:dmFormatter];

	// Enable colors in console. XCode colors is required
	// https://github.com/robbiehanson/XcodeColors
	[[DDTTYLogger sharedInstance] setColorsEnabled:YES];
}

- (NSArray*)logFilePaths {
    return self.fileLogger.logFileManager.sortedLogFilePaths;
}

- (NSArray*)logFileInfos {
    return [self.fileLogger.logFileManager sortedLogFileInfos];
}

- (void)flushLogs {
    [DDLog  flushLog];
}

//- (void) logToFile:(NSString *)inString, ... {
//    va_list args;
//	va_start(args, inString);
////    NSString *expString = [[NSString alloc] initWithFormat:inString arguments:args];
//
//        // DDLog takes care of logging to file if a file logger is setup
//    [DDLog log:LOG_ASYNC_INFO
//         level:LOG_LEVEL_DEF
//          flag:LOG_FLAG_INFO
//       context:0
//          file:nil
//      function:nil
//          line:0
//           tag:nil
//        format:inString, args];
//	va_end(args);
//}

@end

