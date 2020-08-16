#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "LoggerClient.h"
#import "LoggerCommon.h"
#import "NSLogger.h"
#import "NSLoggerSwift.h"

FOUNDATION_EXPORT double NSLoggerVersionNumber;
FOUNDATION_EXPORT const unsigned char NSLoggerVersionString[];

