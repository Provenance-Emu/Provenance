//#import <CocoaLumberjack/DDLog.h>
@import PVLogging;
#import <Foundation/Foundation.h>
#import "PVLoggingObjC.h"

OBJC_EXPORT
void PVLog(NSUInteger level, NSUInteger flag, const char *file,
           const char *function, int line, NSString *_Nonnull format, ...) {

    va_list args;
    va_start(args, format);
    
    NSString *logMessage = [[NSString alloc] initWithFormat:format arguments:args];
    NSString *fileString = [NSString stringWithCString:file];
    NSString *functionString = [NSString stringWithCString:function];

    switch (level) {
        case PVLogFlagVerbose:
            [PVLogWrapper objclog:logMessage level:OS_LOG_TYPE_DEFAULT file:fileString function:functionString line:line];
            break;
        case PVLogFlagDebug:
            [PVLogWrapper objclog:logMessage level:OS_LOG_TYPE_DEBUG file:fileString function:functionString line:line];
            break;
        case PVLogFlagInfo:
            [PVLogWrapper objclog:logMessage level:OS_LOG_TYPE_INFO file:fileString function:functionString line:line];
            break;
        case PVLogFlagWarning:
            [PVLogWrapper objclog:logMessage level:OS_LOG_TYPE_INFO file:fileString function:functionString line:line];
            break;
        case PVLogFlagError:
            [PVLogWrapper objclog:logMessage level:OS_LOG_TYPE_ERROR file:fileString function:functionString line:line];
            break;
        default:
            [PVLogWrapper objclog:logMessage level:OS_LOG_TYPE_DEFAULT file:fileString function:functionString line:line];
            break;
    }
    
    va_end(args);
}
