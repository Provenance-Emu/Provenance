//
//  PVCocoaLumberJackLogging.m
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

#import "PVCocoaLumberJackLogging.h"
@import CocoaLumberjack;

@interface PVCocoaLumberJackLogging   ()
@property (nonatomic, strong) DDFileLogger *fileLogger;
@end

@implementation PVCocoaLumberJackLogging

- (instancetype)init
{
    self = [super init];
    if (self) {
            // Only log to console if we're running non-appstore build
            // For speed. File logging only is the fastest (async flushing)
#ifdef DEBUG
            // Always enable for debug builds
        [DDLog addLogger:[DDOSLogger sharedInstance] withLevel:DDLogLevelDebug];
#else
        [DDLog addLogger:[DDOSLogger sharedInstance] withLevel:DDLogLevelWarning];
#endif

		[self initFileLogger];
    }

    return self;
}

- (void)initFileLogger {
	_fileLogger = [[DDFileLogger alloc] init];
	_fileLogger.rollingFrequency = 60 * 60 * 24; // 24 hour rolling
	_fileLogger.doNotReuseLogFiles = YES;
	_fileLogger.logFileManager.maximumNumberOfLogFiles = 5;

	//        [_fileLogger setLogFormatter:kfFormatter];

	[DDLog addLogger:_fileLogger];
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

@end

