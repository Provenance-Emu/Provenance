//
//  PVControllerButtonUtils.h
//  PVCoreObjCBridge
//
//  Shared utilities for detecting Share/Create/Capture and other center-face buttons
//  across modern controllers (DualSense, DualShock 4, Xbox Series, Nintendo Switch Pro).
//
//  Usage: Import via @import PVCoreObjCBridge; or #import <PVCoreObjCBridge/PVControllerButtonUtils.h>
//

#pragma once

#import <GameController/GameController.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Share/Create/Capture Button Detection

/**
 Returns the Share, Create, or Capture button for a controller via its physical input profile.

 Modern controllers expose extra center-face buttons only through the physical input profile:
 - PlayStation 4 (DualShock 4): "Button Share"
 - PlayStation 5 (DualSense):   "Button Create"
 - Xbox Series controllers:     "Button Share"
 - Nintendo Switch Pro:         "Button Capture"

 On PlayStation, these physical inputs correspond to the same Share/Create button that is already
 exposed logically as `buttonOptions`, so this lookup is effectively a redundant but harmless
 fallback. On Xbox Series (and Switch Pro), the physical entries represent an additional
 capture/share-style button beyond the `buttonOptions` logical button (View / + / −), so this
 helper is required to access those extra controls.

 @param controller The GCController to inspect.
 @return The share-like GCControllerButtonInput, or nil if unavailable.
 */
static inline GCControllerButtonInput * _Nullable
PVShareLikeButtonForController(GCController * _Nonnull controller) {
    NSDictionary<NSString *, GCControllerButtonInput *> *profileButtons =
        controller.physicalInputProfile.buttons;
    GCControllerButtonInput *button = profileButtons[@"Button Share"];
    if (!button) { button = profileButtons[@"Button Create"]; }
    if (!button) { button = profileButtons[@"Button Capture"]; }
    return button;
}

#pragma mark - Touchpad Button Detection

/**
 Returns the PlayStation touchpad button for DualShock 4 or DualSense controllers.

 The touchpad button provides an additional input point useful for mapping to Select
 on systems with limited button counts (NES, Game Boy, etc.).

 @param controller The GCController to inspect.
 @return The touchpad GCControllerButtonInput, or nil for non-PlayStation controllers.
 */
static inline GCControllerButtonInput * _Nullable
PVTouchpadButtonForController(GCController * _Nonnull controller) {
    GCExtendedGamepad *gamepad = controller.extendedGamepad;
    if (!gamepad) { return nil; }
    if ([gamepad isKindOfClass:[GCDualSenseGamepad class]]) {
        return [(GCDualSenseGamepad *)gamepad touchpadButton];
    }
    if ([gamepad isKindOfClass:[GCDualShockGamepad class]]) {
        return [(GCDualShockGamepad *)gamepad touchpadButton];
    }
    return nil;
}

#pragma mark - Start / Select Resolution

/**
 Resolves the optimal Start and Select button inputs for a controller.

 Handles all major modern controller families:

 | Controller        | Start         | Select                          |
 |-------------------|---------------|---------------------------------|
 | DualSense (PS5)   | buttonMenu    | buttonOptions (Create button)   |
 | DualShock 4 (PS4) | buttonMenu    | buttonOptions (Share button)    |
 | Xbox Series/One   | buttonMenu    | buttonOptions (View button)     |
 | Switch Pro        | buttonMenu    | buttonOptions (− button)        |
 | Generic MFi       | buttonOptions | nil (map shoulders instead)     |

 On systems that have distinct Start+Select (NES, Game Boy, SNES, etc.), pass both
 outStart and outSelect. On systems with only a Start button (Dreamcast, N64), pass
 NULL for outSelect — the parameter is optional and skipped when NULL.

 @param controller The GCController to inspect.
 @param outStart   Written with the resolved Start button input, or nil. Pass NULL to ignore.
 @param outSelect  Written with the resolved Select button input, or nil. Pass NULL to ignore.
 */
static inline void
PVResolveStartSelectButtons(GCController * _Nonnull controller,
                             GCControllerButtonInput * _Nullable * _Nullable outStart,
                             GCControllerButtonInput * _Nullable * _Nullable outSelect) {
    GCControllerButtonInput *resolvedStart  = nil;
    GCControllerButtonInput *resolvedSelect = nil;

    GCExtendedGamepad *gamepad = controller.extendedGamepad;
    if (gamepad) {
        BOOL isDualSense = [gamepad isKindOfClass:[GCDualSenseGamepad class]];
        BOOL isDualShock = [gamepad isKindOfClass:[GCDualShockGamepad class]];
        BOOL isXbox      = [gamepad isKindOfClass:[GCXboxGamepad class]];

        if (isDualSense || isDualShock) {
            // PlayStation controllers:
            //   buttonMenu    → Options button  (≡ / hamburger)  → Start
            //   buttonOptions → Create (PS5) / Share (PS4) button → Select
            resolvedStart  = gamepad.buttonMenu;
            resolvedSelect = gamepad.buttonOptions;
        } else if (isXbox) {
            // Xbox controllers:
            //   buttonMenu    → Menu button  (≡)  → Start
            //   buttonOptions → View button  (⊡)  → Select
            resolvedStart  = gamepad.buttonMenu;
            resolvedSelect = gamepad.buttonOptions;
        } else if (gamepad.buttonMenu) {
            // Switch Pro and other controllers with a dedicated menu/home button:
            //   buttonMenu    → + button → Start
            //   buttonOptions → − button → Select (may be nil on some controllers)
            resolvedStart  = gamepad.buttonMenu;
            resolvedSelect = gamepad.buttonOptions;
        } else if (gamepad.buttonOptions) {
            // Basic MFi controllers with only a single menu/pause button:
            //   buttonOptions → Single menu button → Start only
            //   (Select mapped via shoulder buttons in the calling core)
            resolvedStart  = gamepad.buttonOptions;
        }
    }

    if (outStart)  { *outStart  = resolvedStart; }
    if (outSelect) { *outSelect = resolvedSelect; }
}

/**
 Resolves Start and Select buttons with additional share-like and touchpad fallbacks.

 Extends PVResolveStartSelectButtons with fallback detection via the physical input
 profile (Share/Create/Capture buttons) and PlayStation touchpad. Prefer this variant
 for systems that benefit from alternative Select inputs (NES, GB, SNES, etc.).

 For PlayStation controllers, Select priority:
   1. PlayStation touchpad (DualSense/DualShock only)
   2. buttonOptions (logical Share/Create button)
   3. Physical profile Share/Create button (fallback via PVShareLikeButtonForController)

 For Xbox controllers, Select is:
   - buttonOptions (View button) only; the physical "Button Share" is exposed via outShareLike.

 For Nintendo Switch Pro, Select is:
   - buttonOptions (− button) only; no additional share-like or touchpad input exists.
 @param controller   The GCController to inspect.
 @param outStart     Written with the resolved Start button input, or nil.
 @param outSelect    Written with the resolved Select button input, or nil.
 @param outShareLike Written with the physical Share/Create/Capture button, or nil.
                     Callers may use this as an additional OR source for Select.
 */
static inline void
PVResolveStartSelectShareButtons(GCController * _Nonnull controller,
                                  GCControllerButtonInput * _Nullable * _Nonnull outStart,
                                  GCControllerButtonInput * _Nullable * _Nonnull outSelect,
                                  GCControllerButtonInput * _Nullable * _Nullable outShareLike) {
    *outStart  = nil;
    *outSelect = nil;
    if (outShareLike) { *outShareLike = nil; }

    GCExtendedGamepad *gamepad = controller.extendedGamepad;
    if (!gamepad) { return; }

    // Detect physical Share/Create/Capture button (available on PS4/PS5/Xbox Series/Switch Pro)
    GCControllerButtonInput *shareLike = PVShareLikeButtonForController(controller);
    if (outShareLike) { *outShareLike = shareLike; }

    BOOL isDualSense = [gamepad isKindOfClass:[GCDualSenseGamepad class]];
    BOOL isDualShock = [gamepad isKindOfClass:[GCDualShockGamepad class]];
    BOOL isXbox      = [gamepad isKindOfClass:[GCXboxGamepad class]];

    if (isDualSense || isDualShock) {
        // PlayStation: Options→Start, touchpad OR Create/Share→Select
        *outStart = gamepad.buttonMenu;

        // Prefer touchpad for Select (most ergonomic on PS4/PS5 for NES-era games)
        *outSelect = PVTouchpadButtonForController(controller);
        // Fall back to logical Share/Create (buttonOptions)
        if (!*outSelect) {
            *outSelect = gamepad.buttonOptions;
        }
        // Final fallback: physical profile button
        if (!*outSelect) {
            *outSelect = shareLike;
        }
    } else if (isXbox) {
        // Xbox: Menu→Start, View(buttonOptions)→Select.
        // Share(buttonShare/physical) is treated as an extra, non-Select button and
        // is exposed only via the outShareLike parameter above.
        *outStart  = gamepad.buttonMenu;
        *outSelect = gamepad.buttonOptions;   // View button
    } else if (gamepad.buttonMenu) {
        // Switch Pro and other controllers with dedicated menu+options buttons
        // Switch: +=Start, -=Select, Capture=physical only (don't use as Select)
        *outStart  = gamepad.buttonMenu;
        *outSelect = gamepad.buttonOptions;
        // NOTE: Do NOT use Capture button as Select on Switch Pro.
        // The − button (buttonOptions) is the natural Select equivalent.
    } else if (gamepad.buttonOptions) {
        // Basic MFi: single menu button → Start, no Select available here
        *outStart  = gamepad.buttonOptions;
        *outSelect = nil;
    }
}

#pragma mark - Universal Analog Deadzone Helpers

/**
 Returns the user-configured universal analog deadzone (0.0–0.5).

 Reads the "analogDeadzone" key from NSUserDefaults (set by PVSettings).
 Returns 0.0 when the preference has not been written (i.e., the user has not
 changed the default), meaning no additional deadzone is applied.
 */
static inline float PVAnalogDeadzone(void) {
    return (float)[[NSUserDefaults standardUserDefaults] floatForKey:@"analogDeadzone"];
}

/**
 Applies the universal analog deadzone to a normalized axis value in [-1, 1].

 Values inside [-deadzone, deadzone] snap to 0.  Outside values are rescaled so
 the output still spans the full [-1, 1] range (i.e. output is not compressed).

 If the universal deadzone setting is 0 (the default), the value is returned
 unchanged, imposing zero additional dead region on top of the hardware deadzone
 already applied by the GameController framework.

 @param value  Normalized axis value in [-1, 1].
 @return       Deadzoned and rescaled axis value in [-1, 1].
 */
static inline float PVApplyAnalogDeadzone(float value) {
    float dz = PVAnalogDeadzone();
    if (dz <= 0.0f) { return value; }
    float absVal = fabsf(value);
    if (absVal <= dz) { return 0.0f; }
    float sign = (value >= 0.0f) ? 1.0f : -1.0f;
    return sign * (absVal - dz) / (1.0f - dz);
}

/**
 Returns the effective digital-input threshold: the larger of @p fallback
 (the core's own hardcoded threshold) and the universal analog deadzone.

 Use this for cores that convert analog stick movement into digital button
 presses.  When the user has configured a larger universal deadzone the
 threshold grows to match, preventing partial stick deflections in the dead
 region from triggering digital presses.

 @param fallback  The core's own hardcoded digital conversion threshold.
 @return          The effective threshold to use for analog→digital conversion.
 */
static inline float PVAnalogDigitalThreshold(float fallback) {
    float dz = PVAnalogDeadzone();
    return (dz > fallback) ? dz : fallback;
}

NS_ASSUME_NONNULL_END
