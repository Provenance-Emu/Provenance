//
//  PVOSDNotification.m
//  PVCoreObjCBridge
//

#import <PVCoreObjCBridge/PVOSDNotification.h>

NSNotificationName const PVOSDMessageNotification = @"PVOSDMessageNotification";
NSString * const PVOSDMessageKey  = @"PVOSDMessage";
NSString * const PVOSDTypeKey     = @"PVOSDType";
NSString * const PVOSDDurationKey = @"PVOSDDuration";

@implementation PVOSDNotification

+ (void)postMessage:(NSString *)message
               type:(PVOSDType)type
           duration:(NSTimeInterval)duration {
    NSDictionary *userInfo = @{
        PVOSDMessageKey:  message,
        PVOSDTypeKey:     @(type),
        PVOSDDurationKey: @(duration > 0 ? duration : 3.0),
    };
    // NSNotificationCenter is thread-safe for posting.
    [[NSNotificationCenter defaultCenter] postNotificationName:PVOSDMessageNotification
                                                        object:nil
                                                      userInfo:userInfo];
}

+ (void)postMessage:(NSString *)message {
    [self postMessage:message type:PVOSDTypeInfo duration:3.0];
}

@end
