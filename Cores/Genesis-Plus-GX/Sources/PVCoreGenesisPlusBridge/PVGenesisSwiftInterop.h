//
//  PVGenesisSwiftInterop.h
//  PVGenesis
//
//  In the Xcode project the ObjC bridge imports the framework's generated
//  `PVGenesis-Swift.h`. In the SwiftPM package the bridge and the Swift module are
//  separate targets and the Swift module depends on the bridge, so the bridge cannot
//  import the Swift header (dependency cycle). This header gives the bridge the Swift
//  enum it stores and the options class it reads, resolved at runtime. Call sites keep
//  their `[PVCoreGenesisPlusOptions …]` spelling via the macro.
//
//  Not part of the module map on purpose: the Swift module declares the real
//  `GenesisCoreType`, and exposing this copy to Swift would clash with it.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Mirrors `GenesisCoreType` in GenesisOptions.swift (an `@objc` Int enum; same order).
typedef NS_ENUM(NSInteger, GenesisCoreType) {
    GenesisCoreTypeSG1000 = 0,
    GenesisCoreTypeMasterSystem = 1,
    GenesisCoreTypeGameGear = 2,
    GenesisCoreTypeGenesis = 3,
};

@protocol PVCoreGenesisPlusOptionsClass <NSObject>
@property (class, nonatomic, readonly) BOOL hq_fm;
@property (class, nonatomic, readonly) BOOL hq_psg;
@property (class, nonatomic, readonly) NSInteger filter;
@property (class, nonatomic, readonly) NSInteger ym2413;
@property (class, nonatomic, readonly) NSInteger ym2612;
@property (class, nonatomic, readonly) BOOL mono;
@property (class, nonatomic, readonly) BOOL no_sprite_limit;
@property (class, nonatomic, readonly) NSInteger overclock;
@property (class, nonatomic, readonly) BOOL gg_extra;
@property (class, nonatomic, readonly) NSInteger overscan;
@end

/// The Swift class is `@objc(PVCoreGenesisPlusOptions)`; the module-qualified name is the
/// fallback for a build of the Swift side that predates that attribute.
static inline Class<PVCoreGenesisPlusOptionsClass> PVCoreGenesisPlusOptionsClass(void) {
    Class cls = NSClassFromString(@"PVCoreGenesisPlusOptions") ?: NSClassFromString(@"PVGenesis.PVCoreGenesisPlusOptions");
    NSCAssert(cls != Nil, @"PVCoreGenesisPlusOptions (Swift) not loaded");
    return cls;
}

#define PVCoreGenesisPlusOptions PVCoreGenesisPlusOptionsClass()

NS_ASSUME_NONNULL_END
