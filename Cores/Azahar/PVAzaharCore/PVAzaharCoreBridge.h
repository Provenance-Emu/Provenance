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
@property (nonatomic, assign) NSInteger layoutOption;
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

/// Declared in the main @interface (SwiftPM/Xcode can drop ObjC categories, see CLAUDE.md).
- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType
        setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
