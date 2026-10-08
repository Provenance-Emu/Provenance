#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <PVCoreObjCBridge/PVCoreObjCBridge.h>

@protocol ObjCBridgedCoreBridge;
typedef enum PV3DSButton: NSInteger PV3DSButton;

NS_ASSUME_NONNULL_BEGIN

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything"
@interface PVAzaharCoreBridge : PVCoreObjCBridge <ObjCBridgedCoreBridge>
#pragma clang diagnostic pop

/// Values pushed from PVAzaharCoreOptions before `loadFileAtPath:` (see Task 9).
@property (nonatomic, assign) NSInteger resolutionFactor;
@property (nonatomic, assign) NSInteger layoutOption;          // landscape: PVAzaharLayoutOption index
@property (nonatomic, assign) NSInteger portraitLayoutOption;  // 0 top full width, 1 original
@property (nonatomic, assign) BOOL swapScreens;
@property (nonatomic, assign) BOOL new3DSMode;
@property (nonatomic, assign) NSInteger cpuClockPercent;
@property (nonatomic, assign) BOOL hardwareShader;
@property (nonatomic, assign) BOOL accurateMultiplication;
@property (nonatomic, assign) BOOL asyncShaderCompilation;
@property (nonatomic, assign) BOOL asyncPresentation;
@property (nonatomic, assign) BOOL diskShaderCache;
@property (nonatomic, assign) NSInteger textureFilter;
@property (nonatomic, assign) BOOL audioStretching;
@property (nonatomic, assign) BOOL realtimeAudio;
@property (nonatomic, assign) NSInteger regionValue;
@property (nonatomic, assign) NSInteger frameLimitPercent;

/// The host (`PVEmulatorCore.startEmulation`) reads this: `Load` runs on the emu thread, so the core
/// is only marked running once `onEmulationStarted` fires, and a failed boot fires `onEmulationFailed`.
@property (nonatomic, readonly) BOOL startsEmulationAsynchronously;
/// YES when the MAP_JIT probe succeeded and the CPU JIT is in use (set in `applySettingsFromOptions`).
@property (nonatomic, readonly) BOOL jitActive;

/// Re-applies the live-safe options (layout, portrait layout, swap, speed limit) to a running core.
/// The Swift side calls it after copying fresh option values into the bridge properties.
- (void)applyLiveSettings;
/// Invoked on the main queue after `Core::System::Load` succeeds. Cleared once either block has fired.
@property (nonatomic, copy, nullable) void (^onEmulationStarted)(void);
/// Invoked on the main queue after a failed boot, once the bridge has torn itself down.
@property (nonatomic, copy, nullable) void (^onEmulationFailed)(NSString *message);

/// Declared in the main @interface (SwiftPM/Xcode can drop ObjC categories, see CLAUDE.md).
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
