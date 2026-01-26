//
//  PVRetroArchCoreBridge+Controls.m
//  PVRetroArch
//
//  Created by Joseph Mattiello on 11/1/18.
//  Copyright © 2021 Provenance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "./cocoa_common.h"

/* RetroArch Includes */
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <boolean.h>
#include <Availability.h>
#import <GameController/GameController.h>
#include "libretro-common/include/libretro.h"
#include "../../frontend/frontend.h"
#include "../../tasks/tasks_internal.h"
#include "../../input/drivers/cocoa_input.h"
#include "../../input/drivers_keyboard/keyboard_event_apple.h"
#include "../../input/input_keymaps.h"
#include "../../configuration.h"
#include "../../retroarch.h"
#include "../../verbosity.h"
#include "../ui_companion_driver.h"

#ifdef HAVE_COREMOTION && !TARGET_OS_TV
#import <CoreMotion/CoreMotion.h>
static CMMotionManager *motionManager;
#endif
#ifdef HAVE_MFI
#import <GameController/GameController.h>
#endif
#if TARGET_OS_IOS && !TARGET_OS_TV
#import <CoreHaptics/CoreHaptics.h>
#endif

#ifndef MAX_MFI_CONTROLLERS
#define MAX_MFI_CONTROLLERS 16
#endif
enum
{
	GCCONTROLLER_PLAYER_INDEX_UNSET = -1,
};
uint32_t mfi_buttons[MAX_USERS];
int16_t  mfi_axes[MAX_USERS][6];
uint32_t mfi_controllers[MAX_MFI_CONTROLLERS];
typedef unsigned char  u8;
typedef signed char    s8;
typedef unsigned short u16;
typedef unsigned int   u32;
extern bool _isInitialized;
extern __weak PVRetroArchCoreBridge *_current;
void handle_touch_event(NSArray* touches);
void handle_click_event(CGPoint click, bool pressed);
/// Virtual controller for player 1 (used for on-screen touch controls and forwarded hardware input)
GCController *touch_controller;
/// Array of virtual controllers for multiplayer support (one per player)
/// Each hardware controller forwards inputs to its corresponding touch_controller
static GCController *touch_controllers[MAX_USERS];
static NSMutableArray *mfiControllers;
/// Flag to indicate Provenance is managing controllers
/// When true, hardware controllers are only accessed via bindControls forwarding to touch_controllers
/// When false, RetroArch polls hardware controllers directly (standalone mode)
static bool provenance_controller_mode = false;

/// Flag to enable smart shoulder-to-start/select mapping for MFi controllers
/// When true, L2→Select and R2→Start on controllers without dedicated start/select buttons
/// Only applies to systems that don't natively use L2/R2 triggers
static bool smart_shoulder_mapping_enabled = true;

/// Per-player flag indicating if that player's controller needs shoulder mapping
/// Set during bindControls based on the hardware controller's capabilities
static bool player_needs_shoulder_mapping[MAX_USERS];

void apple_gamecontroller_joypad_connect(GCController *controller);
void refresh_gamecontrollers();
void apple_gamecontroller_joypad_disconnect(GCController* controller);

/// Check if a controller has dedicated Start/Select buttons (Options/Share on PS, Menu/View on Xbox)
/// MFi controllers like Steelseries Nimbus only have Menu button, no Options/Share
static bool controller_has_dedicated_start_select(GCController *controller) {
    if (!controller || !controller.extendedGamepad) {
        return false;
    }
    /// Check if buttonOptions exists and is functional
    /// Controllers with buttonOptions have a dedicated Select button (Share/View/Options)
    /// This is available on PS4/PS5/Xbox/Switch controllers but NOT on basic MFi controllers
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        /// If buttonOptions is nil or not present, this is likely a basic MFi controller
        if (controller.extendedGamepad.buttonOptions == nil) {
            return false;
        }
        return true;
    }
    /// Before iOS 13, assume no dedicated buttons
    return false;
}

/// Check if the current system natively uses L2/R2 triggers
/// Systems like PS1, PS2, Saturn, Dreamcast, GameCube, N64 need all 4 shoulder buttons
/// Systems like NES, SNES, Genesis, Game Boy don't use L2/R2 natively
static bool system_needs_l2r2_triggers(void) {
    if (!_current || !_current.systemIdentifier) {
        return false;
    }
    NSString *sysId = _current.systemIdentifier;

    /// Systems that natively use L2/R2 triggers - don't remap shoulders
    static NSArray *systemsWithL2R2 = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        systemsWithL2R2 = @[
            /// Sony systems with L2/R2
            @"psx", @"ps1", @"playstation",
            @"ps2", @"playstation2",
            @"psp",
            /// Sega systems with analog triggers
            @"saturn",
            @"dreamcast", @"dc",
            /// Nintendo systems with analog triggers
            @"gc", @"gamecube", @"ngc",
            @"n64", @"nintendo64",
            @"wii",
            @"wiiu",
            @"switch",
            /// Other systems with L2/R2
            @"3do",
            @"jaguar"
        ];
    });

    NSString *lowerSysId = [sysId lowercaseString];
    for (NSString *system in systemsWithL2R2) {
        if ([lowerSysId containsString:system]) {
            return true;
        }
    }
    return false;
}

/// Check if we should apply smart shoulder mapping for a given controller
/// Returns true if:
/// 1. Smart mapping is enabled
/// 2. Controller lacks dedicated Start/Select buttons (basic MFi)
/// 3. Current system doesn't natively use L2/R2 triggers
static bool should_apply_shoulder_mapping(GCController *controller) {
    if (!smart_shoulder_mapping_enabled) {
        return false;
    }
    bool hasDedicated = controller_has_dedicated_start_select(controller);
    bool needsL2R2 = system_needs_l2r2_triggers();
    /// If the system needs L2/R2, only remap when the controller lacks Start/Select
    if (needsL2R2) {
        return !hasDedicated;
    }
    /// For systems without L2/R2, remap when Start/Select are missing
    return !hasDedicated;
}

#if TARGET_OS_IOS && !TARGET_OS_TV
#define IPHONE_RUMBLE_AVAIL API_AVAILABLE(ios(14.0))
static CHHapticEngine *deviceHapticEngine IPHONE_RUMBLE_AVAIL;
static id<CHHapticPatternPlayer> deviceWeakPlayer IPHONE_RUMBLE_AVAIL;
static id<CHHapticPatternPlayer> deviceStrongPlayer IPHONE_RUMBLE_AVAIL;
#define MFI_RUMBLE_AVAIL API_AVAILABLE(ios(14.0), tvos(14.0))
#define MFI_WEAK_RUMBLE 0.5f
static unsigned mfi_rumble_gain[MAX_MFI_CONTROLLERS];
@class PVMFIRumbleController;
static PVMFIRumbleController *mfi_rumblers[MAX_MFI_CONTROLLERS];

@interface PVMFIRumbleController : NSObject
@property (nonatomic, strong, readonly) GCController *controller;
@property (nonatomic, strong) NSMutableSet<CHHapticEngine *> *engines MFI_RUMBLE_AVAIL;
@property (nonatomic, strong, readonly) id<CHHapticPatternPlayer> strongPlayer MFI_RUMBLE_AVAIL;
@property (nonatomic, strong, readonly) id<CHHapticPatternPlayer> weakPlayer MFI_RUMBLE_AVAIL;
- (instancetype)initWithController:(GCController*)controller MFI_RUMBLE_AVAIL;
- (void)shutdown MFI_RUMBLE_AVAIL;
@end

@implementation PVMFIRumbleController
@synthesize strongPlayer = _strongPlayer;
@synthesize weakPlayer   = _weakPlayer;

- (instancetype)initWithController:(GCController*)controller MFI_RUMBLE_AVAIL
{
    if (self = [super init])
    {
        if (!controller.haptics)
            return self;

        _controller = controller;
        _engines = [[NSMutableSet alloc] init];
    }
    return self;
}

- (id<CHHapticPatternPlayer>)createPlayerWithLocality:(GCHapticsLocality)locality andIntensity:(float)intensity MFI_RUMBLE_AVAIL
{
    NSError *error;
    if (!self.controller)
        return nil;

    if (![self.controller.haptics.supportedLocalities containsObject:locality])
        locality = GCHapticsLocalityDefault;
    CHHapticEngine *engine = [self.controller.haptics createEngineWithLocality:locality];
    [engine startAndReturnError:&error];
    if (error)
        return nil;

    [self.engines addObject:engine];

    __weak PVMFIRumbleController *weakSelf = self;
    engine.resetHandler = ^{
        PVMFIRumbleController *strongSelf = weakSelf;
        if (!strongSelf)
            return;

        for (CHHapticEngine *eng in strongSelf.engines)
            [eng startAndReturnError:nil];
    };

    CHHapticEventParameter *intense;
    CHHapticEvent *event;
    CHHapticPattern *pattern;
    CHHapticEventParameter *sharp;

    intense = [[CHHapticEventParameter alloc]
               initWithParameterID:CHHapticEventParameterIDHapticIntensity
               value:intensity];
    sharp   = [[CHHapticEventParameter alloc]
               initWithParameterID:CHHapticEventParameterIDHapticSharpness
               value:1.0];
    event   = [[CHHapticEvent alloc]
             initWithEventType:CHHapticEventTypeHapticContinuous
             parameters:[NSArray arrayWithObjects:intense, sharp, nil]
             relativeTime:0
             duration:GCHapticDurationInfinite];
    pattern = [[CHHapticPattern alloc]
               initWithEvents:[NSArray arrayWithObject:event]
               parameters:[[NSArray alloc] init]
               error:&error];

    if (error)
        return nil;

    id<CHHapticPatternPlayer> player = [engine createPlayerWithPattern:pattern error:&error];
    if (error)
        return nil;
    [player stopAtTime:0 error:&error];
    return player;
}

- (id<CHHapticPatternPlayer>)strongPlayer
{
    _strongPlayer = _strongPlayer ?: [self createPlayerWithLocality:GCHapticsLocalityAll andIntensity:1.0];
    return _strongPlayer;
}

- (id<CHHapticPatternPlayer>)weakPlayer
{
    _weakPlayer = _weakPlayer ?: [self createPlayerWithLocality:GCHapticsLocalityTriggers andIntensity:MFI_WEAK_RUMBLE];
    return _weakPlayer;
}

- (void)shutdown
{
    if (@available(iOS 14, tvOS 14, *))
    {
        for (CHHapticEngine *eng in self.engines)
            eng.resetHandler = ^{};
        [self.engines removeAllObjects];
        if (_weakPlayer) [_weakPlayer cancelAndReturnError:nil];
        _weakPlayer   = nil;
        if (_strongPlayer) [_strongPlayer cancelAndReturnError:nil];
        _strongPlayer = nil;
    }
}

@end

static void apple_gamecontroller_device_haptics_setup(void) IPHONE_RUMBLE_AVAIL
{
    NSError *error;
    if (!CHHapticEngine.capabilitiesForHardware.supportsHaptics)
        return;
    if (deviceHapticEngine)
        return;

    CHHapticEngine *engine = [[CHHapticEngine alloc] initAndReturnError:&error];
    if (error)
        return;

    deviceHapticEngine = engine;

    deviceHapticEngine.stoppedHandler = ^(CHHapticEngineStoppedReason reason)
    {
        deviceHapticEngine = nil;
    };
    deviceHapticEngine.resetHandler = ^{
        if (!deviceHapticEngine)
            return;
        [deviceHapticEngine startAndReturnError:nil];
    };

    [deviceHapticEngine startAndReturnError:&error];
}

static id<CHHapticPatternPlayer> apple_gamecontroller_device_haptics_create_player(float intensity) IPHONE_RUMBLE_AVAIL
{
    NSError *error;
    if (!CHHapticEngine.capabilitiesForHardware.supportsHaptics)
        return nil;
    apple_gamecontroller_device_haptics_setup();
    if (!deviceHapticEngine)
        return nil;

    CHHapticEventParameter *intense;
    CHHapticEvent *event;
    CHHapticPattern *pattern;
    NSError *patternError;
    CHHapticEventParameter *sharp;

    intense = [[CHHapticEventParameter alloc]
               initWithParameterID:CHHapticEventParameterIDHapticIntensity
               value:intensity];
    sharp   = [[CHHapticEventParameter alloc]
               initWithParameterID:CHHapticEventParameterIDHapticSharpness
               value:1.0];
    event   = [[CHHapticEvent alloc]
               initWithEventType:CHHapticEventTypeHapticContinuous
               parameters:[NSArray arrayWithObjects:intense, sharp, nil]
               relativeTime:0
               duration:GCHapticDurationInfinite];
    pattern = [[CHHapticPattern alloc]
               initWithEvents:[NSArray arrayWithObject:event]
               parameters:[[NSArray alloc] init]
               error:&patternError];

    if (patternError)
        return nil;

    id<CHHapticPatternPlayer> player = [deviceHapticEngine createPlayerWithPattern:pattern error:&error];
    if (error)
        return nil;
    [player stopAtTime:0 error:&error];
    return player;
}

static id<CHHapticPatternPlayer> apple_gamecontroller_device_haptics_strong_player(void) IPHONE_RUMBLE_AVAIL
{
    if (!deviceStrongPlayer)
        deviceStrongPlayer = apple_gamecontroller_device_haptics_create_player(1.0f);
    return deviceStrongPlayer;
}

static id<CHHapticPatternPlayer> apple_gamecontroller_device_haptics_weak_player(void) IPHONE_RUMBLE_AVAIL
{
    if (!deviceWeakPlayer)
        deviceWeakPlayer = apple_gamecontroller_device_haptics_create_player(0.7f);
    return deviceWeakPlayer;
}

static void apple_gamecontroller_joypad_setup_haptics(GCController *controller) MFI_RUMBLE_AVAIL
{
    if (@available(iOS 14, tvOS 14, *))
        mfi_rumblers[controller.playerIndex] = [[PVMFIRumbleController alloc] initWithController:controller];
}
#endif

/// Forward declaration for CustomLayout category
@interface PVRetroArchCoreBridge (CustomLayout)
@property (nonatomic, assign) BOOL useCustomRenderViewLayout;
@end

@implementation PVRetroArchCoreBridge (Controls)
- (void)initControllBuffers {}
#pragma mark - Control
-(void)controllerConnected:(NSNotification *)notification {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        /// In Provenance mode, don't connect hardware controllers to RetroArch's internal system
        /// Provenance manages controller assignments, and inputs are forwarded via bindControls
        if (!provenance_controller_mode) {
            apple_gamecontroller_joypad_connect([notification object]);
        }
        [self refresh_gamecontrollers];
        [self useRetroArchController:self.retroArchControls];
        ILOG(@"Binding Controls\n");
    });
}
-(void)controllerDisconnected:(NSNotification *)notification {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        /// In Provenance mode, hardware controllers aren't connected to RetroArch's internal system
        if (!provenance_controller_mode) {
            apple_gamecontroller_joypad_disconnect([notification object]);
        }
        [self refresh_gamecontrollers];
        [self useRetroArchController:self.retroArchControls];
    });
}

-(void)keyboardConnected:(NSNotification *)notification {
    [self useRetroArchController:self.retroArchControls];
}
-(void)keyboardDisconnected:(NSNotification *)notification {
    [self useRetroArchController:self.retroArchControls];
}
- (void)processKeyPress:(int)key pressed:(bool)pressed {
    if (self.bindAnalogKeys) {
        switch (key) {
                static float dPadX=0;
                static float dPadY=0;
                static float leftXAxis=0;
                static float leftYAxis=0;
                static float rightXAxis=0;
                static float rightYAxis=0;
            case(KEY_S): // down
                leftYAxis=pressed?-1.0:leftYAxis<0 ? 0 : leftYAxis;
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
                break;
            case(KEY_W): // up
                leftYAxis=pressed?1.0:leftYAxis>0 ? 0 : leftYAxis;
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
                break;
            case(KEY_D):  // right
                leftXAxis=pressed?1.0:leftXAxis>0 ? 0 :leftXAxis;
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
                break;
            case(KEY_A):  // left
                leftXAxis=pressed?-1.0:leftXAxis<0 ? 0 : leftXAxis;
                [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:leftXAxis yAxis:leftYAxis];
                break;
            case(KEY_O): // up
                rightYAxis=pressed?1.0:rightYAxis > 0 ? 0 : rightYAxis;
                [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                if (self.bindAnalogDpad)
                    [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
               break;
            case(KEY_L): // down
                rightYAxis=pressed?-1.0:rightYAxis < 0 ? 0 : rightYAxis;
                [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                if (self.bindAnalogDpad)
                    [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
               break;
            case(KEY_K):  // left
                rightXAxis=pressed?-1.0:rightXAxis < 0 ? 0 : rightXAxis;
                [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                if (self.bindAnalogDpad)
                    [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                break;
            case(KEY_Semicolon):  // right
                rightXAxis=pressed?1.0:rightXAxis > 0 ? 0 : rightXAxis;
                [touch_controller.extendedGamepad.rightThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                if (self.bindAnalogDpad)
                    [touch_controller.extendedGamepad.leftThumbstick setValueForXAxis:rightXAxis yAxis:rightYAxis];
                break;
            case(KEY_Up):
                dPadY = pressed ? 1.0 : dPadY > 0 ? 0 : dPadY;
                [touch_controller.extendedGamepad.dpad setValueForXAxis:dPadX yAxis:dPadY];
                break;
            case(KEY_Down):
                dPadY = pressed ? -1.0 : dPadY < 0 ? 0.0 : dPadY;
                [touch_controller.extendedGamepad.dpad setValueForXAxis:dPadX yAxis:dPadY];
                break;
            case(KEY_Left):
                dPadX = pressed ? -1.0 : dPadX < 0 ? 0.0 : dPadX;
                [touch_controller.extendedGamepad.dpad setValueForXAxis:dPadX yAxis:dPadY];
                break;
            case(KEY_Right):
                dPadX = pressed ? 1.0 : dPadX > 0 ? 0.0 : dPadX;
                [touch_controller.extendedGamepad.dpad setValueForXAxis:dPadX yAxis:dPadY];
                break;
            case(KEY_F):
                [touch_controller.extendedGamepad.buttonB setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Space):
                [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Q):
                [touch_controller.extendedGamepad.buttonX setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_E):
                [touch_controller.extendedGamepad.buttonY setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_G):
                [touch_controller.extendedGamepad.buttonY setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Y):
                [touch_controller.extendedGamepad.buttonX setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_J):
                [touch_controller.extendedGamepad.buttonB setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_B):
                [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_N):
                [touch_controller.extendedGamepad.buttonA setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Tab):
                [touch_controller.extendedGamepad.leftShoulder setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_LeftShift):
                [touch_controller.extendedGamepad.leftTrigger
                    setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_X):
                [touch_controller.extendedGamepad.leftThumbstickButton setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_R):
                [touch_controller.extendedGamepad.rightShoulder setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_V):
                [touch_controller.extendedGamepad.rightTrigger setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_C):
                [touch_controller.extendedGamepad.rightThumbstickButton setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_U):
                [touch_controller.extendedGamepad.buttonOptions setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_I):
                [touch_controller.extendedGamepad.buttonMenu
                    setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_Slash):
                [touch_controller.extendedGamepad.buttonOptions setValue:pressed ? 1.0 : 0.0];
                break;
            case(KEY_RightShift):
                [touch_controller.extendedGamepad.buttonMenu
                    setValue:pressed ? 1.0 : 0.0];
                break;
            default:
                break;
        }
    }
    if (self.bindNumKeys) {
        switch (key) {
            case(KEY_Z):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP1, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_X):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP2, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_C):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP3, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_A):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP4, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_S):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP5, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_D):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP6, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Q):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP7, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_W):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP8, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_E):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP9, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Up):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP8, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Down):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP2, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Left):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP4, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_Right):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP6, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_LeftControl):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP0, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_LeftAlt):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_PERIOD, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_LeftShift):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_ENTER, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_V):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_ENTER, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_F):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_PLUS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_R):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_MINUS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_3):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_MULTIPLY, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_2):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_DIVIDE, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            case(KEY_4):
                apple_direct_input_keyboard_event(pressed, (int)RETROK_KP_EQUALS, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
                break;
            default:
                break;
        }
    }
    switch (key) {
        case(KEY_RightAlt):
            apple_direct_input_keyboard_event(pressed, (int)RETROK_ESCAPE, 0, 0, (int)RETRO_DEVICE_KEYBOARD);
            break;
    }
}
-(void)refresh_gamecontrollers {
    /// Connect all virtual touch_controllers for multiplayer support
    /// Each player slot gets its own touch_controller that hardware controllers forward to
    for (int player = 0; player < MAX_USERS; player++) {
        if (touch_controllers[player]) {
            apple_gamecontroller_joypad_connect(touch_controllers[player]);
        }
    }

    /// In Provenance mode, we don't connect hardware controllers to RetroArch's internal system
    /// Instead, inputs are forwarded via bindControls handlers to the appropriate touch_controller
    /// This prevents player index conflicts and double input registration
    if (!provenance_controller_mode) {
        /// Standalone mode - connect hardware controllers directly
        for (NSInteger player = 0; player < 8; player++) {
            GCController *controller = nil;
            switch (player) {
                case 0: controller = _current.controller1; break;
                case 1: controller = _current.controller2; break;
                case 2: controller = _current.controller3; break;
                case 3: controller = _current.controller4; break;
                case 4: controller = _current.controller5; break;
                case 5: controller = _current.controller6; break;
                case 6: controller = _current.controller7; break;
                case 7: controller = _current.controller8; break;
            }
            if (controller) {
                apple_gamecontroller_joypad_connect(controller);
            }
        }
    }

    /// Set up input forwarding handlers for all connected controllers
    [self bindControls];
}
-(void)setupControllers {
    _current=self;
    ILOG(@"Setting up Controller Notification Listeners\n");
    /// Enable Provenance controller mode - hardware controllers are managed via bindControls
    /// forwarding to touch_controller, preventing double input registration
    provenance_controller_mode = true;
    [self initControllBuffers];
    [self useRetroArchController:self.retroArchControls];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerConnected:)
                                                 name:GCControllerDidConnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(controllerDisconnected:)
                                                 name:GCControllerDidDisconnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardConnected:)
                                                 name:GCKeyboardDidConnectNotification
                                               object:nil
    ];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDisconnected:)
                                                 name:GCKeyboardDidDisconnectNotification
                                               object:nil
    ];
}
-(void)bindControls {
    for (NSInteger player = 0; player < 8; player++)
    {
        GCController *controller = nil;
        switch (player) {
            case 0: controller = self.controller1; break;
            case 1: controller = self.controller2; break;
            case 2: controller = self.controller3; break;
            case 3: controller = self.controller4; break;
            case 4: controller = self.controller5; break;
            case 5: controller = self.controller6; break;
            case 6: controller = self.controller7; break;
            case 7: controller = self.controller8; break;
        }

        if (!controller) {
            continue;
        }

        ILOG(@"Controller Vendor Name: %s for player %ld\n", controller.vendorName.UTF8String, (long)player);

#if TARGET_OS_TV
        /// On tvOS, skip the Siri Remote (microGamepad only, no extendedGamepad)
        /// The Siri Remote has limited buttons and shouldn't be used for game input
        if (controller.microGamepad != nil && controller.extendedGamepad == nil) {
            ILOG(@"Skipping Siri Remote (microGamepad only) for game input\n");
            continue;
        }
#endif

        if (controller.extendedGamepad != nil && ![controller.vendorName containsString:@"Keyboard"])
        {
            /// Get the correct virtual controller for this player slot
            /// Each player gets their own touch_controller to ensure proper player separation
            GCController *targetController = touch_controllers[player];
            if (!targetController) {
                WLOG(@"No touch_controller for player %ld, falling back to player 0\n", (long)player);
                targetController = touch_controller;
            }

            /// Determine if this hardware controller needs smart shoulder mapping
            /// Check the HARDWARE controller (not virtual) for buttonOptions capability
            bool needsShoulderMapping = should_apply_shoulder_mapping(controller);
            player_needs_shoulder_mapping[player] = needsShoulderMapping;

            ILOG(@"bindControls: Binding player %ld controller '%@' -> touch_controller with playerIndex=%ld (shoulderMapping=%s)\n",
                 (long)player, controller.vendorName, (long)targetController.playerIndex,
                 needsShoulderMapping ? "YES" : "NO");

            /// Capture targetController in block to ensure correct player mapping
            /// Use strong reference since touch_controllers array retains them
            GCController *strongTarget = targetController;

            /// Disable system gestures for menu/options/home buttons so input is delivered to the app
            if (@available(iOS 14.0, tvOS 14.0, *)) {
                GCExtendedGamepad *gp = controller.extendedGamepad;
                if (gp) {
                    if (gp.buttonOptions) gp.buttonOptions.preferredSystemGestureState = GCSystemGestureStateDisabled;
                    if (gp.buttonMenu) gp.buttonMenu.preferredSystemGestureState = GCSystemGestureStateDisabled;
                    if (gp.buttonHome) gp.buttonHome.preferredSystemGestureState = GCSystemGestureStateDisabled;
                }
            }

            /// Fallback: use valueChangedHandler to catch Options/Menu when pressedChangedHandler fails
            GCExtendedGamepadValueChangedHandler previousHandler = controller.extendedGamepad.valueChangedHandler;
            controller.extendedGamepad.valueChangedHandler = ^(GCExtendedGamepad *gamepad, GCControllerElement *element) {
                if (element == gamepad.buttonOptions && gamepad.buttonOptions) {
                    [strongTarget.extendedGamepad.buttonOptions setValue:gamepad.buttonOptions.value];
                } else if (element == gamepad.buttonMenu && gamepad.buttonMenu) {
                    [strongTarget.extendedGamepad.buttonMenu setValue:gamepad.buttonMenu.value];
                }
                if (previousHandler) {
                    previousHandler(gamepad, element);
                }
            };

            controller.extendedGamepad.buttonA.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.buttonA setValue:value];
            };
            controller.extendedGamepad.buttonB.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.buttonB setValue:value];
            };
            controller.extendedGamepad.buttonX.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.buttonX setValue:value];
            };
            controller.extendedGamepad.buttonY.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.buttonY setValue:value];
            };
            controller.extendedGamepad.leftShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.leftShoulder setValue:value];
            };
            controller.extendedGamepad.rightShoulder.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.rightShoulder setValue:value];
            };
            controller.extendedGamepad.leftTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.leftTrigger setValue:value];
            };
            controller.extendedGamepad.rightTrigger.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.rightTrigger setValue:value];
            };
            controller.extendedGamepad.dpad.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [strongTarget.extendedGamepad.dpad setValueForXAxis:xValue yAxis:yValue];
            };
            controller.extendedGamepad.leftThumbstick.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [strongTarget.extendedGamepad.leftThumbstick setValueForXAxis:xValue yAxis:yValue];
            };
            controller.extendedGamepad.rightThumbstick.valueChangedHandler = ^(GCControllerDirectionPad *dpad, float xValue, float yValue) {
                [strongTarget.extendedGamepad.rightThumbstick setValueForXAxis:xValue yAxis:yValue];
            };
            controller.extendedGamepad.leftThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.leftThumbstickButton setValue:value];
            };
            controller.extendedGamepad.rightThumbstickButton.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.rightThumbstickButton setValue:value];
            };
            controller.extendedGamepad.buttonOptions.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.buttonOptions setValue:value];
            };
            #if defined(__IPHONE_13_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_13_0
            /// buttonMenu maps to START in RetroArch (RETRO_DEVICE_ID_JOYPAD_START)
            controller.extendedGamepad.buttonMenu.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.buttonMenu setValue:value];
            };
            #endif
            #if defined(__IPHONE_14_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_14_0
            controller.extendedGamepad.buttonHome.pressedChangedHandler = ^(GCControllerButtonInput* button, float value, bool pressed) {
                [strongTarget.extendedGamepad.buttonHome setValue:value];
                /// Toggle RetroArch menu on HOME button press
                if (pressed) {
                    command_event(CMD_EVENT_MENU_TOGGLE, NULL);
                }
            };
            #endif
        }
    }
}

- (void)sendEvent:(UIEvent *)event {
    [super sendEvent:event];
    if (@available(iOS 13.4, *)) {
        if (event.type == UIEventTypeHover)
            return;
    }
    if (event.allTouches.count)
        handle_touch_event(event.allTouches.allObjects);
}

-(void)useRetroArchController:(BOOL)flag {
    self.retroArchControls=flag;
    bool should_update=false;
    settings_t *settings            = config_get_ptr();
    if (!settings) {
        ILOG(@"Option: Settings not available, skipping overlay update\n");
        return;
    }
    input_driver_state_t  *input_st = input_state_get_ptr();
    input_overlay_t       *ol       = input_st ? input_st->overlay_ptr : NULL;
    input_overlay_state_t *ol_state = ol ? &ol->overlay_state : NULL;

    /// Check if skins are being used (Delta or Manic skin)
    /// Skins take priority - if skins are active, RetroArch overlay must be disabled
    BOOL usingSkins = self.useCustomRenderViewLayout;

    NSString *original_overlay = settings->paths.path_overlay ? [NSString stringWithUTF8String:settings->paths.path_overlay] : @"";

    /// When using skins, always disable RetroArch overlay regardless of setting
    if (usingSkins) {
        ILOG(@"Option: Using skins - disabling RetroArch overlay (flag was %d)\n", flag);
        settings->bools.input_overlay_enable=false;
        should_update=true;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowTouchControls" object:nil userInfo:nil];
    } else if (flag) {
        /// RetroArch controls enabled: enable overlay and hide PVControllerViewController
        ILOG(@"Option: Use Retro arch controller\n");
        if ([original_overlay
             containsString:@RETROARCH_PVOVERLAY]) {
            NSString *overlay=@RETROARCH_DEFAULT_OVERLAY;
            NSString *new_overlay=[overlay stringByReplacingOccurrencesOfString:@"/RetroArch"
             withString:[self.batterySavesPath stringByAppendingPathComponent:@"../../RetroArch" ]];
            if (![new_overlay isEqualToString:original_overlay]) {
                configuration_set_string(settings,
                        settings->paths.path_overlay,
                        new_overlay.UTF8String
                );
                settings->bools.input_overlay_auto_scale=true;
                settings->floats.input_overlay_opacity=0.3;
                ILOG(@"Updating %s to %s\n", original_overlay.UTF8String, new_overlay.UTF8String);
            }
        }
        settings->bools.input_overlay_enable=true;
        should_update=true;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"HideTouchControls" object:nil userInfo:nil];
    } else {
        /// RetroArch controls disabled: disable overlay and show PVControllerViewController
        should_update=true;
        settings->bools.input_overlay_enable=false;
        ILOG(@"Option: Don't Use Retro arch controller\n");

        [[NSNotificationCenter defaultCenter] postNotificationName:@"ShowTouchControls" object:nil userInfo:nil];
    }
    if (should_update) {
        ILOG(@"Option: Updating Overlay\n");
        command_event(CMD_EVENT_OVERLAY_INIT, NULL);
    }

}
@end
static bool apple_gamecontroller_available(void) {
	return true;
}

static void apple_gamecontroller_joypad_poll_internal(GCController *controller)
{
	uint32_t slot, pause, select, l3, r3;
	uint32_t *buttons;
	if (!controller)
		return;

	slot               = (uint32_t)controller.playerIndex;
	/* If we have not assigned a slot to this controller yet, ignore it. */
    if (slot >= MAX_USERS)
		return;
	buttons            = &mfi_buttons[slot];

	/* retain the values from the paused controller handler and pass them through */
	if (@available(iOS 13, *))
	{
		/* The menu button can be pressed/unpressed
		 * like any other button in iOS 13,
		 * so no need to passthrough anything */
		*buttons = 0;
	}
	else
	{
		/* Use the paused controller handler for iOS versions below 13 */
		pause              = *buttons & (1 << RETRO_DEVICE_ID_JOYPAD_START);
		select             = *buttons & (1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
		l3                 = *buttons & (1 << RETRO_DEVICE_ID_JOYPAD_L3);
		r3                 = *buttons & (1 << RETRO_DEVICE_ID_JOYPAD_R3);
		*buttons           = 0 | pause | select | l3 | r3;
	}
	memset(mfi_axes[slot], 0, sizeof(mfi_axes[0]));
    if (controller.extendedGamepad)
	{
		GCExtendedGamepad *gp = (GCExtendedGamepad *)controller.extendedGamepad;

		*buttons             |= gp.dpad.up.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_UP)    : 0;
		*buttons             |= gp.dpad.down.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_DOWN)  : 0;
		*buttons             |= gp.dpad.left.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_LEFT)  : 0;
		*buttons             |= gp.dpad.right.pressed      ? (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT) : 0;
		*buttons             |= gp.buttonA.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_B)     : 0;
		*buttons             |= gp.buttonB.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_A)     : 0;
		*buttons             |= gp.buttonX.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_Y)     : 0;
		*buttons             |= gp.buttonY.pressed         ? (1 << RETRO_DEVICE_ID_JOYPAD_X)     : 0;
		*buttons             |= gp.leftShoulder.pressed    ? (1 << RETRO_DEVICE_ID_JOYPAD_L)     : 0;
		*buttons             |= gp.rightShoulder.pressed   ? (1 << RETRO_DEVICE_ID_JOYPAD_R)     : 0;
		/// For virtual controllers, check value > 0 in addition to pressed state
		/// Use a small threshold to ensure we catch values that are set programmatically
		const float triggerThreshold = 0.1f;
		/// Check if this is any of the virtual touch_controllers
		bool isVirtualController = false;
		for (int i = 0; i < MAX_USERS; i++) {
			if (controller == touch_controllers[i]) {
				isVirtualController = true;
				break;
			}
		}
		bool leftTriggerActive = gp.leftTrigger.pressed || (isVirtualController && gp.leftTrigger.value >= triggerThreshold);
		bool rightTriggerActive = gp.rightTrigger.pressed || (isVirtualController && gp.rightTrigger.value >= triggerThreshold);

		/// Smart shoulder mapping for MFi controllers without dedicated Start/Select buttons
		/// On systems that don't use L2/R2 natively (NES, SNES, etc.), map:
		/// - L2 → Select
		/// - R2 → Start
		/// This gives MFi controller users easy access to Start/Select without using Menu button combos
		/// Use the per-player flag set during bindControls (checks the hardware controller's capabilities)
		bool applyShoulderMapping = (slot < MAX_USERS) && player_needs_shoulder_mapping[slot];

		if (applyShoulderMapping) {
			/// Remap L2 to Select instead of L2
			*buttons             |= leftTriggerActive         ? (1 << RETRO_DEVICE_ID_JOYPAD_SELECT) : 0;
			/// Remap R2 to Start instead of R2
			*buttons             |= rightTriggerActive        ? (1 << RETRO_DEVICE_ID_JOYPAD_START)  : 0;
		} else {
			/// Normal mapping - L2/R2 go to their native buttons
			*buttons             |= leftTriggerActive         ? (1 << RETRO_DEVICE_ID_JOYPAD_L2)    : 0;
			*buttons             |= rightTriggerActive        ? (1 << RETRO_DEVICE_ID_JOYPAD_R2)    : 0;
		}
        // NSLog(@"leftTriggerActive: %@, rightTriggerActive: %@", leftTriggerActive ? @"Yes" : @"No",  rightTriggerActive ? @"Yes" : @"No");
        //printf("slot %d button %d extended\n", slot, *buttons);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 120100 || __TV_OS_VERSION_MAX_ALLOWED >= 120100
		if (@available(iOS 12.1, *))
		{
			*buttons         |= gp.leftThumbstickButton.pressed ? (1 << RETRO_DEVICE_ID_JOYPAD_L3) : 0;
			*buttons         |= gp.rightThumbstickButton.pressed ? (1 << RETRO_DEVICE_ID_JOYPAD_R3) : 0;
		}
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 130000 || __TV_OS_VERSION_MAX_ALLOWED >= 130000
		if (@available(iOS 13, *))
		{
			/* Support "Options" button present in PS4 / XBox One controllers */
			*buttons         |= gp.buttonOptions.pressed ? (1 << RETRO_DEVICE_ID_JOYPAD_SELECT) : 0;

			/* Support buttons that aren't supported by older mFi controller via "hotkey" combinations:
			 *
			 * LS + Menu => Select
			 * LT + Menu => L3
			 * RT + Menu => R3
			*/
			if (gp.buttonMenu.pressed )
			{
				if (gp.leftShoulder.pressed)
					*buttons     |= 1 << RETRO_DEVICE_ID_JOYPAD_SELECT;
				else if (gp.leftTrigger.pressed)
					*buttons     |= 1 << RETRO_DEVICE_ID_JOYPAD_L2;
				else if (gp.rightTrigger.pressed)
					*buttons     |= 1 << RETRO_DEVICE_ID_JOYPAD_R2;
				else
					*buttons     |= 1 << RETRO_DEVICE_ID_JOYPAD_START;
			}
		}
#endif

		mfi_axes[slot][0]     = gp.leftThumbstick.xAxis.value * 32767.0f;
		mfi_axes[slot][1]     = gp.leftThumbstick.yAxis.value * 32767.0f;
		mfi_axes[slot][2]     = gp.rightThumbstick.xAxis.value * 32767.0f;
		mfi_axes[slot][3]     = gp.rightThumbstick.yAxis.value * 32767.0f;
        mfi_axes[slot][4]     = gp.leftTrigger.value         * 32767.0f;
        mfi_axes[slot][5]     = gp.rightTrigger.value         * 32767.0f;
        //printf("slot %d axes %d extended\n", slot, mfi_axes[slot][0]);
	}

	/* GCGamepad is deprecated */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
	else if (controller.gamepad)
	{
		GCGamepad *gp = (GCGamepad *)controller.gamepad;

		*buttons |= gp.dpad.up.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_UP)    : 0;
		*buttons |= gp.dpad.down.pressed     ? (1 << RETRO_DEVICE_ID_JOYPAD_DOWN)  : 0;
		*buttons |= gp.dpad.left.pressed     ? (1 << RETRO_DEVICE_ID_JOYPAD_LEFT)  : 0;
		*buttons |= gp.dpad.right.pressed    ? (1 << RETRO_DEVICE_ID_JOYPAD_RIGHT) : 0;
		*buttons |= gp.buttonA.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_B)     : 0;
		*buttons |= gp.buttonB.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_A)     : 0;
		*buttons |= gp.buttonX.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_Y)     : 0;
		*buttons |= gp.buttonY.pressed       ? (1 << RETRO_DEVICE_ID_JOYPAD_X)     : 0;
		*buttons |= gp.leftShoulder.pressed  ? (1 << RETRO_DEVICE_ID_JOYPAD_L)     : 0;
		*buttons |= gp.rightShoulder.pressed ? (1 << RETRO_DEVICE_ID_JOYPAD_R)     : 0;
        //printf("slot %d button %d gamepad\n", slot, *buttons);

	}
#pragma clang diagnostic pop
}

static void apple_gamecontroller_joypad_poll(void)
{
	if (!apple_gamecontroller_available())
		return;

	/// When Provenance is managing controllers, poll all virtual touch_controllers
	/// Hardware controller inputs are forwarded via bindControls handlers to the appropriate touch_controller
	/// This prevents double input registration (buttons appearing on multiple players)
	if (provenance_controller_mode) {
		for (int player = 0; player < MAX_USERS; player++) {
			if (touch_controllers[player])
				apple_gamecontroller_joypad_poll_internal(touch_controllers[player]);
		}
		return;
	}

	/// Standalone RetroArch mode - poll all hardware controllers directly
	for (GCController *controller in [GCController controllers])
		apple_gamecontroller_joypad_poll_internal(controller);
    if (touch_controller)
        apple_gamecontroller_joypad_poll_internal(touch_controller);
}

/* GCGamepad is deprecated */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated"
static void apple_gamecontroller_joypad_register(GCExtendedGamepad * _Nullable __strong gamepad)
{
#ifdef __IPHONE_14_0
	/* Don't let tvOS or iOS do anything with **our** buttons!!
	 * iOS will start a screen recording if you hold or doubleclick
	 * the OPTIONS button, we don't want that. */
	if (@available(iOS 14.0, tvOS 14.0, *))
	{
		GCExtendedGamepad *gp = (GCExtendedGamepad *)gamepad.controller.extendedGamepad;
		gp.buttonOptions.preferredSystemGestureState = GCSystemGestureStateDisabled;
		gp.buttonMenu.preferredSystemGestureState    = GCSystemGestureStateDisabled;
		gp.buttonHome.preferredSystemGestureState    = GCSystemGestureStateDisabled;
	}
#endif

	gamepad.valueChangedHandler = ^(GCExtendedGamepad *updateGamepad, GCControllerElement *element)
	{
		/// In Provenance mode, hardware controllers are polled via touch_controller forwarding
		/// Skip direct polling to avoid double input registration
		if (provenance_controller_mode && updateGamepad.controller != touch_controller)
			return;
		apple_gamecontroller_joypad_poll_internal(updateGamepad.controller);
	};

	/* controllerPausedHandler is deprecated in favor
	 * of being able to deal with the menu
	 * button as any other button */
	if (@available(iOS 13, *))
	   return;

	{
		gamepad.controller.controllerPausedHandler = ^(GCController *controller)

		{
		   uint32_t slot      = (uint32_t)controller.playerIndex;

		   /* Support buttons that aren't supported by the mFi
			* controller via "hotkey" combinations:
			*
			* LS + Menu => Select
			* LT + Menu => L3
			* RT + Menu => R3
			* Note that these are just button presses, and it
			* does not simulate holding down the button
			*/
		   if (     controller.gamepad.leftShoulder.pressed
				 || controller.extendedGamepad.leftShoulder.pressed )
		   {
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L);
			  mfi_buttons[slot] |= (1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
			  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_SELECT);
					});
			  return;
		   }

		   if (controller.extendedGamepad.leftTrigger.pressed )
		   {
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L2);
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
			  mfi_buttons[slot] |= (1 << RETRO_DEVICE_ID_JOYPAD_L3);
			  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_L3);
					});
			  return;
		   }

		   if (controller.extendedGamepad.rightTrigger.pressed )
		   {
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R2);
			  mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
			  mfi_buttons[slot] |= (1 << RETRO_DEVICE_ID_JOYPAD_R3);
			  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
					mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_R3);
					});
			  return;
		   }

		   mfi_buttons[slot] |= (1 << RETRO_DEVICE_ID_JOYPAD_START);

		   dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
				 mfi_buttons[slot] &= ~(1 << RETRO_DEVICE_ID_JOYPAD_START);
				 });
		};
	}
}
#pragma clang diagnostic pop
int auto_incr_id=0;
static void mfi_joypad_autodetect_add(unsigned autoconf_pad)
{
    auto_incr_id+=1;
	input_autoconfigure_connect("mFi Controller", NULL, mfi_joypad.ident, autoconf_pad, auto_incr_id, 0);
}

/// Check if a controller is one of our virtual touch_controllers
static bool is_virtual_touch_controller(GCController *controller) {
	for (int i = 0; i < MAX_USERS; i++) {
		if (controller == touch_controllers[i])
			return true;
	}
	return false;
}

void apple_gamecontroller_joypad_connect(GCController *controller)
{
	signed desired_index = (int32_t)controller.playerIndex;
	desired_index        = (desired_index >= 0 && desired_index < MAX_MFI_CONTROLLERS)
	? desired_index : 0;
    /* prevent same controller getting set twice */
	if ([mfiControllers containsObject:controller])
		return;
    if ([controller.vendorName containsString:@"Keyboard"])
        return;

	/// Virtual touch_controllers have fixed player indices set during init
	/// Don't add them to mfiControllers to prevent playerIndex reassignment
	if (is_virtual_touch_controller(controller)) {
		/// Just register for autodetect with their fixed playerIndex
		if (controller.extendedGamepad)
			apple_gamecontroller_joypad_register(controller.extendedGamepad);
		else
			apple_gamecontroller_joypad_register(controller.gamepad);
		mfi_joypad_autodetect_add((unsigned)controller.playerIndex);
		return;
	}

	if (mfi_controllers[desired_index] != (uint32_t)controller.hash)
	{
		/* desired slot is unused, take it */
		if (!mfi_controllers[desired_index])
		{
			controller.playerIndex = (GCControllerPlayerIndex)desired_index;
			mfi_controllers[desired_index] = (uint32_t)controller.hash;
		}
		else
		{
			/* find a new slot for this controller that's unused */
			unsigned i;

			for (i = 0; i < MAX_MFI_CONTROLLERS; ++i)
			{
				if (mfi_controllers[i])
					continue;

				mfi_controllers[i] = (uint32_t)controller.hash;
				controller.playerIndex = (GCControllerPlayerIndex)i;
				break;
			}
		}
		[mfiControllers addObject:controller];
		/* Move any non-game controllers (like the siri remote) to the end */
		if (mfiControllers.count > 1)
		{
		   int newPlayerIndex = 0;
		   NSInteger connectedNonGameControllerIndex = NSNotFound;
		   NSUInteger index = 0;

		   for (GCController *connectedController in mfiControllers)
		   {
			  if (     connectedController.gamepad         == nil
					&& connectedController.extendedGamepad == nil )
				 connectedNonGameControllerIndex = index;
			  index++;
		   }

		   if (connectedNonGameControllerIndex != NSNotFound)
		   {
			  GCController *nonGameController = [mfiControllers objectAtIndex:connectedNonGameControllerIndex];
			  [mfiControllers removeObjectAtIndex:connectedNonGameControllerIndex];
			  [mfiControllers addObject:nonGameController];
		   }
		   for (GCController *gc in mfiControllers)
			  gc.playerIndex = (GCControllerPlayerIndex)newPlayerIndex++;
		}
        if (controller.extendedGamepad)
            apple_gamecontroller_joypad_register(controller.extendedGamepad);
        else
            apple_gamecontroller_joypad_register(controller.gamepad);
#if TARGET_OS_IOS && !TARGET_OS_TV
        if (@available(iOS 14, *))
            apple_gamecontroller_joypad_setup_haptics(controller);
#endif
		mfi_joypad_autodetect_add((unsigned)controller.playerIndex);
	}
}

void apple_gamecontroller_joypad_disconnect(GCController* controller)
{
	signed pad = (int32_t)controller.playerIndex;

	if (pad == GCCONTROLLER_PLAYER_INDEX_UNSET)
		return;

#if TARGET_OS_IOS && !TARGET_OS_TV
	if (@available(iOS 14, *))
	{
		if (pad < MAX_MFI_CONTROLLERS && mfi_rumblers[pad])
		{
			[mfi_rumblers[pad] shutdown];
			mfi_rumblers[pad] = nil;
		}
	}
#endif

	mfi_controllers[pad] = 0;
	if ([mfiControllers containsObject:controller])
	{
		[mfiControllers removeObject:controller];
		input_autoconfigure_disconnect(pad, mfi_joypad.ident);
	}
}

void *apple_gamecontroller_joypad_init(void *data) {
    if (!apple_gamecontroller_available())
      return NULL;

    /// Enable Provenance controller mode early in initialization
    /// This ensures hardware controllers aren't connected directly to RetroArch
    /// and instead are managed via bindControls forwarding
    provenance_controller_mode = true;

    mfiControllers=[[NSMutableArray alloc] initWithCapacity:MAX_MFI_CONTROLLERS];

    for (int i=0; i < MAX_MFI_CONTROLLERS; i++) {
        mfi_controllers[i]=0;
#if TARGET_OS_IOS && !TARGET_OS_TV
        mfi_rumble_gain[i] = 100;
        mfi_rumblers[i] = nil;
#endif
    }
#if TARGET_OS_IOS && !TARGET_OS_TV
    if (@available(iOS 14, *))
        apple_gamecontroller_device_haptics_setup();
#endif
    /// Initialize virtual touch_controllers for each player slot
    /// This allows each hardware controller to map to its own player correctly
    for (int player = 0; player < MAX_USERS; player++) {
        if (!touch_controllers[player]) {
            /// controllerWithExtendedGamepad returns an already-initialized virtual controller
            /// Do NOT call init again - that would return a different/invalid object
            touch_controllers[player] = [GCController controllerWithExtendedGamepad];
            if (touch_controllers[player]) {
                touch_controllers[player].playerIndex = (GCControllerPlayerIndex)player;
                apple_gamecontroller_joypad_connect(touch_controllers[player]);
                ILOG(@"Initialized touch_controller for player %d with playerIndex=%ld\n",
                     player, (long)touch_controllers[player].playerIndex);
            } else {
                ELOG(@"Failed to create virtual touch_controller for player %d\n", player);
            }
        }
    }
    /// Keep touch_controller as alias to player 0 for backwards compatibility with on-screen touch
    if (!touch_controller) {
        touch_controller = touch_controllers[0];
    }
    [_current refresh_gamecontrollers];
    return (void*)-1;
}

void apple_gamecontroller_joypad_destroy(void) {
    printf("Controller: Disconnecting Controllers\n");
    /*
    if (touch_controller) {
        apple_gamecontroller_joypad_disconnect(touch_controller);
    }
    for (GCController *gc in mfiControllers)
        apple_gamecontroller_joypad_disconnect(gc);
     */
    /// Clean up all virtual touch_controllers
    for (int player = 0; player < MAX_USERS; player++) {
        touch_controllers[player] = nil;
    }
    touch_controller = nil;

    /// Reset Provenance controller mode so next core load starts fresh
    provenance_controller_mode = false;

    /// Clear mfiControllers array
    [mfiControllers removeAllObjects];

    /// Clear mfi_controllers hash array
    for (int i = 0; i < MAX_MFI_CONTROLLERS; i++) {
        mfi_controllers[i] = 0;
    }

    /// Clear button and axis state
    for (int i = 0; i < MAX_USERS; i++) {
        mfi_buttons[i] = 0;
        memset(mfi_axes[i], 0, sizeof(mfi_axes[0]));
    }

    /// Clear shoulder mapping flags
    for (int i = 0; i < MAX_USERS; i++) {
        player_needs_shoulder_mapping[i] = false;
    }
}

static int32_t apple_gamecontroller_joypad_button(
	  unsigned port, uint16_t joykey)
{
   if (port >= DEFAULT_MAX_PADS)
	  return 0;
   /* Check hat. */
   else if (GET_HAT_DIR(joykey))
	  return 0;
   else if (joykey < 32)
	  return ((mfi_buttons[port] & (1 << joykey)) != 0);
   return 0;
}

static void apple_gamecontroller_joypad_get_buttons(unsigned port,
	  input_bits_t *state)
{
	BITS_COPY16_PTR(state, mfi_buttons[port]);
}

static int16_t apple_gamecontroller_joypad_axis(
	  unsigned port, uint32_t joyaxis)
{
	int16_t val  = 0;
	int16_t axis = -1;
	bool is_neg  = false;
	bool is_pos  = false;

	if (AXIS_NEG_GET(joyaxis) < 6)
	{
		axis     = AXIS_NEG_GET(joyaxis);
		is_neg   = true;
	}
	else if(AXIS_POS_GET(joyaxis) < 6)
	{
		axis     = AXIS_POS_GET(joyaxis);
		is_pos   = true;
	}
	else
	   return 0;

	if (axis >= 0 && axis < 6)
	   val  = mfi_axes[port][axis];
	if (is_neg && val > 0)
	   return 0;
	else if (is_pos && val < 0)
	   return 0;
	return val;
}

static int16_t apple_gamecontroller_joypad_state(
	  rarch_joypad_info_t *joypad_info,
	  const struct retro_keybind *binds,
	  unsigned port)
{
   unsigned i;
   int16_t ret                          = 0;
   uint16_t port_idx                    = joypad_info->joy_idx;

   if (port_idx >= DEFAULT_MAX_PADS)
	  return 0;

   for (i = 0; i < RARCH_FIRST_CUSTOM_BIND; i++)
   {
	  /* Auto-binds are per joypad, not per user. */
	  const uint64_t joykey  = (binds[i].joykey != NO_BTN)
		 ? binds[i].joykey  : joypad_info->auto_binds[i].joykey;
	  const uint32_t joyaxis = (binds[i].joyaxis != AXIS_NONE)
		 ? binds[i].joyaxis : joypad_info->auto_binds[i].joyaxis;
	  if (     (uint16_t)joykey != NO_BTN
			&& !GET_HAT_DIR(i)
			&& (i < 32)
			&& ((mfi_buttons[port_idx] & (1 << i)) != 0)
		 )
		 ret |= ( 1 << i);
	  else if (joyaxis != AXIS_NONE &&
			((float)abs(apple_gamecontroller_joypad_axis(port_idx, joyaxis))
			 / 0x8000) > joypad_info->axis_threshold)
		 ret |= (1 << i);
   }
   return ret;
}

static bool apple_gamecontroller_joypad_query_pad(unsigned pad)
{
	return pad < MAX_USERS;
}

static const char *apple_gamecontroller_joypad_name(unsigned pad)
{
	if (pad >= MAX_USERS)
		return NULL;

	return "mFi Controller";
}

static bool apple_gamecontroller_joypad_set_rumble(unsigned pad,
      enum retro_rumble_effect type, uint16_t strength)
{
#if TARGET_OS_IOS && !TARGET_OS_TV
    if (@available(iOS 14, *))
    {
        settings_t *settings            = config_get_ptr();
        bool enable_device_vibration    = settings->bools.enable_device_vibration;

        if (enable_device_vibration && pad == 0)
        {
            NSError *error;
            id<CHHapticPatternPlayer> player = (type == RETRO_RUMBLE_STRONG ?
                                                apple_gamecontroller_device_haptics_strong_player() :
                                                apple_gamecontroller_device_haptics_weak_player());
            if (player)
            {
                if (strength == 0)
                    [player stopAtTime:0 error:&error];
                else
                {
                    float str = (float)strength / 65535.0f;
                    unsigned gain = (pad < MAX_MFI_CONTROLLERS) ? mfi_rumble_gain[pad] : 100;
                    str *= (float)gain / 100.0f;
                    CHHapticDynamicParameter *param = [[CHHapticDynamicParameter alloc]
                       initWithParameterID:CHHapticDynamicParameterIDHapticIntensityControl
                                                       value:str
                                                       relativeTime:0];
                    [player sendParameters:[NSArray arrayWithObject:param] atTime:0 error:&error];
                    if (!error)
                        [player startAtTime:0 error:&error];
                }
            }
        }

        if (pad < MAX_MFI_CONTROLLERS)
        {
           PVMFIRumbleController *rumble = mfi_rumblers[pad];
           if (rumble)
           {
              NSError *error;
              id<CHHapticPatternPlayer> player = (type == RETRO_RUMBLE_STRONG ? rumble.strongPlayer : rumble.weakPlayer);
              if (player)
              {
                 if (strength == 0)
                    [player stopAtTime:0 error:&error];
                 else
                 {
                    float str = (float)strength / 65535.0f;
                    unsigned gain = mfi_rumble_gain[pad];
                    str *= (float)gain / 100.0f;
                    if (type == RETRO_RUMBLE_WEAK) str *= MFI_WEAK_RUMBLE;
                    CHHapticDynamicParameter *param = [[CHHapticDynamicParameter alloc]
                       initWithParameterID:CHHapticDynamicParameterIDHapticIntensityControl
                                    value:str
                             relativeTime:0];
                    [player sendParameters:[NSArray arrayWithObject:param] atTime:0 error:&error];
                    if (!error)
                       [player startAtTime:0 error:&error];
                 }
                 return error == nil;
              }
           }
        }
    }
#endif
    return false;
}

static bool apple_gamecontroller_joypad_set_rumble_gain(unsigned pad, unsigned gain)
{
#if TARGET_OS_IOS && !TARGET_OS_TV
    if (pad < MAX_MFI_CONTROLLERS)
    {
        mfi_rumble_gain[pad] = gain > 100 ? 100 : gain;
        return true;
    }
#endif
    return false;
}

static bool apple_gamecontroller_joypad_set_sensor_state(void *data, unsigned port,
      enum retro_sensor_action action, unsigned rate)
{
   if (   (action != RETRO_SENSOR_ACCELEROMETER_ENABLE)
       && (action != RETRO_SENSOR_ACCELEROMETER_DISABLE)
       && (action != RETRO_SENSOR_GYROSCOPE_ENABLE)
       && (action != RETRO_SENSOR_GYROSCOPE_DISABLE))
      return false;

#if TARGET_OS_IOS && !TARGET_OS_TV
   if (@available(iOS 14.0, *))
   {
      if (port < MAX_MFI_CONTROLLERS)
      {
         GCController *controller = nil;
         if (port == 0 && touch_controller)
            controller = touch_controller;
         else if (mfiControllers)
         {
            for (GCController *c in mfiControllers)
            {
               if (c.playerIndex == port)
               {
                  controller = c;
                  break;
               }
            }
         }

         if (controller && controller.motion)
         {
            if (controller.motion.sensorsRequireManualActivation)
            {
               if (     (action == RETRO_SENSOR_ACCELEROMETER_ENABLE)
                     || (action == RETRO_SENSOR_GYROSCOPE_ENABLE))
                  controller.motion.sensorsActive = YES;
               else
                  controller.motion.sensorsActive = NO;
            }
            return true;
         }
      }
   }
#endif

#ifdef HAVE_COREMOTION && !TARGET_OS_TV
   if (port == 0)
   {
      if (!motionManager)
         motionManager = [[CMMotionManager alloc] init];

      if (!motionManager || !motionManager.deviceMotionAvailable)
         return false;

      if (     (action == RETRO_SENSOR_ACCELEROMETER_ENABLE)
            || (action == RETRO_SENSOR_GYROSCOPE_ENABLE))
      {
         if (!motionManager.deviceMotionActive)
            [motionManager startDeviceMotionUpdates];
         motionManager.deviceMotionUpdateInterval = 1.0f / (float)rate;
      }
      else
      {
         if (motionManager.deviceMotionActive)
            [motionManager stopDeviceMotionUpdates];
      }

      return true;
   }
#endif

   return false;
}

static float apple_gamecontroller_joypad_get_sensor_input(void *data, unsigned port, unsigned id)
{
#if TARGET_OS_IOS && !TARGET_OS_TV
   if (@available(iOS 14.0, *))
   {
      if (port < MAX_MFI_CONTROLLERS)
      {
         GCController *controller = nil;
         if (port == 0 && touch_controller)
            controller = touch_controller;
         else if (mfiControllers)
         {
            for (GCController *c in mfiControllers)
            {
               if (c.playerIndex == port)
               {
                  controller = c;
                  break;
               }
            }
         }

         if (controller && controller.motion)
         {
            switch (id)
            {
               case RETRO_SENSOR_ACCELEROMETER_X:
                  return controller.motion.userAcceleration.x;
               case RETRO_SENSOR_ACCELEROMETER_Y:
                  return controller.motion.userAcceleration.y;
               case RETRO_SENSOR_ACCELEROMETER_Z:
                  return controller.motion.userAcceleration.z;
               case RETRO_SENSOR_GYROSCOPE_X:
                  return controller.motion.rotationRate.x;
               case RETRO_SENSOR_GYROSCOPE_Y:
                  return controller.motion.rotationRate.y;
               case RETRO_SENSOR_GYROSCOPE_Z:
                  return controller.motion.rotationRate.z;
            }
         }
      }
   }
#endif

#ifdef HAVE_COREMOTION && !TARGET_OS_TV
   if (port == 0 && motionManager && motionManager.deviceMotionActive)
   {
      switch (id)
      {
         case RETRO_SENSOR_ACCELEROMETER_X:
            return motionManager.deviceMotion.userAcceleration.x;
         case RETRO_SENSOR_ACCELEROMETER_Y:
            return motionManager.deviceMotion.userAcceleration.y;
         case RETRO_SENSOR_ACCELEROMETER_Z:
            return motionManager.deviceMotion.userAcceleration.z;
         case RETRO_SENSOR_GYROSCOPE_X:
            return motionManager.deviceMotion.rotationRate.x;
         case RETRO_SENSOR_GYROSCOPE_Y:
            return motionManager.deviceMotion.rotationRate.y;
         case RETRO_SENSOR_GYROSCOPE_Z:
            return motionManager.deviceMotion.rotationRate.z;
      }
   }
#endif

   return 0.0f;
}

input_device_driver_t mfi_joypad = {
	apple_gamecontroller_joypad_init,       // void *(*init)(void *data);
	apple_gamecontroller_joypad_query_pad,  // bool (*query_pad)(unsigned);
	apple_gamecontroller_joypad_destroy,    // void (*destroy)(void);
	apple_gamecontroller_joypad_button,     // int32_t (*button)(unsigned, uint16_t);
	apple_gamecontroller_joypad_state,      // int16_t (*state)(rarch_joypad_info_t *joypad_info,
                                            //          const struct retro_keybind *binds, unsigned port);
	apple_gamecontroller_joypad_get_buttons,// void (*get_buttons)(unsigned, input_bits_t *);
	apple_gamecontroller_joypad_axis,       // int16_t (*axis)(unsigned, uint32_t);
	apple_gamecontroller_joypad_poll,       // void (*poll)(void);
	apple_gamecontroller_joypad_set_rumble, // bool (*set_rumble)(unsigned, enum retro_rumble_effect, uint16_t);
	apple_gamecontroller_joypad_set_rumble_gain, // bool (*set_rumble_gain)(unsigned, unsigned);
    apple_gamecontroller_joypad_set_sensor_state, // bool (*set_sensor_state)(void *data, unsigned port,
                                            //       enum retro_sensor_action action, unsigned rate);
    apple_gamecontroller_joypad_get_sensor_input, // float (*get_sensor_input)(void *data, unsigned port, unsigned id);
	apple_gamecontroller_joypad_name,       // const char *(*name)(unsigned);
	"mfi",                                  // const char *ident;
};

@interface CocoaView (Utility)
-(void) showRetroArchNotification:_:(NSString *)title _:(NSString *)message _:(enum message_queue_icon)icon _:(enum message_queue_category)category;
@end
@implementation CocoaView (Utility)
// A native swift wrapper around displaying notifications
-(void) showRetroArchNotification:_:(NSString *)title _:(NSString *)message _:(enum message_queue_icon)icon _:(enum message_queue_category)category {
    runloop_msg_queue_push([message UTF8String], message.length, 1, 100, true, [title UTF8String], icon, category);
}
@end

enum
{
   NSAlphaShiftKeyMask                  = 1 << 16,
   NSShiftKeyMask                       = 1 << 17,
   NSControlKeyMask                     = 1 << 18,
   NSAlternateKeyMask                   = 1 << 19,
   NSCommandKeyMask                     = 1 << 20,
   NSNumericPadKeyMask                  = 1 << 21,
   NSHelpKeyMask                        = 1 << 22,
   NSFunctionKeyMask                    = 1 << 23,
   NSDeviceIndependentModifierFlagsMask = 0xffff0000U
};

@interface CocoaView (InputEvents)
@end
@implementation CocoaView (InputEvents)
float oldX, oldY;
bool dragging=false;

// In a view or view controller subclass:
- (BOOL)canBecomeFirstResponder
{
	return YES;
}

- (void)pressesBegan:(NSSet<UIPress *> *)touches withEvent:(UIPressesEvent *)event {
	for (int i = 0; i < touches.allObjects.count; i++) {
		UIKey *key = touches.allObjects[i].key;
		NSUInteger mods = key.modifierFlags;
		uint32_t mod       = 0;
		if (mods & NSAlphaShiftKeyMask)
			mod |= RETROKMOD_CAPSLOCK;
		if (mods & NSShiftKeyMask)
			mod |= RETROKMOD_SHIFT;
		if (mods & NSControlKeyMask)
			mod |= RETROKMOD_CTRL;
		if (mods & NSAlternateKeyMask)
			mod |= RETROKMOD_ALT;
		if (mods & NSCommandKeyMask)
			mod |= RETROKMOD_META;
		if (mods & NSNumericPadKeyMask)
			mod |= RETROKMOD_NUMLOCK;
        [_current processKeyPress:key.keyCode pressed:true];
        apple_input_keyboard_event(true,
		 (uint32_t)key.keyCode,
		 key.characters.length > 0 ? (uint32_t)[key.characters characterAtIndex:0] : 0,
		 mod,
		 RETRO_DEVICE_KEYBOARD);
	}
}

- (void)pressesEnded:(NSSet<UIPress *> *)touches withEvent:(UIPressesEvent *)event {
    for (int i = 0; i < touches.allObjects.count; i++) {
		UIKey *key = touches.allObjects[i].key;
		NSUInteger mods = key.modifierFlags;
		uint32_t mod       = 0;
		if (mods & NSAlphaShiftKeyMask)
			mod |= RETROKMOD_CAPSLOCK;
		if (mods & NSShiftKeyMask)
			mod |= RETROKMOD_SHIFT;
		if (mods & NSControlKeyMask)
			mod |= RETROKMOD_CTRL;
		if (mods & NSAlternateKeyMask)
			mod |= RETROKMOD_ALT;
		if (mods & NSCommandKeyMask)
			mod |= RETROKMOD_META;
		if (mods & NSNumericPadKeyMask)
			mod |= RETROKMOD_NUMLOCK;
        [_current processKeyPress:key.keyCode pressed:false];
        apple_input_keyboard_event(false,
		   (uint32_t)key.keyCode,
		   key.characters.length > 0 ? (uint32_t)[key.characters characterAtIndex:0] : 0,
		   mod,
		   RETRO_DEVICE_KEYBOARD);
	 }
}

-(void)handle_touch_event:(NSSet*) touches {
	handle_touch_event(touches.allObjects);
}
@end

void handle_touch_event(NSArray* touches) {
   cocoa_input_data_t *apple = (cocoa_input_data_t*)
      input_state_get_ptr()->current_data;
   float scale               = cocoa_screen_get_native_scale();
   if (!apple)
      return;
   apple->touch_count = 0;
   for (int i = 0; i < touches.count && (apple->touch_count < MAX_TOUCHES); i++) {
      UITouch      *touch = [touches objectAtIndex:i];
      CGPoint       coord = [touch locationInView:[touch view]];
      if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled) {
         apple->touches[apple->touch_count   ].screen_x = coord.x * scale;
         apple->touches[apple->touch_count ++].screen_y = coord.y * scale;
      }
   }
}

void handle_click_event(CGPoint click, bool pressed) {
   cocoa_input_data_t *apple = (cocoa_input_data_t*)input_state_get_ptr()->current_data;
   float scale = cocoa_screen_get_native_scale();
   if (!apple) return;
   apple->touch_count = 0;
   CGPoint coord = click;
   if (pressed) {
     apple->touches[apple->touch_count   ].screen_x = coord.x * scale;
     apple->touches[apple->touch_count ++].screen_y = coord.y * scale;
   }
}

/* cocoa input */


#if TARGET_OS_IPHONE
#define HIDKEY(X) X
#else
#define HIDKEY(X) (X < 128) ? MAC_NATIVE_TO_HID[X] : 0
#endif

#define MAX_ICADE_PROFILES 4
#define MAX_ICADE_KEYS     0x100

typedef struct icade_map
{
   bool up;
   enum retro_key key;
} icade_map_t;

/* TODO/FIXME -
 * fix game focus toggle */

/*
 * FORWARD DECLARATIONS
 */
#ifdef OSX
float cocoa_screen_get_backing_scale_factor(void);
#endif

#if TARGET_OS_IPHONE
/* TODO/FIXME - static globals */
static bool small_keyboard_active = false;
static icade_map_t icade_maps[MAX_ICADE_PROFILES][MAX_ICADE_KEYS];
#if TARGET_OS_IOS && !TARGET_OS_TV
static UISelectionFeedbackGenerator *feedbackGenerator;
#endif
#endif

static bool apple_key_state[MAX_KEYS];

/* Send keyboard inputs directly using RETROK_* codes
 * Used by the iOS custom keyboard implementation */
void apple_direct_input_keyboard_event(bool down,
      unsigned code, uint32_t character, uint32_t mod, unsigned device)
{
    int apple_key              = rarch_keysym_lut[code];
    apple_key_state[apple_key] = down;
    input_keyboard_event(down,
          code,
          character, (enum retro_mod)mod, device);
}

void apple_init_small_keyboard() {
    settings_t *settings         = config_get_ptr();
    settings->bools.input_small_keyboard_enable = true;
}
#if TARGET_OS_IPHONE
static bool apple_input_handle_small_keyboard(unsigned* code, bool down)
{
   static uint8_t mapping[128];
   static bool map_initialized;
   static const struct { uint8_t orig; uint8_t mod; } mapping_def[] =
   {
      { KEY_Grave,      KEY_Escape     }, { KEY_1,          KEY_F1         },
      { KEY_2,          KEY_F2         }, { KEY_3,          KEY_F3         },
      { KEY_4,          KEY_F4         }, { KEY_5,          KEY_F5         },
      { KEY_6,          KEY_F6         }, { KEY_7,          KEY_F7         },
      { KEY_8,          KEY_F8         }, { KEY_9,          KEY_F9         },
      { KEY_0,          KEY_F10        }, { KEY_Minus,      KEY_F11        },
      { KEY_Equals,     KEY_F12        }, { KEY_Up,         KEY_PageUp     },
      { KEY_Down,       KEY_PageDown   }, { KEY_Left,       KEY_Home       },
      { KEY_Right,      KEY_End        }, { KEY_Q,          KP_7           },
      { KEY_W,          KP_8           }, { KEY_E,          KP_9           },
      { KEY_A,          KP_4           }, { KEY_S,          KP_5           },
      { KEY_D,          KP_6           }, { KEY_Z,          KP_1           },
      { KEY_X,          KP_2           }, { KEY_C,          KP_3           },
      { 0 }
   };
   unsigned translated_code  = 0;

   if (!map_initialized)
   {
      int i;
      for (i = 0; mapping_def[i].orig; i ++)
         mapping[mapping_def[i].orig] = mapping_def[i].mod;
      map_initialized = true;
   }

   if (*code == KEY_RightShift)
   {
      small_keyboard_active = down;
      *code = 0;
      return true;
   }

   if (*code < 128)
      translated_code = mapping[*code];

   /* Allow old keys to be released. */
   if (!down && apple_key_state[*code])
      return false;

   if ((!down && apple_key_state[translated_code]) ||
         small_keyboard_active)
   {
      *code = translated_code;
      return true;
   }

   return false;
}

static bool apple_input_handle_icade_event(unsigned kb_type_idx, unsigned *code, bool *keydown)
{
   static bool initialized = false;
   bool ret                = false;

   if (!initialized)
   {
      unsigned i;
      unsigned j = 0;

      for (j = 0; j < MAX_ICADE_PROFILES; j++)
      {
         for (i = 0; i < MAX_ICADE_KEYS; i++)
         {
            icade_maps[j][i].key = RETROK_UNKNOWN;
            icade_maps[j][i].up  = false;
         }
      }

      /* iPega PG-9017 */
      j = 1;

      icade_maps[j][rarch_keysym_lut[RETROK_a]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_d]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_e]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_w]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_x]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_u]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_i]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_j]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_k]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_h]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_y]].key = RETROK_s;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].key = RETROK_s;

      icade_maps[j][rarch_keysym_lut[RETROK_e]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].up  = true;

      /* 8-bitty */
      j = 2;

      icade_maps[j][rarch_keysym_lut[RETROK_a]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_d]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_e]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_w]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_x]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_h]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_j]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_i]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_k]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_y]].key = RETROK_RSHIFT;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].key = RETROK_RSHIFT;
      icade_maps[j][rarch_keysym_lut[RETROK_u]].key = RETROK_RETURN;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].key = RETROK_RETURN;
      icade_maps[j][rarch_keysym_lut[RETROK_l]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_v]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_o]].key = RETROK_s;
      icade_maps[j][rarch_keysym_lut[RETROK_g]].key = RETROK_s;

      icade_maps[j][rarch_keysym_lut[RETROK_e]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_v]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_g]].up  = true;

      /* SNES30 8bitDo */
      j = 3;

      icade_maps[j][rarch_keysym_lut[RETROK_e]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_w]].key = RETROK_UP;
      icade_maps[j][rarch_keysym_lut[RETROK_x]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].key = RETROK_DOWN;
      icade_maps[j][rarch_keysym_lut[RETROK_a]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].key = RETROK_LEFT;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_d]].key = RETROK_RIGHT;
      icade_maps[j][rarch_keysym_lut[RETROK_u]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].key = RETROK_x;
      icade_maps[j][rarch_keysym_lut[RETROK_h]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].key = RETROK_z;
      icade_maps[j][rarch_keysym_lut[RETROK_y]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].key = RETROK_a;
      icade_maps[j][rarch_keysym_lut[RETROK_j]].key = RETROK_s;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].key = RETROK_s;
      icade_maps[j][rarch_keysym_lut[RETROK_k]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].key = RETROK_q;
      icade_maps[j][rarch_keysym_lut[RETROK_i]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].key = RETROK_w;
      icade_maps[j][rarch_keysym_lut[RETROK_l]].key = RETROK_RSHIFT;
      icade_maps[j][rarch_keysym_lut[RETROK_v]].key = RETROK_RSHIFT;
      icade_maps[j][rarch_keysym_lut[RETROK_o]].key = RETROK_RETURN;
      icade_maps[j][rarch_keysym_lut[RETROK_g]].key = RETROK_RETURN;

      icade_maps[j][rarch_keysym_lut[RETROK_v]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_g]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_e]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_z]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_q]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_c]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_r]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_f]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_n]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_t]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_p]].up  = true;
      icade_maps[j][rarch_keysym_lut[RETROK_m]].up  = true;

      initialized = true;
   }

   if ((*code < 0x20) && (icade_maps[kb_type_idx][*code].key != RETROK_UNKNOWN))
   {
      *keydown     = icade_maps[kb_type_idx][*code].up ? false : true;
      ret          = true;
      *code        = rarch_keysym_lut[icade_maps[kb_type_idx][*code].key];
   }

   return ret;
}

void apple_input_keyboard_event(bool down,
      unsigned code, uint32_t character, uint32_t mod, unsigned device)
{
   settings_t *settings         = config_get_ptr();
   bool keyboard_gamepad_enable = settings->bools.input_keyboard_gamepad_enable;
   bool small_keyboard_enable   = settings->bools.input_small_keyboard_enable;

   if (keyboard_gamepad_enable)
   {
      if (apple_input_handle_icade_event(
               settings->uints.input_keyboard_gamepad_mapping_type,
               &code, &down))
         character = 0;
      else
         code      = 0;
   }
   else if (small_keyboard_enable)
   {
      if (apple_input_handle_small_keyboard(&code, down))
         character = 0;
   }

   if (code == 0 || code >= MAX_KEYS)
      return;

   apple_key_state[code] = down;

   input_keyboard_event(down,
         input_keymaps_translate_keysym_to_rk(code),
         character, (enum retro_mod)mod, device);
}
#else
void apple_input_keyboard_event(bool down,
      unsigned code, uint32_t character, uint32_t mod, unsigned device)
{
   /* Taken from https://github.com/depp/keycode,
    * check keycode.h for license. */
   static const unsigned char MAC_NATIVE_TO_HID[128] = {
      4, 22,  7,  9, 11, 10, 29, 27,  6, 25,255,  5, 20, 26,  8, 21,
      28, 23, 30, 31, 32, 33, 35, 34, 46, 38, 36, 45, 37, 39, 48, 18,
      24, 47, 12, 19, 40, 15, 13, 52, 14, 51, 49, 54, 56, 17, 16, 55,
      43, 44, 53, 42,255, 41,231,227,225, 57,226,224,229,230,228,255,
      108, 99,255, 85,255, 87,255, 83,255,255,255, 84, 88,255, 86,109,
      110,103, 98, 89, 90, 91, 92, 93, 94, 95,111, 96, 97,255,255,255,
      62, 63, 64, 60, 65, 66,255, 68,255,104,107,105,255, 67,255, 69,
      255,106,117, 74, 75, 76, 61, 77, 59, 78, 58, 80, 79, 81, 82,255
   };
   code                  = HIDKEY(code);
   if (code == 0 || code >= MAX_KEYS)
      return;

   apple_key_state[code] = down;

   input_keyboard_event(down,
         input_keymaps_translate_keysym_to_rk(code),
         character, (enum retro_mod)mod, device);
}
#endif

static void *cocoa_input_init(const char *joypad_driver)
{
   cocoa_input_data_t *apple = NULL;
#ifdef HAVE_COREMOTION
   if (@available(macOS 10.15, *))
      if (!motionManager)
         motionManager = [[CMMotionManager alloc] init];
#endif

#if TARGET_OS_IOS && !TARGET_OS_TV
   if (!feedbackGenerator)
      feedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];
   [feedbackGenerator prepare];
#endif

   /* TODO/FIXME - shouldn't we free the above in case this fails for
    * TARGET_OS_IOS / HAVE_COREMOTION? */
   if (!(apple = (cocoa_input_data_t*)calloc(1, sizeof(*apple))))
      return NULL;

   input_keymaps_init_keyboard_lut(rarch_key_map_apple_hid);

   return apple;
}

static void cocoa_input_poll(void *data)
{
   uint32_t i;
   cocoa_input_data_t *apple    = (cocoa_input_data_t*)data;
#ifndef IOS
   float   backing_scale_factor = cocoa_screen_get_backing_scale_factor();
#else
   int     backing_scale_factor = 1;
#endif

    if (!apple)
       return;

    apple->mouse_rel_x = apple->window_pos_x - apple->mouse_x_last;
    apple->mouse_x_last = apple->window_pos_x;

    apple->mouse_rel_y = apple->window_pos_y - apple->mouse_y_last;
    apple->mouse_y_last = apple->window_pos_y;

    for (i = 0; i < apple->touch_count || i == 0; i++)
    {
       struct video_viewport vp;

       memset(&vp, 0, sizeof(vp));

       video_driver_translate_coord_viewport_confined_wrap(
             &vp,
             apple->touches[i].screen_x * backing_scale_factor,
             apple->touches[i].screen_y * backing_scale_factor,
             &apple->touches[i].confined_x,
             &apple->touches[i].confined_y,
             &apple->touches[i].full_x,
             &apple->touches[i].full_y);

       video_driver_translate_coord_viewport_wrap(
             &vp,
             apple->touches[i].screen_x * backing_scale_factor,
             apple->touches[i].screen_y * backing_scale_factor,
             &apple->touches[i].fixed_x,
             &apple->touches[i].fixed_y,
             &apple->touches[i].full_x,
             &apple->touches[i].full_y);
    }
}

static int16_t cocoa_input_state(
      void *data,
      const input_device_driver_t *joypad,
      const input_device_driver_t *sec_joypad,
      rarch_joypad_info_t *joypad_info,
      const retro_keybind_set *binds,
      bool keyboard_mapping_blocked,
      unsigned port,
      unsigned device,
      unsigned idx,
      unsigned id)
{
   cocoa_input_data_t *apple = (cocoa_input_data_t*)data;

   switch (device)
   {
      case RETRO_DEVICE_JOYPAD:
         if (id == RETRO_DEVICE_ID_JOYPAD_MASK)
         {
            unsigned i;
            /* Do a bitwise OR to combine both input
             * states together */
            int16_t ret = 0;

            if (!keyboard_mapping_blocked)
            {
               for (i = 0; i < RARCH_FIRST_CUSTOM_BIND; i++)
               {
                  if ((binds[port][i].key < RETROK_LAST)
                        && apple_key_state[rarch_keysym_lut[binds[port][i].key]])
                     ret |= (1 << i);
               }
            }
            return ret;
         }

         if (binds[port][id].valid)
         {
            if (id < RARCH_BIND_LIST_END)
               if (!keyboard_mapping_blocked || (id == RARCH_GAME_FOCUS_TOGGLE))
                  if (apple_key_state[rarch_keysym_lut[binds[port][id].key]])
                     return 1;

         }
         break;
      case RETRO_DEVICE_ANALOG:
         {
            int16_t ret           = 0;
            int id_minus_key      = 0;
            int id_plus_key       = 0;
            unsigned id_minus     = 0;
            unsigned id_plus      = 0;
            bool id_plus_valid    = false;
            bool id_minus_valid   = false;

            input_conv_analog_id_to_bind_id(idx, id, id_minus, id_plus);

            id_minus_valid        = binds[port][id_minus].valid;
            id_plus_valid         = binds[port][id_plus].valid;
            id_minus_key          = binds[port][id_minus].key;
            id_plus_key           = binds[port][id_plus].key;

            if (id_plus_valid && id_plus_key < RETROK_LAST)
            {
               if (apple_key_state[rarch_keysym_lut[(enum retro_key)id_plus_key]])
                  ret = 0x7fff;
            }
            if (id_minus_valid && id_minus_key < RETROK_LAST)
            {
               if (apple_key_state[rarch_keysym_lut[(enum retro_key)id_minus_key]])
                  ret += -0x7fff;
            }
            return ret;
         }
         break;

      case RETRO_DEVICE_KEYBOARD:
         return (id < RETROK_LAST) && apple_key_state[rarch_keysym_lut[(enum retro_key)id]];
      case RETRO_DEVICE_MOUSE:
      case RARCH_DEVICE_MOUSE_SCREEN:
         {
            int16_t val = 0;
            switch (id)
            {
               case RETRO_DEVICE_ID_MOUSE_X:
                  if (device == RARCH_DEVICE_MOUSE_SCREEN)
                  {
#ifdef IOS
                     return apple->window_pos_x;
#else
                     return apple->window_pos_x * cocoa_screen_get_backing_scale_factor();
#endif
                  }
#ifdef IOS
#ifdef HAVE_IOS_TOUCHMOUSE
                  if (apple->window_pos_x > 0)
                  {
                     val = apple->window_pos_x - apple->mouse_x_last;
                     apple->mouse_x_last = apple->window_pos_x;
                  }
                  else
                     val = apple->mouse_rel_x;
#else
                  val = apple->mouse_rel_x;
#endif
#else
                  val = apple->window_pos_x - apple->mouse_x_last;
                  apple->mouse_x_last = apple->window_pos_x;
#endif
                  return val;
               case RETRO_DEVICE_ID_MOUSE_Y:
                  if (device == RARCH_DEVICE_MOUSE_SCREEN)
                  {
#ifdef IOS
                     return apple->window_pos_y;
#else
                     return apple->window_pos_y * cocoa_screen_get_backing_scale_factor();
#endif
                  }
#ifdef IOS
#ifdef HAVE_IOS_TOUCHMOUSE
                  if (apple->window_pos_y > 0)
                  {
                     val = apple->window_pos_y - apple->mouse_y_last;
                     apple->mouse_y_last = apple->window_pos_y;
                  }
                  else
                     val = apple->mouse_rel_y;
#else
                  val    = apple->mouse_rel_y;
#endif
#else
                  val = apple->window_pos_y - apple->mouse_y_last;
                  apple->mouse_y_last = apple->window_pos_y;
#endif
                  return val;
               case RETRO_DEVICE_ID_MOUSE_LEFT:
                  return apple->mouse_buttons & 1;
               case RETRO_DEVICE_ID_MOUSE_RIGHT:
                  return apple->mouse_buttons & 2;
               case RETRO_DEVICE_ID_MOUSE_WHEELUP:
                  return apple->mouse_wu;
               case RETRO_DEVICE_ID_MOUSE_WHEELDOWN:
                  return apple->mouse_wd;
               case RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELUP:
                  return apple->mouse_wl;
               case RETRO_DEVICE_ID_MOUSE_HORIZ_WHEELDOWN:
                  return apple->mouse_wr;
            }
         }
         break;
      case RETRO_DEVICE_POINTER:
      case RARCH_DEVICE_POINTER_SCREEN:
         {

            if (idx < apple->touch_count && (idx < MAX_TOUCHES))
            {
               const cocoa_touch_data_t *touch = (const cocoa_touch_data_t *)
                  &apple->touches[idx];

               if (touch)
               {
                  switch (id)
                  {
                     case RETRO_DEVICE_ID_POINTER_PRESSED:
                        if (device == RARCH_DEVICE_POINTER_SCREEN)
                           return (touch->full_x  != -0x8000) && (touch->full_y  != -0x8000); /* Inside? */
                        return    (touch->fixed_x != -0x8000) && (touch->fixed_y != -0x8000); /* Inside? */
                     case RETRO_DEVICE_ID_POINTER_X:
                        return (device == RARCH_DEVICE_POINTER_SCREEN) ? touch->full_x : touch->fixed_x;
                     case RETRO_DEVICE_ID_POINTER_Y:
                        return (device == RARCH_DEVICE_POINTER_SCREEN) ? touch->full_y : touch->fixed_y;
                     case RETRO_DEVICE_ID_POINTER_COUNT:
                        return apple->touch_count;
                  }
               }
            }
         }
         break;
   }

   return 0;
}

static void cocoa_input_free(void *data)
{
   unsigned i;
   cocoa_input_data_t *apple = (cocoa_input_data_t*)data;

   if (!apple || !data)
      return;

   for (i = 0; i < MAX_KEYS; i++)
      apple_key_state[i] = 0;

   free(apple);
}

static uint64_t cocoa_input_get_capabilities(void *data)
{
   return
        (1 << RETRO_DEVICE_JOYPAD)
      | (1 << RETRO_DEVICE_MOUSE)
      | (1 << RETRO_DEVICE_KEYBOARD)
      | (1 << RETRO_DEVICE_POINTER)
      | (1 << RETRO_DEVICE_ANALOG);
}

static bool cocoa_input_set_sensor_state(void *data, unsigned port,
      enum retro_sensor_action action, unsigned rate)
{
   if (   (action != RETRO_SENSOR_ACCELEROMETER_ENABLE)
       && (action != RETRO_SENSOR_ACCELEROMETER_DISABLE)
       && (action != RETRO_SENSOR_GYROSCOPE_ENABLE)
       && (action != RETRO_SENSOR_GYROSCOPE_DISABLE))
      return false;

#ifdef HAVE_MFI
   if (@available(iOS 14.0, macOS 11.0, *))
   {
      for (GCController *controller in [GCController controllers])
      {
         if (!controller || controller.playerIndex != port)
            continue;
         if (!controller.motion)
            break;
         if (controller.motion.sensorsRequireManualActivation)
         {
            /* This is a bug, we assume if you turn on/off either
             * you want both on/off */
            if (     (action == RETRO_SENSOR_ACCELEROMETER_ENABLE)
                  || (action == RETRO_SENSOR_GYROSCOPE_ENABLE))
               controller.motion.sensorsActive = YES;
            else
               controller.motion.sensorsActive = NO;
         }
         /* no such thing as update interval for GCController? */
         return true;
      }
   }
#endif

#ifdef HAVE_COREMOTION
   if (port != 0)
      return false;

   if (!motionManager || !motionManager.deviceMotionAvailable)
      return false;

   if (     (action == RETRO_SENSOR_ACCELEROMETER_ENABLE)
         || (action == RETRO_SENSOR_GYROSCOPE_ENABLE))
   {
      if (!motionManager.deviceMotionActive)
         [motionManager startDeviceMotionUpdates];
      motionManager.deviceMotionUpdateInterval = 1.0f / (float)rate;
   }
   else
   {
      if (motionManager.deviceMotionActive)
         [motionManager stopDeviceMotionUpdates];
   }

   return true;
#else
   return false;
#endif
}

static float cocoa_input_get_sensor_input(void *data, unsigned port, unsigned id)
{
#ifdef HAVE_MFI
   if (@available(iOS 14.0, *))
   {
      for (GCController *controller in [GCController controllers])
      {
         if (!controller || controller.playerIndex != port)
            continue;
         if (!controller.motion)
            break;
         switch (id)
         {
            case RETRO_SENSOR_ACCELEROMETER_X:
               return controller.motion.userAcceleration.x;
            case RETRO_SENSOR_ACCELEROMETER_Y:
               return controller.motion.userAcceleration.y;
            case RETRO_SENSOR_ACCELEROMETER_Z:
               return controller.motion.userAcceleration.z;
            case RETRO_SENSOR_GYROSCOPE_X:
               return controller.motion.rotationRate.x;
            case RETRO_SENSOR_GYROSCOPE_Y:
               return controller.motion.rotationRate.y;
            case RETRO_SENSOR_GYROSCOPE_Z:
               return controller.motion.rotationRate.z;
         }
      }
   }
#endif

#ifdef HAVE_COREMOTION
   if (port == 0 && motionManager && motionManager.deviceMotionActive)
   {
      switch (id)
      {
         case RETRO_SENSOR_ACCELEROMETER_X:
            return motionManager.deviceMotion.userAcceleration.x;
         case RETRO_SENSOR_ACCELEROMETER_Y:
            return motionManager.deviceMotion.userAcceleration.y;
         case RETRO_SENSOR_ACCELEROMETER_Z:
            return motionManager.deviceMotion.userAcceleration.z;
         case RETRO_SENSOR_GYROSCOPE_X:
            return motionManager.deviceMotion.rotationRate.x;
         case RETRO_SENSOR_GYROSCOPE_Y:
            return motionManager.deviceMotion.rotationRate.y;
         case RETRO_SENSOR_GYROSCOPE_Z:
            return motionManager.deviceMotion.rotationRate.z;
      }
   }
#endif

   return 0.0f;
}

#if TARGET_OS_IOS
static void cocoa_input_keypress_vibrate(void)
{
#if !TARGET_OS_TV
   [feedbackGenerator selectionChanged];
   [feedbackGenerator prepare];
#endif
}
#endif

#ifdef OSX
static void cocoa_input_grab_mouse(void *data, bool state)
{
   cocoa_input_data_t *apple = (cocoa_input_data_t*)data;

   if (state)
   {
      NSWindow *window      = (BRIDGE NSWindow*)ui_companion_cocoa.get_main_window(nil);
      CGPoint window_pos    = window.frame.origin;
      CGSize window_size    = window.frame.size;
      CGPoint window_center = CGPointMake(window_pos.x + window_size.width / 2.0f, window_pos.y + window_size.height / 2.0f);
      CGWarpMouseCursorPosition(window_center);
   }

   CGAssociateMouseAndMouseCursorPosition(!state);
   cocoa_show_mouse(nil, !state);
   apple->mouse_grabbed = state;
}
#elif TARGET_OS_IOS
static void cocoa_input_grab_mouse(void *data, bool state)
{
   cocoa_input_data_t *apple = (cocoa_input_data_t*)data;

   apple->mouse_grabbed = state;

   if (@available(iOS 14, *))
      [[CocoaView get] setNeedsUpdateOfPrefersPointerLocked];
}
#endif

input_driver_t input_cocoa = {
   cocoa_input_init,
   cocoa_input_poll,
   cocoa_input_state,
   cocoa_input_free,
   cocoa_input_set_sensor_state,
   cocoa_input_get_sensor_input,
   cocoa_input_get_capabilities,
   "cocoa",
#if defined(OSX) || TARGET_OS_IOS
   cocoa_input_grab_mouse,
#else
   NULL,                         /* grab_mouse */
#endif
   NULL,                         /* grab_stdin */
#if TARGET_OS_IOS
   cocoa_input_keypress_vibrate
#else
   NULL                          /* vibrate */
#endif
};
