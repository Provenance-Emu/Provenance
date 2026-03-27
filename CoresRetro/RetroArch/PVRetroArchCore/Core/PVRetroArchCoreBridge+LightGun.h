//
//  PVRetroArchCoreBridge+LightGun.h
//  PVRetroArch
//
//  Exposes light-gun input methods on PVRetroArchCoreBridge so that the Swift
//  LightGunResponder conformance on PVRetroArchCoreCore can forward coordinates
//  and button state to the C cocoa_input_state callback.
//

#import <PVRetroArch/PVRetroArchCoreBridge.h>

NS_ASSUME_NONNULL_BEGIN

@interface PVRetroArchCoreBridge (LightGun)

/// Set the current gun-aim position.
/// @param x  Normalised X in [-0x7FFF, +0x7FFF] (RETRO_DEVICE_ID_LIGHTGUN_SCREEN_X).
/// @param y  Normalised Y in [-0x7FFF, +0x7FFF] (RETRO_DEVICE_ID_LIGHTGUN_SCREEN_Y).
/// @param offscreen  YES when the gun is pointed off-screen.
- (void)setLightGunX:(int16_t)x y:(int16_t)y offscreen:(BOOL)offscreen;

/// Trigger (fire) button state.
- (void)setLightGunTrigger:(BOOL)down;

/// Reload (forced off-screen shot) button state.
- (void)setLightGunReload:(BOOL)down;

/// Auxiliary A button state (mapped to Cursor in older protocol).
- (void)setLightGunAuxA:(BOOL)down;

/// Auxiliary B button state (mapped to Turbo in older protocol).
- (void)setLightGunAuxB:(BOOL)down;

/// Start button state.
- (void)setLightGunStart:(BOOL)down;

/// Select button state.
- (void)setLightGunSelect:(BOOL)down;

/// Returns YES if the currently-loaded libretro core declared
/// RETRO_DEVICE_LIGHTGUN as a supported device type on any controller port.
@property (nonatomic, readonly) BOOL coreDeclaresLightGunDevice;

@end

NS_ASSUME_NONNULL_END
