//
//  DebugUtils.h
//  PVSupport
//
//  Created by James Addyman on 18/01/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#ifndef PVSupport_DebugUtils_h
#define PVSupport_DebugUtils_h

#import <CocoaLumberjack/DDLog.h>

//MARK: Strong/Weak
#define MAKEWEAK(x)\
__weak __typeof(x)weak##x = x

#define MAKESTRONG(x)\
__strong __typeof(weak##x) strong##x = weak##x;

#define MAKESTRONG_RETURN_IF_NIL(x)\
if (weak##x == nil) return; \
__strong __typeof(weak##x) strong##x = weak##x;


//MARK: System Version
#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

// MARK: BOOLs
#define BOOL_TOGGLE(x) \
x ^= true

// MARK: X-Macros
#define QUOTE(...) @#__VA_ARGS__

//MARK: Threading

#define FORCEMAIN(x)                      \
if (![NSThread isMainThread]) {           \
	[self performSelectorOnMainThread:_cmd  \
	withObject:x   \
	waitUntilDone:YES]; \
	return;                                 \
}
#define PVAssertMainThread \
NSAssert([NSThread isMainThread], @"Not main thread");

// MARK: String

#define PVStringF( s, ... ) [NSString stringWithFormat:(s), ##__VA_ARGS__]

//MARK: Likely
#define UNLIKELY(n) __builtin_expect((n) != 0, 0)
#define LIKELY(n) __builtin_expect((n) != 0, 1)

#endif

//MARK: Direct OBJC

// Direct method and property calls with Xcode 12 and above.
#if defined(__IPHONE_14_0) || defined(__MAC_10_16) || defined(__TVOS_14_0) || defined(__WATCHOS_7_0)
#define PV_OBJC_DIRECT_MEMBERS __attribute__((objc_direct_members))
#define PV_OBJC_DIRECT __attribute__((objc_direct))
#define PV_DIRECT ,direct
#else
#define PV_OBJC_DIRECT_MEMBERS
#define PV_OBJC_DIRECT
#define PV_DIRECT
#endif

#define VISIBLE_DEFAULT __attribute__((visibility("default")))

#define PVCORE VISIBLE_DEFAULT PV_OBJC_DIRECT_MEMBERS

// MARK: - Logging
/*
 * There are four levels of logging: debug, info, error and file, and each can be enabled independently
 * via the LOGGING_LEVEL_DEBUG, LOGGING_LEVEL_INFO, LOGGING_LEVEL_ERROR and LOGGING_LEVEL_FILE switches
 * below, respectively. In addition, ALL logging can be enabled or disabled via the LOGGING_ENABLED switch below.
 *
 * To perform logging, use any of the following function calls in your code:
 *
 *     DLOG(fmt, ...) – will print if LOGGING_LEVEL_DEBUG is set on.
 *     ILOG(fmt, ...) – will print if LOGGING_LEVEL_INFO is set on.
 *     ELOG(fmt, ...) – will print if LOGGING_LEVEL_ERROR is set on.
 *     ILOG(fmt, ...) – will save to log file if LOGGING_LEVEL_FILE is set on.
 *
 * FLOG will use LOGGING_FILE_NAME for the name of the on device file.
 *
 * Each logging entry can optionally automatically include class, method and line information by
 * enabling the LOGGING_INCLUDE_CODE_LOCATION switch.
 *
 */

    // TODO :: Logging upgrades
/*
 1) Deal with memory warning, flush
 2) Maybe capture app crash and write
 3) Log converts, convert to HTML, XML ETC
 */

    // Set this switch to enable or disable ALL logging.
    // (DSwift - please do not disable loggging at this level - must remain enabled for production to get ELOGs, ILOGs, and FLOGs).
#ifndef LOGGING_ENABLED
#define LOGGING_ENABLED    1
#endif

#ifndef THROW_ON_ERROR
#define THROW_ON_ERROR 0
#endif

    // Set any or all of these switches to enable or disable logging at specific levels.
#ifndef LOGGING_LEVEL_VERBOSE
#define LOGGING_LEVEL_VERBOSE        0
#endif

#ifndef LOGGING_LEVEL_DEBUG
#define LOGGING_LEVEL_DEBUG        0
#endif

#ifndef LOGGING_LEVEL_WARN
#define LOGGING_LEVEL_WARN        1
#endif

#ifndef LOGGING_LEVEL_INFO
#define LOGGING_LEVEL_INFO        1
#endif

#ifndef LOGGING_LEVEL_ERROR
#define LOGGING_LEVEL_ERROR        1
#endif

#ifndef LOGGING_LEVEL_FILE
#define LOGGING_LEVEL_FILE        1
#endif

#define LOGGING_STACK_SIZE 4096

    // Set this switch to set whether or not to include class, method and line information in the log entries.
#ifndef LOGGING_INCLUDE_CODE_LOCATION
#define LOGGING_INCLUDE_CODE_LOCATION    1
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
static DDLogLevel ddLogLevel = DDLogLevelDebug; //DDLogLevelDebug;

//#ifdef __cplusplus
//extern "C" {
//#endif
//    void PVLog(NSUInteger level, NSUInteger flag, const char* _Nonnull file, const char * _Nonnull function, int line, NSString* _Nonnull format, ...);
//#ifdef __cplusplus
//}
//#endif

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

#ifdef __cplusplus
extern "C" {
#endif
static void PVLog(DDLogLevel level, NSUInteger flag, const char* _Nonnull file, const char * _Nonnull function, int line, NSString* _Nonnull format, ...) {
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


#ifndef _OEGeometry_
#define _OEGeometry_
typedef struct OEIntPoint {
    int x;
    int y;
} OEIntPoint;

typedef struct OEIntSize {
    int width;
    int height;
} OEIntSize;

typedef struct OEIntRect {
    OEIntPoint origin;
    OEIntSize size;
} OEIntRect;

static inline OEIntPoint OEIntPointMake(int x, int y)
{
    return (OEIntPoint){ x, y };
}

static inline OEIntSize OEIntSizeMake(int width, int height)
{
    return (OEIntSize){ width, height };
}

static inline OEIntRect OEIntRectMake(int x, int y, int width, int height)
{
    return (OEIntRect){ (OEIntPoint){ x, y }, (OEIntSize){ width, height } };
}

static inline BOOL OEIntPointEqualToPoint(OEIntPoint point1, OEIntPoint point2)
{
    return point1.x == point2.x && point1.y == point2.y;
}

static inline BOOL OEIntSizeEqualToSize(OEIntSize size1, OEIntSize size2)
{
    return size1.width == size2.width && size1.height == size2.height;
}

static inline BOOL OEIntRectEqualToRect(OEIntRect rect1, OEIntRect rect2)
{
    return OEIntPointEqualToPoint(rect1.origin, rect2.origin) && OEIntSizeEqualToSize(rect1.size, rect2.size);
}

static inline BOOL OEIntSizeIsEmpty(OEIntSize size)
{
    return size.width == 0 || size.height == 0;
}

static inline BOOL OEIntRectIsEmpty(OEIntRect rect)
{
    return OEIntSizeIsEmpty(rect.size);
}

static inline CGSize CGSizeFromOEIntSize(OEIntSize size)
{
    return CGSizeMake(size.width, size.height);
}

static inline NSString* __nonnull NSStringFromOEIntPoint(OEIntPoint p)
{
    return [NSString stringWithFormat:@"{ %d, %d }", p.x, p.y];
}

static inline NSString * __nonnull NSStringFromOEIntSize(OEIntSize s)
{
    return [NSString stringWithFormat:@"{ %d, %d }", s.width, s.height];
}

static inline NSString * __nonnull NSStringFromOEIntRect(OEIntRect r)
{
    return [NSString stringWithFormat:@"{ %@, %@ }", NSStringFromOEIntPoint(r.origin), NSStringFromOEIntSize(r.size)];
}

static inline CGSize OEScaleSize(CGSize size, CGFloat factor)
{
    return (CGSize){size.width*factor, size.height*factor};
}

static inline CGSize OERoundSize(CGSize size)
{
    return (CGSize){roundf(size.width), roundf(size.height)};
}

static inline BOOL CGPointInTriangle(CGPoint p, CGPoint A, CGPoint B, CGPoint C)
{
    CGFloat d = (B.y-C.y) * (A.x-C.x) + (C.x - B.x) * (A.y - C.y);
    CGFloat a = ((B.y - C.y)*(p.x - C.x) + (C.x - B.x)*(p.y - C.y)) / d;
    CGFloat b = ((C.y - A.y)*(p.x - C.x) + (A.x - C.x)*(p.y - C.y)) / d;
    CGFloat c = 1 - a - b;

    return 0 <= a && a <= 1 && 0 <= b && b <= 1 && 0 <= c && c <= 1;
}
#endif

