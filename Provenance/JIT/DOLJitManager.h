// Copyright 2021 Dolphin Emulator Project
// Licensed under GPLv2+
// Refer to the license.txt file included.

#import <Foundation/Foundation.h>

// Use forward declaration here instead of the Swift header to avoid a build failure
@class DOLCancellationToken;

typedef NS_ENUM(NSUInteger, DOLJitType)
{
  DOLJitTypeNone,
  DOLJitTypeDebugger,
  DOLJitTypeAllowUnsigned,
  DOLJitTypePTrace,
  DOLJitTypeNotRestricted
};

extern NSString* _Nonnull const DOLJitAcquiredNotification;
extern NSString* _Nonnull const DOLJitAltJitFailureNotification;

NS_ASSUME_NONNULL_BEGIN

@interface DOLJitManager : NSObject

+ (DOLJitManager*)sharedManager;

- (void)attemptToAcquireJitOnStartup;
- (void)recheckHasAcquiredJit;
- (void)attemptToAcquireJitByWaitingForDebuggerUsingCancellationToken:(DOLCancellationToken*)token;
- (void)attemptToAcquireJitByAltJIT;
- (void)attemptToAcquireJitByJitStreamer;
- (DOLJitType)jitType;
- (bool)appHasAcquiredJit;
- (void)setAuxiliaryError:(NSString*)error;
- (nullable NSString*)getAuxiliaryError;

@end

NS_ASSUME_NONNULL_END
