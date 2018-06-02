#import <Foundation/Foundation.h>
#import "HockeySDKNullability.h"

typedef struct {
    const void * __nullable exception;
    const char * __nullable exception_type_name;
    const char * __nullable exception_message;
    uint32_t exception_frames_count;
    const uintptr_t * __nonnull exception_frames;
} BITCrashUncaughtCXXExceptionInfo;

typedef void (*BITCrashUncaughtCXXExceptionHandler)(
    const BITCrashUncaughtCXXExceptionInfo * __nonnull info
);

@interface BITCrashUncaughtCXXExceptionHandlerManager : NSObject

+ (void)addCXXExceptionHandler:(nonnull BITCrashUncaughtCXXExceptionHandler)handler;
+ (void)removeCXXExceptionHandler:(nonnull BITCrashUncaughtCXXExceptionHandler)handler;

@end
