@import Foundation;
@import PVCoreObjCBridge;

// Forward Declerations
@protocol ObjCBridgedCoreBridge;
@protocol PVSega32XSystemResponderClient;
typedef enum PVSega32XButton: NSInteger PVSega32XButton;

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVPicoDriveBridge: PVCoreObjCBridge <ObjCBridgedCoreBridge, PVSega32XSystemResponderClient>
#pragma clang diagnostic pop
- (void)didPushSega32XButton:(PVSega32XButton)button forPlayer:(NSUInteger)player;
- (void)didReleaseSega32XButton:(PVSega32XButton)button forPlayer:(NSUInteger)player;
@end

NS_HEADER_AUDIT_END(nullability, sendability)
