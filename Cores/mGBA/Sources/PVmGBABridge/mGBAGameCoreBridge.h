#import <Foundation/Foundation.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

@protocol ObjCBridgedCoreBridge;
@protocol PVGBASystemResponderClient;
typedef enum PVGBAButton: NSInteger PVGBAButton;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVmGBAGameCoreBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge>
#pragma clang diagnostic pop

// Init
+ (instancetype)sharedInstance;
- (instancetype)init NS_DESIGNATED_INITIALIZER;

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVmGBAGameCoreBridge (Controls) <PVGBASystemResponderClient>
#pragma clang diagnostic pop

- (oneway void)didPushGBAButton:(PVGBAButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleaseGBAButton:(PVGBAButton)button forPlayer:(NSUInteger)player;

@end
