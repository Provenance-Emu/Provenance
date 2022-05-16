////
////  PVLogging.h
////  PVSupport
////
////  Created by Mattiello, Joseph R on 1/27/14.
////  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//
///*
// * There are four levels of logging: debug, info, error and file, and each can be enabled independently
// * via the LOGGING_LEVEL_DEBUG, LOGGING_LEVEL_INFO, LOGGING_LEVEL_ERROR and LOGGING_LEVEL_FILE switches
// * below, respectively. In addition, ALL logging can be enabled or disabled via the LOGGING_ENABLED switch below.
// *
// * To perform logging, use any of the following function calls in your code:
// *
// *	 DLOG(fmt, ...) – will print if LOGGING_LEVEL_DEBUG is set on.
// *	 ILOG(fmt, ...) – will print if LOGGING_LEVEL_INFO is set on.
// *	 ELOG(fmt, ...) – will print if LOGGING_LEVEL_ERROR is set on.
// *	 ILOG(fmt, ...) – will save to log file if LOGGING_LEVEL_FILE is set on.
// *
// * FLOG will use LOGGING_FILE_NAME for the name of the on device file.
// *
// * Each logging entry can optionally automatically include class, method and line information by
// * enabling the LOGGING_INCLUDE_CODE_LOCATION switch.
// *
// */
//
//#import <Foundation/Foundation.h>
//
//  // TODO :: Logging upgrades
///*
// 1) Deal with memory warning, flush
// 2) Maybe capture app crash and write
// 3) Log converts, convert to HTML, XML ETC
// */
//
//  // Set this switch to enable or disable ALL logging.
//  // (DSwift - please do not disable loggging at this level - must remain enabled for production to get ELOGs, ILOGs, and FLOGs).
//#ifndef LOGGING_ENABLED
//#define LOGGING_ENABLED	1
//#endif
//
//#ifndef THROW_ON_ERROR
//#define THROW_ON_ERROR 0
//#endif
//
//  // Set any or all of these switches to enable or disable logging at specific levels.
//#ifndef LOGGING_LEVEL_VERBOSE
//#define LOGGING_LEVEL_VERBOSE		0
//#endif
//
//#ifndef LOGGING_LEVEL_DEBUG
//#define LOGGING_LEVEL_DEBUG		0
//#endif
//
//#ifndef LOGGING_LEVEL_WARN
//#define LOGGING_LEVEL_WARN		1
//#endif
//
//#ifndef LOGGING_LEVEL_INFO
//#define LOGGING_LEVEL_INFO		1
//#endif
//
//#ifndef LOGGING_LEVEL_ERROR
//#define LOGGING_LEVEL_ERROR		1
//#endif
//
//#ifndef LOGGING_LEVEL_FILE
//#define LOGGING_LEVEL_FILE		1
//#endif
//
//#define LOGGING_STACK_SIZE 4096
//
//  // Set this switch to set whether or not to include class, method and line information in the log entries.
//#ifndef LOGGING_INCLUDE_CODE_LOCATION
//#define LOGGING_INCLUDE_CODE_LOCATION	1
//#endif
//
//  // Set this value to the name of the file used by FLOG.  It will reside in the Documents folder of the device.
//#ifndef LOGGING_FILE_NAME
//#define LOGGING_FILE_NAME       @"pvlogfile.txt"
//#endif
//
//  // Assist with logging BOOL types to NSString
//#define BOOL_STRING(boolean) ((NSString*)(boolean ? @"YES" : @"NO"))
//
//  // ***************** END OF USER SETTINGS ***************
//
//#if !(defined(LOGGING_ENABLED) && LOGGING_ENABLED)
//#undef LOGGING_LEVEL_VERBOSE
//#undef LOGGING_LEVEL_DEBUG
//#undef LOGGING_LEVEL_INFO
//#undef LOGGING_LEVEL_WARN
//#undef LOGGING_LEVEL_ERROR
//#undef LOGGING_LEVEL_FILE
//#endif
//
//#define LOGGING_SYSTEM_COCOALUMBERJACK      1
//
//#define LOGGING_SYSTEM                      LOGGING_SYSTEM_COCOALUMBERJACK
//
//#if (LOGGING_SYSTEM == LOGGING_SYSTEM_COCOALUMBERJACK)
//
//  // Set the log level for CocoaLumberJack. Set to all since we use our own
//  // filters
//  //#define LOG_LEVEL_DEF ddLogLevel
////#define DD_LEGACY_MARCROS 0
////@import CocoaLumberjack;
////#import <CocoaLumberjack/CocoaLumberjack.h>
////#import <CocoaLumberjack/DDLegacyMacros.h>
//
////#import <CocoaLumberjack/DDLogMacros.h>
////#import <CocoaLumberjack/CocoaLumberjack.h>
//static int ddLogLevel = 0xFF; //DDLogLevelDebug;
//
//#ifdef __cplusplus
//extern "C" {
//#endif
//	void PVLog(NSUInteger level, NSUInteger flag, const char* _Nonnull file, const char * _Nonnull function, int line, NSString* _Nonnull format, ...);
//#ifdef __cplusplus
//}
//#endif
//// Enable all logging in debug builds
//  // for Cocoalumberjack since it uses such good filtering
////#if defined(DEBUG)
////    #undef LOGGING_LEVEL_DEBUG
////    #define LOGGING_LEVEL_DEBUG 1
////#endif
//typedef NS_OPTIONS(NSUInteger, PVLogFlag){
//	/**
//	 *  0...00001 PVLogFlagError
//	 */
//	PVLogFlagError      = (1 << 0),
//
//	/**
//	 *  0...00010 PVLogFlagWarning
//	 */
//	PVLogFlagWarning    = (1 << 1),
//
//	/**
//	 *  0...00100 PVLogFlagInfo
//	 */
//	PVLogFlagInfo       = (1 << 2),
//
//	/**
//	 *  0...01000 PVLogFlagDebug
//	 */
//	PVLogFlagDebug      = (1 << 3),
//
//	/**
//	 *  0...10000 PVLogFlagVerbose
//	 */
//	PVLogFlagVerbose    = (1 << 4)
//};
//
//#if defined(LOGGING_LEVEL_VERBOSE) && LOGGING_LEVEL_VERBOSE
//#undef VLOG
//#define VLOG(fmt, ...) \
//PVLog(ddLogLevel, PVLogFlagVerbose, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__);
//#else
//#define VLOG(...)
//#endif
//
//#if defined(LOGGING_LEVEL_DEBUG) && LOGGING_LEVEL_DEBUG
//#undef DLOG
//#define DLOG(fmt, ...) \
//PVLog(ddLogLevel, PVLogFlagDebug, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__);
//// Fix legacy log lines
//#define DLog(fmt,...) DLOG(fmt, ##__VA_ARGS__)
//#else
//#define DLOG(...)
//#define DLog(...)
//#endif
//
//  // Info level logging
//#if defined(LOGGING_LEVEL_INFO) && LOGGING_LEVEL_INFO
//#undef ILOG
//#define ILOG(fmt, ...) \
//PVLog(ddLogLevel, PVLogFlagInfo, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__);
//#else
//#define ILOG(...)
//#endif
//
//  // Warning level logging
//#if defined(LOGGING_LEVEL_WARN) && LOGGING_LEVEL_WARN
//#undef WLOG
//#define WLOG(fmt, ...) \
//PVLog(ddLogLevel, PVLogFlagWarning, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__);
//#else
//#define WLOG(...)
//#endif
//
//#if THROW_ON_ASSERT
//#define NAssert(fmt, ...) \
//NSAssert(false, fmt, ##__VA_ARGS__)
//#else
//#define NAssert(...)
//#endif
//
//  // Error level logging
//#if defined(LOGGING_LEVEL_ERROR) && LOGGING_LEVEL_ERROR
//#undef ELOG
//#define ELOG(fmt, ...) \
//PVLog(ddLogLevel, PVLogFlagError, __FILE__, __PRETTY_FUNCTION__, __LINE__, fmt, ##__VA_ARGS__); \
//NAssert(fmt, ##__VA_ARGS__)
//#else
//#define ELOG(...)
//#endif
//#endif
//
//#define STUB( format, ...) \
//do { \
//NSString *message = [NSString stringWithFormat:format, ##__VA_ARGS__]; \
//NSString *logMessage = [NSString stringWithFormat:@"STUB::%@", message]; \
//WLOG(@"%@", logMessage); \
//} while(0) \
//
//NS_ASSUME_NONNULL_BEGIN
//@class PVLogging;
//
//@protocol PVLoggingEventProtocol <NSObject>
//@required
//- (void)updateHistory:(PVLogging *)sender;
//@end
//
//@protocol PVLoggingEntity <NSObject>
///**
// *  Obtain paths of any file logs
// *
// *  @return List of file paths, with newest as the first
// */
//- (NSArray<NSString*>* __nullable)logFilePaths;
//
///**
// *  Writes any async logs
// */
//- (void)flushLogs;
//
//@optional
///**
// *  Array of info for the log files such as zie and modification date
// *
// *  @return Sorted list of info dicts, newest first
// */
//- (NSArray* __nullable)logFileInfos;
//@end
//
//@interface PVLogging : NSObject
//
//@property (strong, readonly)    NSDate          *startupTime;
//@property (copy)                NSArray         *history;
//@property (strong)              NSMutableSet    *listeners;
//@property (readonly,nonatomic)  NSString        *historyString;
//@property (readonly,nonatomic)  NSString        *htmlString;
//
///**
// *  Add a new listener for PVLogging events such as new entries
// *
// *  @param delegate Object to respsond to PVLoggingEventProtocol events
// */
//- (void)registerListner:(NSObject<PVLoggingEventProtocol> *)delegate;
//- (void)removeListner:(NSObject<PVLoggingEventProtocol> *)delegate;
//
//#pragma mark Singleton functions
//+ (PVLogging *)sharedInstance;
///**
// Get iOS version
// */
//+ (NSInteger) systemVersionAsAnInteger;
//
///**
// *  Print out the state of NSURL disk and memory cache usage
// */
//+ (void) logNSURLCacheUsage;
//
///**
// *  Convenience method to get the newest log file as a string
// *
// *  @return String of the newest log file
// */
//- (NSString *)newestFileLogContentsAsString;
//
///**
// Write local information about the device to the file log
// */
//-(void) writeLocalInfo;
//
///**
// *  Obtain paths of any file logs
// *
// *  @return List of file paths, with newest as the first
// */
//- (NSArray*)logFilePaths;
//
///**
// *  Array of info for the log files such as zie and modification date
// *
// *  @return Sorted list of info dicts, newest first
// */
//- (NSArray*)logFileInfos;
//
///**
// *  Writes any async logs
// */
//- (void)flushLogs;
//
///**
// *  Notify listerners of log updates
// */
//- (void)notifyListeners;
//@end
//NS_ASSUME_NONNULL_END
//
//  //
//  //  PVLogging.m
//  //  PVSupport
//  //
//  //  Created by Mattiello, Joseph R on 1/27/14.
//  //  Copyright (c) 2014 Joe Mattiello. All rights reserved.
//  //
//  
//  #import "PVLogging.h"
//  #import <sys/utsname.h>
//  #import "PVLogEntry.h"
//  
//#if SWIFT_PACKAGE
//  @import Foundation;
//#else
//  #import <PVSupport/PVSupport-Swift.h>
//#endif
//  
//  //#import "NSData+HexEnc.h"
//  //#import "NSData+Base64.h"
//  
//  // The logging systems available
//  #import "PVLogging.h"
//  @import CocoaLumberjack;
//  
//#if TARGET_OS_IOS || TARGET_OS_TV
//  @import UIKit;
//#endif
//  NSString  * const ISO_TIMEZONE_UTC_FORMAT    = @"Z";
//  NSString  * const ISO_TIMEZONE_OFFSET_FORMAT = @"%+02d%02d";
//  
//  #define VIRTUAL_METHOD \
//  @throw [NSException exceptionWithName:NSInternalInconsistencyException \
//      reason:[NSString stringWithFormat: \
//          @"This method should be overloaded : %s", __PRETTY_FUNCTION__] \
//      userInfo:nil];
//  
//  // This overrides all NSLog calls from 3rd party libraries. The linker
//  // will cause this to be called instead of the system's NSLog
//  //void NSLog(NSString *format, ...) {
//  //    va_list args;
//  //    if(format) {
//  //        va_start(args, format);
//  //
//  //        NSString *line = [[NSString alloc] initWithFormat:format
//  //                                                arguments:args];
//  //        va_end(args);
//  //
//  //            // Some macro may need _cmd.
//  //            // Making one up here.
//  //        SEL _cmd = NSSelectorFromString(@"NSLog");
//  //        ILOG(line);
//  //    }
//  //}
//  
//#ifdef __cplusplus
//  extern "C" {
//      #endif
//      void PVLog(NSUInteger level, NSUInteger flag, const char* file, const char *function, int line, NSString* _Nonnull format, ...) {
//          BOOL async = YES;
//          if (flag == PVLogFlagError) {
//              async = NO;
//          }
//          va_list args;
//          va_start(args, format);
//          [DDLog log : async
//              level : level
//              flag : flag
//              context : 0
//              file : file
//              function : function
//              line : line
//              tag : nil
//              format : (format)
//              args: args];
//          va_end(args);
//      }
//      
//#ifdef __cplusplus
//      }
//#endif
//      
//      @interface PVLogging  ()
//      @property (nonatomic, strong) id <PVLoggingEntity> loggingEntity;
//      @end
//      
//      @implementation PVLogging
//      @dynamic historyString, htmlString;
//      
//      // Virtual methods. No defaults implimentation. You must override these in
//      // subclasses
//      #pragma mark - Virtual Methods
//      
//      - (NSArray*)logFilePaths {
//          return self.loggingEntity.logFilePaths;
//      }
//      
//      - (NSArray*)logFileInfos {
//          return self.loggingEntity.logFileInfos;
//      }
//      
//      - (void)flushLogs {
//          [self.loggingEntity flushLogs];
//      }
//      
//      #pragma mark -
//      #pragma mark Singleton methods
//      
//      +(void) initialize {
//          __PVLoggingStartupTime = [NSDate date];
//      }
//      
//      +(instancetype)sharedInstance {
//          static id sharedInstance = NULL;
//          static dispatch_once_t onceToken;
//          dispatch_once(&onceToken, ^{
//              sharedInstance = [[[self class] alloc] init];
//          });
//          
//          return sharedInstance;
//      }
//      
//      + (void)logNSURLCacheUsage {
//          const float mb2b = 1024*1024;
//          
//          NSURLCache *defaultCache    = [NSURLCache sharedURLCache];
//          uint defaultCacheSizeMemory = (uint)defaultCache.memoryCapacity;
//          uint defaultCacheSizeDisk   = (uint)defaultCache.diskCapacity;
//          uint usedCacheMemory        = (uint)defaultCache.currentMemoryUsage;
//          uint usedCacheDisk          = (uint)defaultCache.currentDiskUsage;
//          ILOG(@"Current cache policy\n\tMemory: %2.2fMB (%2.2f) used\tDisk: %2.2fMB (%2.2f) used",
//              defaultCacheSizeMemory/mb2b, usedCacheMemory/mb2b, defaultCacheSizeDisk/mb2b, usedCacheDisk/mb2b);
//      }
//      
//      #pragma mark - Init
//      - (instancetype)init
//      {
//          self = [super init];
//          if (self) {
//              _history   = [NSMutableArray new];
//              _listeners = [NSMutableSet new];
//              
//#if LOGGING_SYSTEM == LOGGING_SYSTEM_COCOALUMBERJACK
//              //        _loggingEntity = [PVCocoaLumberJackLogging new];
//#else
//              #error Invalid setting for LOGGING_SYSTEM
//#endif
//              
//              [self writeLocalInfo];
//          }
//          return self;
//      }
//      
//      #pragma mark - Listeners
//      - (void)registerListner:(NSObject<PVLoggingEventProtocol> *)delegate {
//          @synchronized(_listeners){
//              [_listeners addObject:delegate];
//          }
//      }
//      
//      - (void)removeListner:(NSObject<PVLoggingEventProtocol> *)delegate {
//          @synchronized(_listeners){
//              [_listeners removeObject:delegate];
//          }
//      }
//      
//      - (void)notifyListeners {
//          
//          @synchronized(_listeners){
//              // loop thru the listeners arry and notify the listeners
//              for (NSObject<PVLoggingEventProtocol> *listener in _listeners) {
//                  [listener updateHistory:self];
//              }
//          }
//      }
//      
//      #pragma mark - String
//      -(NSString*)historyString {
//          
//          NSMutableString *historyString = [NSMutableString new];
//          
//          for(NSObject *object in _history){
//              if([object isKindOfClass:[PVLogEntry class]]){
//                  [historyString appendFormat:@"%@\n", [object description]];
//              } else {
//                  [historyString appendFormat:@"%@\n", object];
//              }
//          }
//          
//          return historyString;
//      }
//      
//      -(NSString*)htmlString {
//          NSMutableString *historyString = [NSMutableString new];
//          
//          for(NSObject *object in _history){
//              if([object isKindOfClass:[PVLogEntry class]]){
//                  [historyString appendFormat:@"%@\n<br>", [(PVLogEntry*)object htmlString]];
//              } else {
//                  [historyString appendFormat:@"%@\n<br>", object];
//              }
//          }
//          
//          return historyString;
//      }
//      
//      //Gets the iOS version number
//      + (NSInteger) systemVersionAsAnInteger{
//          int index = 0;
//          NSInteger version = 0;
//          
//          NSArray* digits = [[UIDevice currentDevice].systemVersion componentsSeparatedByString:@"."];
//          NSEnumerator* enumer = [digits objectEnumerator];
//          NSString* number;
//          while (number = [enumer nextObject]) {
//              if (index>2) {
//                  break;
//              }
//              NSInteger multipler = powf(100, 2-index);
//              version += [number intValue]*multipler;
//              index++;
//          }
//          return version;
//      }
//      
//      /**
//      This method is responsible for writing the device type, iOS version,
//      and the App version.
//      */
//      - (void)writeLocalInfo {
//          struct utsname systemInfo;
//          uname(&systemInfo);
//          
//          NSString *appName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
//          NSString *appId = [[NSBundle mainBundle] infoDictionary][@"CFBundleIdentifier"];
//          NSString *buildVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
//          NSString *appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
//          
//          NSString *os = @(systemInfo.sysname);
//          NSString *machine = @(systemInfo.machine);
//          
//          
//          NSString *gitBranch = [[NSBundle mainBundle] infoDictionary][@"GitBranch"];
//          NSString *gitTag = [[NSBundle mainBundle] infoDictionary][@"GitTag"];
//          NSString *gitDate = [[NSBundle mainBundle] infoDictionary][@"GitDate"];
//          
//          
//          NSString *systemName = [[UIDevice currentDevice] systemName];
//          
//          NSMutableString *info = [NSMutableString new];
//          
//          [info appendString:@"\n---------------- App Load ----------------------\n"];
//          [info appendFormat:@"Load date: %@\n",[NSDate date]];
//          [info appendFormat:@"App: %@\n",appName];
//          [info appendFormat:@"System: %@ %@\n", os, machine];
//          //	[info appendFormat:@"Device: %@\n", [UIDevice currentDevice].modelName];
//          [info appendFormat:@"%@ Version: %@\n",systemName, [UIDevice currentDevice].systemVersion];
//          [info appendFormat:@"App Id: %@\n",appId];
//          [info appendFormat:@"App Version: %@\n",appVersion];
//          [info appendFormat:@"Build #: %@\n",buildVersion];
//          
//          // Append git info if it exists
//          if (gitBranch && gitBranch.length) {
//              [info appendFormat:@"Git Branch: %@\n",gitBranch];
//          }
//          
//          if (gitTag && gitTag.length) {
//              [info appendFormat:@"Git Tag: %@\n",gitTag];
//          }
//          
//          if (gitDate && gitDate.length) {
//              [info appendFormat:@"Git Date: %@\n",gitDate];
//          }
//          
//          [info appendString:@"------------------------------------------------"];
//          
//          ILOG(@"%@",info);
//      }
//      
//      - (NSString *)newestFileLogContentsAsString {
//          
//          NSArray *logs = [self logFilePaths];
//          
//          if (!logs || logs.count == 0) {
//              return @"NO logs";
//          }
//          
//          NSString *path = logs[0];
//          
//          if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
//              
//              NSError *error;
//              NSString *myText = [NSString stringWithContentsOfFile:path
//                  encoding:NSUTF8StringEncoding
//                  error:&error];
//              if (!myText) {
//                  ELOG(@"%@", [error localizedDescription]);
//                  return @"";
//              }
//              
//              return myText;
//          } else {
//              return [NSString stringWithFormat:@"No log %@", path];
//          }
//      }
//      
//      @end