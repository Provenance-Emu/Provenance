//
//  PVLogging.h
//  PVSupport
//
//  Created by Mattiello, Joseph R on 1/27/14.
//  Copyright (c) 2014 Joe Mattiello. All rights reserved.

/*
 * There are four levels of logging: debug, info, error and file, and each can be enabled independently
 * via the LOGGING_LEVEL_DEBUG, LOGGING_LEVEL_INFO, LOGGING_LEVEL_ERROR and LOGGING_LEVEL_FILE switches
 * below, respectively. In addition, ALL logging can be enabled or disabled via the LOGGING_ENABLED switch below.
 *
 * To perform logging, use any of the following function calls in your code:
 *
 *	 DLOG(fmt, ...) – will print if LOGGING_LEVEL_DEBUG is set on.
 *	 ILOG(fmt, ...) – will print if LOGGING_LEVEL_INFO is set on.
 *	 ELOG(fmt, ...) – will print if LOGGING_LEVEL_ERROR is set on.
 *	 ILOG(fmt, ...) – will save to log file if LOGGING_LEVEL_FILE is set on.
 *
 * FLOG will use LOGGING_FILE_NAME for the name of the on device file.
 *
 * Each logging entry can optionally automatically include class, method and line information by
 * enabling the LOGGING_INCLUDE_CODE_LOCATION switch.
 *
 */

#import <Foundation/Foundation.h>

    // TODO :: Logging upgrades
/*
 1) Deal with memory warning, flush
 2) Maybe capture app crash and write
 3) Log converts, convert to HTML, XML ETC
 */

    // Set this switch to enable or disable ALL logging.
    // (DSwift - please do not disable loggging at this level - must remain enabled for production to get ELOGs, ILOGs, and FLOGs).
#ifndef LOGGING_ENABLED
#define LOGGING_ENABLED	1
#endif

#ifndef THROW_ON_ERROR
#define THROW_ON_ERROR 0
#endif

    // Set any or all of these switches to enable or disable logging at specific levels.
#ifndef LOGGING_LEVEL_VERBOSE
#define LOGGING_LEVEL_VERBOSE		0
#endif

#ifndef LOGGING_LEVEL_DEBUG
#define LOGGING_LEVEL_DEBUG		0
#endif

#ifndef LOGGING_LEVEL_WARN
#define LOGGING_LEVEL_WARN		1
#endif

#ifndef LOGGING_LEVEL_INFO
#define LOGGING_LEVEL_INFO		1
#endif

#ifndef LOGGING_LEVEL_ERROR
#define LOGGING_LEVEL_ERROR		1
#endif

#ifndef LOGGING_LEVEL_FILE
#define LOGGING_LEVEL_FILE		1
#endif

#define stackSize 4096

    // Set this switch to set whether or not to include class, method and line information in the log entries.
#ifndef LOGGING_INCLUDE_CODE_LOCATION
#define LOGGING_INCLUDE_CODE_LOCATION	1
#endif

    // Set this value to the name of the file used by FLOG.  It will reside in the Documents folder of the device.
#ifndef LOGGING_FILE_NAME
#define LOGGING_FILE_NAME       @"pvlogfile.txt"
#endif

    // Assist with logging BOOL types to NSString
#define BOOL_STRING(boolean) ((NSString*)(boolean ? @"YES" : @"NO"))

    // ***************** END OF USER SETTINGS ***************

#if !(defined(LOGGING_ENABLED) && LOGGING_ENABLED)
#undef LOGGING_LEVEL_VERBOSE
#undef LOGGING_LEVEL_DEBUG
#undef LOGGING_LEVEL_INFO
#undef LOGGING_LEVEL_WARN
#undef LOGGING_LEVEL_ERROR
#undef LOGGING_LEVEL_FILE
#endif

#define LOGGING_SYSTEM_COCOALUMBERJACK      1

#define LOGGING_SYSTEM                      LOGGING_SYSTEM_COCOALUMBERJACK

#if (LOGGING_SYSTEM == LOGGING_SYSTEM_COCOALUMBERJACK)

    // Set the log level for CocoaLumberJack. Set to all since we use our own
    // filters
    //#define LOG_LEVEL_DEF ddLogLevel
//#define DD_LEGACY_MARCROS 0
//@import CocoaLumberjack;
//#import <CocoaLumberjack/CocoaLumberjack.h>
//#import <CocoaLumberjack/DDLegacyMacros.h>

//#import <CocoaLumberjack/DDLogMacros.h>
//#import <CocoaLumberjack/CocoaLumberjack.h>
static int ddLogLevel = 0xFF; //DDLogLevelDebug;

#ifdef __cplusplus
extern "C" {
#endif
	void PVLog(NSUInteger level, NSUInteger flag, const char* _Nonnull file, const char * _Nonnull function, int line, NSString* _Nonnull format, ...);
#ifdef __cplusplus
}
#endif
// Enable all logging in debug builds
    // for Cocoalumberjack since it uses such good filtering
//#if defined(DEBUG)
//    #undef LOGGING_LEVEL_DEBUG
//    #define LOGGING_LEVEL_DEBUG 1
//#endif
typedef NS_OPTIONS(NSUInteger, PVLogFlag){
	/**
	 *  0...00001 PVLogFlagError
	 */
	PVLogFlagError      = (1 << 0),

	/**
	 *  0...00010 PVLogFlagWarning
	 */
	PVLogFlagWarning    = (1 << 1),

	/**
	 *  0...00100 PVLogFlagInfo
	 */
	PVLogFlagInfo       = (1 << 2),

	/**
	 *  0...01000 PVLogFlagDebug
	 */
	PVLogFlagDebug      = (1 << 3),

	/**
	 *  0...10000 PVLogFlagVerbose
	 */
	PVLogFlagVerbose    = (1 << 4)
};

#if defined(LOGGING_LEVEL_VERBOSE) && LOGGING_LEVEL_VERBOSE
#undef VLOG
#define VLOG(fmt, ...) \
PVLog(ddLogLevel, PVLogFlagVerbose, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__);
#else
#define VLOG(...)
#endif

#if defined(LOGGING_LEVEL_DEBUG) && LOGGING_LEVEL_DEBUG
#undef DLOG
#define DLOG(fmt, ...) \
PVLog(ddLogLevel, PVLogFlagDebug, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__);
// Fix legacy log lines
#define DLog(fmt,...) DLOG(fmt, ##__VA_ARGS__)
#else
#define DLOG(...)
#define DLog(...)
#endif

    // Info level logging
#if defined(LOGGING_LEVEL_INFO) && LOGGING_LEVEL_INFO
#undef ILOG
#define ILOG(fmt, ...) \
PVLog(ddLogLevel, PVLogFlagInfo, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__);
#else
#define ILOG(...)
#endif

    // Warning level logging
#if defined(LOGGING_LEVEL_WARN) && LOGGING_LEVEL_WARN
#undef WLOG
#define WLOG(fmt, ...) \
PVLog(ddLogLevel, PVLogFlagWarning, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__);
#else
#define WLOG(...)
#endif

#if THROW_ON_ASSERT
#define NAssert(fmt, ...) \
NSAssert(false, fmt, ##__VA_ARGS__)
#else
#define NAssert(...)
#endif

    // Error level logging
#if defined(LOGGING_LEVEL_ERROR) && LOGGING_LEVEL_ERROR
#undef ELOG
#define ELOG(fmt, ...) \
PVLog(ddLogLevel, PVLogFlagError, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__); \
NAssert(fmt, ##__VA_ARGS__)
#else
#define ELOG(...)
#endif
#endif

#define STUB( format, ...) \
do { \
NSString *message = [NSString stringWithFormat:format, ##__VA_ARGS__]; \
NSString *logMessage = [NSString stringWithFormat:@"STUB::%@", message]; \
WLOG(@"%@", logMessage); \
} while(0) \

NS_ASSUME_NONNULL_BEGIN
@class PVLogging;

@protocol PVLoggingEventProtocol <NSObject>
@required
- (void)updateHistory:(PVLogging *)sender;
@end

@protocol PVLoggingEntity <NSObject>
/**
 *  Obtain paths of any file logs
 *
 *  @return List of file paths, with newest as the first
 */
- (NSArray*)logFilePaths;

/**
 *  Array of info for the log files such as zie and modification date
 *
 *  @return Sorted list of info dicts, newest first
 */
- (NSArray*)logFileInfos;

/**
 *  Writes any async logs
 */
- (void)flushLogs;
@end

@interface PVLogging : NSObject

@property (strong, readonly)    NSDate          *startupTime;
@property (copy)                NSArray         *history;
@property (strong)              NSMutableSet    *listeners;
@property (readonly,nonatomic)  NSString        *historyString;
@property (readonly,nonatomic)  NSString        *htmlString;

/**
 *  Add a new listener for PVLogging events such as new entries
 *
 *  @param delegate Object to respsond to PVLoggingEventProtocol events
 */
- (void)registerListner:(NSObject<PVLoggingEventProtocol> *)delegate;
- (void)removeListner:(NSObject<PVLoggingEventProtocol> *)delegate;

#pragma mark Singleton functions
+ (PVLogging *)sharedInstance;
/**
 Get iOS version
 */
+ (NSInteger) systemVersionAsAnInteger;

/**
 *  Print out the state of NSURL disk and memory cache usage
 */
+ (void) logNSURLCacheUsage;

/**
 *  Convenience method to get the newest log file as a string
 *
 *  @return String of the newest log file
 */
- (NSString *)newestFileLogContentsAsString;

/**
 Write local information about the device to the file log
 */
-(void) writeLocalInfo;

/**
 *  Obtain paths of any file logs
 *
 *  @return List of file paths, with newest as the first
 */
- (NSArray*)logFilePaths;

/**
 *  Array of info for the log files such as zie and modification date
 *
 *  @return Sorted list of info dicts, newest first
 */
- (NSArray*)logFileInfos;

/**
 *  Writes any async logs
 */
- (void)flushLogs;

/**
 *  Notify listerners of log updates
 */
- (void)notifyListeners;
@end
NS_ASSUME_NONNULL_END
