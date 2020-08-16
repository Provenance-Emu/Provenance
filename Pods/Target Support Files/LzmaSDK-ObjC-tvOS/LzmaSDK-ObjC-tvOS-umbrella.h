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

#import "LzmaSDKObjCTypes.h"
#import "LzmaSDKObjCExtern.h"
#import "LzmaSDKObjCReader.h"
#import "LzmaSDKObjCWriter.h"
#import "LzmaSDKObjCItem.h"
#import "LzmaSDKObjCMutableItem.h"
#import "LzmaSDKObjCBufferProcessor.h"
#import "LzmaSDKObjCCrc.h"
#import "LzmaSDKObjC.h"

FOUNDATION_EXPORT double LzmaSDK_ObjCVersionNumber;
FOUNDATION_EXPORT const unsigned char LzmaSDK_ObjCVersionString[];

