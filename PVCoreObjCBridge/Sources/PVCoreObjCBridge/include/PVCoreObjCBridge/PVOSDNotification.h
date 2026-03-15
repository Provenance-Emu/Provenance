//
//  PVOSDNotification.h
//  PVCoreObjCBridge
//
//  Thin ObjC helper that lets emulator C/ObjC++ bridge code post
//  on-screen display messages without taking a direct dependency on PVUI.
//  PVUI (PVEmulatorViewController+OSD.swift) observes these notifications
//  and forwards them to PVToastManager.
//
//  Usage from ObjC / ObjC++ bridge code:
//    [PVOSDNotification postMessage:@"Save state created" type:PVOSDTypeSuccess duration:3.0];
//    [PVOSDNotification postMessage:@"Keyboard error" type:PVOSDTypeError duration:4.0];
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// NSNotificationCenter name posted when an emulator core wants to show an OSD message.
/// userInfo keys: PVOSDMessageKey (NSString), PVOSDTypeKey (NSNumber/int), PVOSDDurationKey (NSNumber/double)
FOUNDATION_EXPORT NSNotificationName const PVOSDMessageNotification;

/// userInfo key — NSString message text.
FOUNDATION_EXPORT NSString * const PVOSDMessageKey;
/// userInfo key — NSNumber wrapping a PVOSDType integer.
FOUNDATION_EXPORT NSString * const PVOSDTypeKey;
/// userInfo key — NSNumber wrapping a TimeInterval (seconds). 0 = use default.
FOUNDATION_EXPORT NSString * const PVOSDDurationKey;

typedef NS_ENUM(NSInteger, PVOSDType) {
    PVOSDTypeInfo    = 0,
    PVOSDTypeSuccess = 1,
    PVOSDTypeWarning = 2,
    PVOSDTypeError   = 3,
};

/// Fire-and-forget helper — safe to call from any thread or C++ context.
@interface PVOSDNotification : NSObject

/// Post a transient OSD toast from any thread/context.
/// @param message   Human-readable text to display.
/// @param type      Severity / icon style (PVOSDType enum).
/// @param duration  Auto-dismiss delay in seconds. Pass 0 for the default (3 s).
+ (void)postMessage:(NSString *)message
               type:(PVOSDType)type
           duration:(NSTimeInterval)duration;

/// Convenience — info type, default duration.
+ (void)postMessage:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
