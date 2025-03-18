//#import <CocoaLumberjack/DDLog.h>
@import PVLogging;
#import <Foundation/Foundation.h>
#import "PVLoggingObjC.h"

#undef ELOG
#undef WLOG
#undef ILOG
#undef VLOG
#undef DLOG

OBJC_EXPORT
void PVLog(NSUInteger level, NSUInteger flag, const char *file,
           const char *function, int line, NSString *_Nonnull format, ...) {
    // Format the string with variable arguments
    va_list args;
    va_start(args, format);
    NSString *formattedMessage = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    // Convert C strings to NSString
    NSString *fileString = file ? [NSString stringWithUTF8String:file] : @"";
    NSString *functionString = function ? [NSString stringWithUTF8String:function] : @"";
    
    // Create log entry
    PVLogEntry* logEntry = [[PVLogEntry alloc] initWithMessage:formattedMessage];
    [PVLogging.sharedInstance add:logEntry];
    
    // Call the appropriate Swift logging method based on log level
    switch (flag) {
        case PVLogFlagVerbose:
            [PVLoggingObjC Vlog:formattedMessage file:fileString function:functionString line:line];
            break;
            
        case PVLogFlagDebug:
            [PVLoggingObjC Dlog:formattedMessage file:fileString function:functionString line:line];
            break;
            
        case PVLogFlagInfo:
            [PVLoggingObjC Ilog:formattedMessage file:fileString function:functionString line:line];
            break;
            
        case PVLogFlagWarning:
            [PVLoggingObjC Wlog:formattedMessage file:fileString function:functionString line:line];
            break;
            
        case PVLogFlagError:
            [PVLoggingObjC Elog:formattedMessage file:fileString function:functionString line:line];
            break;
            
        default:
            // Default to debug log if level is unknown
            [PVLoggingObjC Dlog:formattedMessage file:fileString function:functionString line:line];
            break;
    }
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
