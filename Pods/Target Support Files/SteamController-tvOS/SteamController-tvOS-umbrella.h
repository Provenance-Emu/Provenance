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

#import "SteamController.h"
#import "SteamControllerExtendedGamepad.h"
#import "SteamControllerInput.h"
#import "SteamControllerManager.h"

FOUNDATION_EXPORT double SteamControllerVersionNumber;
FOUNDATION_EXPORT const unsigned char SteamControllerVersionString[];

