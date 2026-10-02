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

// MARK: - RetroAchievements hooks
// Declared in the main @interface, not a category: SwiftPM module synthesis
// can silently drop ObjC categories declared in separate headers.

NS_ASSUME_NONNULL_BEGIN

/// Called on the emulation thread at the end of every emulated frame, after
/// video, audio, and the save-RAM mirror are updated. The emulation loop runs
/// inside this bridge, so the Swift core's `executeFrame()` is never called.
@property (nonatomic, copy, nullable) void (^frameCompletedHandler)(void);

/// Asked before any save-state load. Returning YES rejects the load
/// (RetroAchievements hardcore mode with a live session).
@property (nonatomic, copy, nullable) BOOL (^saveStateLoadBlockedHandler)(void);

/// GBA Internal Work RAM (bus 0x03000000). NULL until a ROM is loaded.
/// The pointer stays valid until the bridge is deallocated.
- (nullable void *)iwramPointer:(nullable NSUInteger *)sizeOut;

/// GBA External Work RAM (bus 0x02000000). NULL until a ROM is loaded.
/// The pointer stays valid until the bridge is deallocated.
- (nullable void *)ewramPointer:(nullable NSUInteger *)sizeOut;

/// A copy of the cartridge save data (bus 0x0E000000), refreshed after every
/// frame, laid out like libretro's SAVE_RAM (flat save image; FLASH1M bank 0
/// first). mGBA re-maps its own save buffer when the save type is detected or
/// grows, so this stable mirror is what achievements read. NULL until a ROM
/// is loaded.
- (nullable void *)saveRAMMirrorPointer:(nullable NSUInteger *)sizeOut;

NS_ASSUME_NONNULL_END

@end

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Weverything" // Silence "Cannot find protocol definition" warning due to forward declaration.
@interface PVmGBAGameCoreBridge (Controls) <PVGBASystemResponderClient>
#pragma clang diagnostic pop

- (oneway void)didPushGBAButton:(PVGBAButton)button forPlayer:(NSUInteger)player;
- (oneway void)didReleaseGBAButton:(PVGBAButton)button forPlayer:(NSUInteger)player;

@end

@interface PVmGBAGameCoreBridge (Cheats)

- (BOOL)setCheat:(NSString *)code setType:(NSString *)type setEnabled:(BOOL)enabled;
- (void)resetCheatCodes;

@end
