//
//  PVMupenSwiftInterop.h
//  PVMupen64Plus
//
//  In the Xcode project the ObjC bridge imports the framework's generated
//  `PVMupen64PlusBridge-Swift.h`. In the SwiftPM package the bridge and the Swift
//  module are separate targets and the Swift module depends on the bridge, so the
//  bridge cannot import the Swift header (dependency cycle). This header gives the
//  bridge the two Swift classes it calls through protocols resolved at runtime.
//  The call sites keep their `[MupenGameCoreOptions …]` spelling via the macros.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PVMupenGameCoreOptionsClass <NSObject>
+ (BOOL)boolForOption:(NSString *)option;
+ (NSInteger)intForOption:(NSString *)option;
+ (float)floatForOption:(NSString *)option;
@property (class, nonatomic, readonly) BOOL useRice;
@property (class, nonatomic, readonly) BOOL perPixelLighting;
@property (class, nonatomic, readonly) BOOL dualJoystickOption;
@property (class, nonatomic, readonly) BOOL useCXD4;
@property (class, nonatomic, readonly) NSInteger controllerPak1Option;
@property (class, nonatomic, readonly) NSInteger controllerPak2Option;
@property (class, nonatomic, readonly) NSInteger controllerPak3Option;
@property (class, nonatomic, readonly) NSInteger controllerPak4Option;
@end

@protocol PVMupenBridgeRumbleHelperClass <NSObject>
+ (void)rumbleForBridgeObject:(NSObject *)bridgeObject
                       player:(NSInteger)player
                 lowFrequency:(float)lowFrequency
                highFrequency:(float)highFrequency
                     duration:(NSTimeInterval)duration;
+ (void)stopRumbleForBridgeObject:(NSObject *)bridgeObject player:(NSInteger)player;
@end

/// `MupenGameCoreOptions` is a plain `@objc` Swift class, so its runtime name is
/// `<module>.MupenGameCoreOptions`; the package module is `PVMupen`.
static inline Class<PVMupenGameCoreOptionsClass> PVMupenGameCoreOptionsClass(void) {
    Class cls = NSClassFromString(@"PVMupen64Plus.MupenGameCoreOptions") ?: NSClassFromString(@"MupenGameCoreOptions");
    NSCAssert(cls != Nil, @"MupenGameCoreOptions (Swift) not loaded");
    return cls;
}

static inline Class<PVMupenBridgeRumbleHelperClass> PVMupenBridgeRumbleHelperClass(void) {
    Class cls = NSClassFromString(@"PVMupenBridgeRumbleHelper");
    NSCAssert(cls != Nil, @"PVMupenBridgeRumbleHelper (Swift) not loaded");
    return cls;
}

#define MupenGameCoreOptions PVMupenGameCoreOptionsClass()
#define PVMupenBridgeRumbleHelper PVMupenBridgeRumbleHelperClass()

NS_ASSUME_NONNULL_END
