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
    va_list args;
    va_start(args, format);
    // TODO: Call our swift code instead
    PVLogEntry* logEntry = [[PVLogEntry alloc] initWithMessage:@""];
    //     let logEntry = PVLogEntry(message: message(), level: level, file: file, function: function, lineNumber: "\(line)")
    [PVLogging.sharedInstance add:logEntry];

//    [DDLog log:async
//         level:level
//          flag:flag
//       context:0
//          file:file
//      function:function
//          line:line
//           tag:nil
//        format:(format)
//          args:args];
    
    va_end(args);
}
