//#import <CocoaLumberjack/DDLog.h>
@import PVLogging;
#import <Foundation/Foundation.h>
#import "PVLoggingObjC.h"

OBJC_EXPORT
void PVLog(NSUInteger level, NSUInteger flag, const char *file,
           const char *function, int line, NSString *_Nonnull format, ...) {
    BOOL async = YES;
    if (flag == PVLogFlagError) {
        async = NO;
    }

    /// Format the message with variable arguments
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    /// Convert flag to PVLogLevel
    PVLogLevel logLevel;
    switch (flag) {
        case PVLogFlagError:
            logLevel = PVLogLevelError;
            break;
        case PVLogFlagWarning:
            logLevel = PVLogLevelWarn;
            break;
        case PVLogFlagInfo:
            logLevel = PVLogLevelInfo;
            break;
        case PVLogFlagDebug:
            logLevel = PVLogLevelDebug;
            break;
        default:
            logLevel = PVLogLevelInfo;
            break;
    }

    /// Create log entry with all required information
    PVLogEntry* logEntry = [[PVLogEntry alloc] initWithMessage:message
                                                        level:logLevel
                                                         file:[NSString stringWithUTF8String:file]
                                                    function:[NSString stringWithUTF8String:function]
                                                 lineNumber:[NSString stringWithFormat:@"%d", line]];

    /// Add to logging system
    [PVLogging.sharedInstance add:logEntry];
}

// ClassFinder.m
#import <objc/runtime.h>

@implementation ClassFinderObjC

+ (NSArray<Class> *)findSubclassesOf:(Class)parentClass {
    NSMutableArray<Class> *result = [NSMutableArray array];
    unsigned int count = 0;
    Class *classes = NULL;
    
    @try {
        classes = objc_copyClassList(&count);
        for (unsigned int i = 0; i < count; i++) {
            Class superClass = class_getSuperclass(classes[i]);
            if (superClass == parentClass) {
                [result addObject:classes[i]];
            }
        }
    } @finally {
        if (classes) {
            free(classes);
        }
    }
    
    return [result copy];
}

@end
