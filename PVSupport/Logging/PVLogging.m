//
//  PVLogging.m
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//

#import "PVLogging.h"
#import <sys/utsname.h>
#import "PVLogEntry.h"
#import <PVSupport/PVSupport-Swift.h>
//#import "NSData+HexEnc.h"
//#import "NSData+Base64.h"

    // The logging systems available
#import "PVCocoaLumberJackLogging.h"
#import "PVLogging.h"
@import CocoaLumberjack;
#if TARGET_OS_IOS || TARGET_OS_TV
@import UIKit;
#endif
NSString  * const ISO_TIMEZONE_UTC_FORMAT    = @"Z";
NSString  * const ISO_TIMEZONE_OFFSET_FORMAT = @"%+02d%02d";

#define VIRTUAL_METHOD \
@throw [NSException exceptionWithName:NSInternalInconsistencyException \
reason:[NSString stringWithFormat: \
@"This method should be overloaded : %s", __PRETTY_FUNCTION__] \
userInfo:nil];

    // This overrides all NSLog calls from 3rd party libraries. The linker
    // will cause this to be called instead of the system's NSLog
//void NSLog(NSString *format, ...) {
//    va_list args;
//    if(format) {
//        va_start(args, format);
//
//        NSString *line = [[NSString alloc] initWithFormat:format
//                                                arguments:args];
//        va_end(args);
//
//            // Some macro may need _cmd.
//            // Making one up here.
//        SEL _cmd = NSSelectorFromString(@"NSLog");
//        ILOG(line);
//    }
//}

#import <CocoaLumberjack/DDLogMacros.h>
#import <CocoaLumberjack/CocoaLumberjack.h>
#ifdef __cplusplus
extern "C" {
#endif
void PVLog(NSUInteger level, NSUInteger flag, const char* file, const char *function, int line, NSString* _Nonnull format, ...) {
	BOOL async = YES;
	if (flag == PVLogFlagError) {
		async = NO;
	}
	va_list args;
	va_start(args, format);
	[DDLog log : async
		 level : level
		  flag : flag
	   context : 0
		  file : file
	  function : function
		  line : line
		   tag : nil
		format : (format)
		   args: args];
	va_end(args);
}

#ifdef __cplusplus
}
#endif

@interface PVLogging  ()
@property (nonatomic, strong) id <PVLoggingEntity> loggingEntity;
@end

@implementation PVLogging
@dynamic historyString, htmlString;

    // Virtual methods. No defaults implimentation. You must override these in
    // subclasses
#pragma mark - Virtual Methods

- (NSArray*)logFilePaths {
    return self.loggingEntity.logFilePaths;
}

- (NSArray*)logFileInfos {
    return self.loggingEntity.logFileInfos;
}

- (void)flushLogs {
    [self.loggingEntity flushLogs];
}

#pragma mark -
#pragma mark Singleton methods

+(void) initialize {
    __PVLoggingStartupTime = [NSDate date];
}

+(instancetype)sharedInstance {
    static id sharedInstance = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[[self class] alloc] init];
    });

	return sharedInstance;
}

+ (void)logNSURLCacheUsage {
    const float mb2b = 1024*1024;

    NSURLCache *defaultCache    = [NSURLCache sharedURLCache];
    uint defaultCacheSizeMemory = (uint)defaultCache.memoryCapacity;
    uint defaultCacheSizeDisk   = (uint)defaultCache.diskCapacity;
    uint usedCacheMemory        = (uint)defaultCache.currentMemoryUsage;
    uint usedCacheDisk          = (uint)defaultCache.currentDiskUsage;
    ILOG(@"Current cache policy\n\tMemory: %2.2fMB (%2.2f) used\tDisk: %2.2fMB (%2.2f) used",
         defaultCacheSizeMemory/mb2b, usedCacheMemory/mb2b, defaultCacheSizeDisk/mb2b, usedCacheDisk/mb2b);
}

#pragma mark - Init
- (instancetype)init
{
    self = [super init];
    if (self) {
        _history   = [NSMutableArray new];
        _listeners = [NSMutableSet new];

#if LOGGING_SYSTEM == LOGGING_SYSTEM_COCOALUMBERJACK
        _loggingEntity = [PVCocoaLumberJackLogging new];
#else
#error Invalid setting for LOGGING_SYSTEM
#endif

        [self writeLocalInfo];
    }
    return self;
}

#pragma mark - Listeners
- (void)registerListner:(NSObject<PVLoggingEventProtocol> *)delegate {
    @synchronized(_listeners){
        [_listeners addObject:delegate];
    }
}

- (void)removeListner:(NSObject<PVLoggingEventProtocol> *)delegate {
    @synchronized(_listeners){
        [_listeners removeObject:delegate];
    }
}

- (void)notifyListeners {

    @synchronized(_listeners){
            // loop thru the listeners arry and notify the listeners
        for (NSObject<PVLoggingEventProtocol> *listener in _listeners) {
            [listener updateHistory:self];
        }
    }
}

#pragma mark - String
-(NSString*)historyString {

    NSMutableString *historyString = [NSMutableString new];

    for(NSObject *object in _history){
        if([object isKindOfClass:[PVLogEntry class]]){
            [historyString appendFormat:@"%@\n", [object description]];
        } else {
            [historyString appendFormat:@"%@\n", object];
        }
    }

    return historyString;
}

-(NSString*)htmlString {
    NSMutableString *historyString = [NSMutableString new];

    for(NSObject *object in _history){
        if([object isKindOfClass:[PVLogEntry class]]){
            [historyString appendFormat:@"%@\n<br>", [(PVLogEntry*)object htmlString]];
        } else {
            [historyString appendFormat:@"%@\n<br>", object];
        }
    }

    return historyString;
}

    //Gets the iOS version number
+ (NSInteger) systemVersionAsAnInteger{
    int index = 0;
    NSInteger version = 0;

    NSArray* digits = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
    NSEnumerator* enumer = [digits objectEnumerator];
    NSString* number;
    while (number = [enumer nextObject]) {
        if (index>2) {
            break;
        }
        NSInteger multipler = powf(100, 2-index);
        version += [number intValue]*multipler;
        index++;
    }
    return version;
}

/**
 This method is responsible for writing the device type, iOS version,
 and the App version.
 */
- (void)writeLocalInfo {
    struct utsname systemInfo;
    uname(&systemInfo);

	NSString *appName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    NSString *appId = [[NSBundle mainBundle] infoDictionary][@"CFBundleIdentifier"];
    NSString *buildVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
	NSString *appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];

	NSString *os = @(systemInfo.sysname);
	NSString *machine = @(systemInfo.machine);


	NSString *gitBranch = [[NSBundle mainBundle] infoDictionary][@"GitBranch"];
	NSString *gitTag = [[NSBundle mainBundle] infoDictionary][@"GitTag"];
	NSString *gitDate = [[NSBundle mainBundle] infoDictionary][@"GitDate"];


	NSString *systemName = [[UIDevice currentDevice] systemName];

    NSMutableString *info = [NSMutableString new];

    [info appendString:@"\n---------------- App Load ----------------------\n"];
    [info appendFormat:@"Load date: %@\n",[NSDate date]];
	[info appendFormat:@"App: %@\n",appName];
    [info appendFormat:@"System: %@ %@\n", os, machine];
	[info appendFormat:@"Device: %@\n", [UIDevice currentDevice].modelName];
    [info appendFormat:@"%@ Version: %@\n",systemName, [UIDevice currentDevice].systemVersion];
    [info appendFormat:@"App Id: %@\n",appId];
	[info appendFormat:@"App Version: %@\n",appVersion];
	[info appendFormat:@"Build #: %@\n",buildVersion];

	// Append git info if it exists
	if (gitBranch && gitBranch.length) {
		[info appendFormat:@"Git Branch: %@\n",gitBranch];
	}

	if (gitTag && gitTag.length) {
		[info appendFormat:@"Git Tag: %@\n",gitTag];
	}

	if (gitDate && gitDate.length) {
		[info appendFormat:@"Git Date: %@\n",gitDate];
	}

    [info appendString:@"------------------------------------------------"];

    ILOG(@"%@",info);
}

- (NSString *)newestFileLogContentsAsString {

    NSArray *logs = [self logFilePaths];

    if (!logs || logs.count == 0) {
        return @"NO logs";
    }

    NSString *path = logs[0];

    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {

        NSError *error;
        NSString *myText = [NSString stringWithContentsOfFile:path
                                                     encoding:NSUTF8StringEncoding
                                                        error:&error];
        if (!myText) {
            ELOG(@"%@", [error localizedDescription]);
            return nil;
        }

        return myText;
    } else {
        return [NSString stringWithFormat:@"No log %@", path];
    }
}

@end
