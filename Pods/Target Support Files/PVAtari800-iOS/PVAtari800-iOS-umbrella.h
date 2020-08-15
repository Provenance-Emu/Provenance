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

#import "ATR800GameCore.h"
#import "PVAtari800.h"

FOUNDATION_EXPORT double PVAtari800VersionNumber;
FOUNDATION_EXPORT const unsigned char PVAtari800VersionString[];

