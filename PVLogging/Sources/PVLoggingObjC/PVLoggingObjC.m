#import <Foundation/Foundation.h>
#import "PVLoggingObjC.h"

//NS_INLINE
OBJC_EXPORT
void PVLog(NSUInteger level, NSUInteger flag, const char *file, const char *function, int line, NSString *_Nonnull format, ...) {
    BOOL async = YES;
    if (flag == PVLogFlagError) {
        async = NO;
    }
    va_list args;
    va_start(args, format);
    // TODO: This, i dunno.
    NSLogv(format, args);
    va_end(args);
}
