#import <Foundation/Foundation.h>
#import <PVSupport/PVSupport.h>
#import <PVLogging/PVLogging.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVSupport/PVSupport-Swift.h>
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface PVRetroArchCore : PVEmulatorCore<PVRetroArchCoreResponderClient, UIApplicationDelegate> {
    int videoWidth;
    int videoHeight;
    int videoBitDepth;
    int8_t gsPreference;
    int8_t resFactor;
    float sampleRate;
    BOOL isNTSC;
    BOOL isRootView;
    UIView *m_view;
    UIViewController *m_view_controller;
    UIViewController *backup_view_controller;
    CAMetalLayer* m_metal_layer;
    CAEAGLLayer *m_gl_layer;
    NSString *romPath;
    CFRunLoopObserverRef iterate_observer;
    bool retroArchControls;
    bool bindAnalogKeys;
    bool hasSecondScreen;
    bool coreOptionOverwrite;
    NSString* coreOptionConfigPath;
    NSString* coreOptionConfig;
@public
    dispatch_queue_t _callbackQueue;
}
@property (nonatomic, assign) int videoWidth;
@property (nonatomic, assign) int videoHeight;
@property (nonatomic, assign) int videoBitDepth;
@property (nonatomic, assign) int8_t resFactor;
@property (nonatomic, assign) int8_t gsPreference;
@property (nonatomic, assign) int volume;
@property (nonatomic, assign) int ffSpeed;
@property (nonatomic, assign) int smSpeed;
@property (nonatomic, assign) bool isRootView;
@property (nonatomic, assign) bool retroArchControls;
@property (nonatomic, assign) bool hasTouchControls;
@property (nonatomic, assign) bool bindAnalogKeys;
@property (nonatomic, assign) bool bindNumKeys;
@property (nonatomic, assign) bool bindAnalogDpad;
@property (nonatomic, assign) bool hasSecondScreen;
@property (nonatomic, assign) int machineType;
@property (nonatomic) NSString* coreIdentifier;
@property (nonatomic) NSString* coreOptionConfigPath;
@property (nonatomic) NSString* coreOptionConfig;
@property (nonatomic) bool coreOptionOverwrite;
// Apple Platform (Libretro)
@property (nonatomic) UIView* view;
@property (nonatomic) UIWindow* window;
@property (nonatomic) NSString* documentsDirectory;
@property (nonatomic) int menu_count;
+ (PVRetroArchCore *)get;
- (void)showGameView;
- (void)supportOtherAudioSessions;
- (void)refreshSystemConfig;

/*! @brief renderView returns the current render view based on the viewType */
@property(readonly) id renderView;
/*! @brief isActive returns true if the application has focus */
@property(readonly) bool hasFocus;
/*! @brief setCursorVisible specifies whether the cursor is visible */
- (void)setCursorVisible:(bool)v;
/*! @brief controls whether the screen saver should be disabled and
 * the displays should not sleep.
 */
- (bool)setDisableDisplaySleep:(bool)disable;
- (void)setupMainWindow;
//
- (void) setupView;
- (void) setRootView:(BOOL)flag;
- (void) setupWindow;
- (void) refreshScreenSize;
- (void) startVM:(UIView *)view;
- (void) setupControllers;
- (void) pollControllers;
- (void) gamepadEventOnPad:(int)player button:(int)button action:(int)action;
- (void) gamepadEventIrRecenter:(int)action;
- (BOOL) setCheat:(NSString *)code setType:(NSString *)type setCodeType:(NSString *)codeType setIndex:(UInt8)cheatIndex setEnabled:(BOOL)enabled error:(NSError**)error;
- (void) useRetroArchController:(BOOL)flag;
- (void) controllerConnected:(NSNotification *)notification;
- (void) controllerDisconnected:(NSNotification *)notification;
- (void) processKeyPress:(int)key pressed:(bool)pressed;
- (void) setVolume;
- (void) setSpeed;
- (void) syncResources:(NSString*)from to:(NSString*)to;
- (void) setupJoypad;
@end

/* iOS UI */
#if TARGET_OS_TV
//#define HAVE_IOS_TOUCHMOUSE 0
#undef HAVE_IOS_TOUCHMOUSE
#define HAVE_COCOATOUCH 1
#define TARGET_OS_IOS 1
#define TARGET_OS_TVOS 1
#else
#define HAVE_IOS_TOUCHMOUSE 1
#define HAVE_COCOATOUCH 1
#define TARGET_OS_IOS 1
#endif
#define HAVE_IOS_SWIFT 1
#define HAVE_IOS_CUSTOMKEYBOARD 1

/* RetroArch cocoa_common */
#if defined(HAVE_COCOATOUCH)
#define RAScreen UIScreen

#ifndef UIUserInterfaceIdiomTV
#define UIUserInterfaceIdiomTV 2
#endif

#ifndef UIUserInterfaceIdiomCarPlay
#define UIUserInterfaceIdiomCarPlay 3
#endif

#if TARGET_OS_IOS
@class EmulatorKeyboardController;

#ifdef HAVE_IOS_TOUCHMOUSE
@class EmulatorTouchMouseHandler;
#endif

@interface CocoaView : UIViewController

#elif TARGET_OS_TV
@interface CocoaView : GCEventViewController
#endif

#if TARGET_OS_IOS && defined(HAVE_IOS_CUSTOMKEYBOARD)
@property(nonatomic,strong) EmulatorKeyboardController *keyboardController;
@property(nonatomic,assign) unsigned int keyboardModifierState;
-(void)toggleCustomKeyboard;
-(void)handle_touch_event:(NSSet*) touches;
#endif

#ifdef HAVE_IOS_TOUCHMOUSE
@property(nonatomic,strong) EmulatorTouchMouseHandler *mouseHandler;
#endif

#if defined(HAVE_IOS_SWIFT)
@property(nonatomic,strong) UIView *helperBarView;
#endif

+ (CocoaView*)get;
@end

void get_ios_version(int *major, int *minor);
#else
#define RAScreen NSScreen

@interface CocoaView : NSView

+ (CocoaView*)get;
#if !defined(HAVE_COCOA) && !defined(HAVE_COCOA_METAL)
- (void)display;
#endif

@end
#endif

typedef struct
{
	char orientations[32];
	unsigned orientation_flags;
	char bluetooth_mode[64];
} apple_frontend_settings_t;
extern apple_frontend_settings_t apple_frontend_settings;

#define BOXSTRING(x) [NSString stringWithUTF8String:x]
#define BOXINT(x)    [NSNumber numberWithInt:x]
#define BOXUINT(x)   [NSNumber numberWithUnsignedInt:x]
#define BOXFLOAT(x)  [NSNumber numberWithDouble:x]

#if defined(__clang__)
/* ARC is only available for Clang */
#if __has_feature(objc_arc)
#define RELEASE(x)   x = nil
#define BRIDGE       __bridge
#define UNSAFE_UNRETAINED __unsafe_unretained
#else
#define RELEASE(x)   [x release]; \
	x = nil
#define BRIDGE
#define UNSAFE_UNRETAINED
#endif
#else
/* On compilers other than Clang (e.g. GCC), assume ARC
	is going to be unavailable */
#define RELEASE(x)   [x release]; \
	x = nil
#define BRIDGE
#define UNSAFE_UNRETAINED
#endif

void get_ios_version(int *major, int *minor);
extern __weak PVRetroArchCore *_current;
#define RETRO_DEVICE_KEYBOARD 3
#ifndef KEYCODE_KEYCODE_H
#define KEYCODE_KEYCODE_H
#ifndef MAX_KEYS
#define MAX_KEYS     256
#endif
enum
{
	KEY_A = 4,
	KEY_B = 5,
	KEY_C = 6,
	KEY_D = 7,
	KEY_E = 8,
	KEY_F = 9,
	KEY_G = 10,
	KEY_H = 11,
	KEY_I = 12,
	KEY_J = 13,
	KEY_K = 14,
	KEY_L = 15,
	KEY_M = 16,
	KEY_N = 17,
	KEY_O = 18,
	KEY_P = 19,
	KEY_Q = 20,
	KEY_R = 21,
	KEY_S = 22,
	KEY_T = 23,
	KEY_U = 24,
	KEY_V = 25,
	KEY_W = 26,
	KEY_X = 27,
	KEY_Y = 28,
	KEY_Z = 29,
	KEY_1 = 30,
	KEY_2 = 31,
	KEY_3 = 32,
	KEY_4 = 33,
	KEY_5 = 34,
	KEY_6 = 35,
	KEY_7 = 36,
	KEY_8 = 37,
	KEY_9 = 38,
	KEY_0 = 39,
	KEY_Enter = 40,
	KEY_Escape = 41,
	KEY_Delete = 42,
	KEY_Tab = 43,
	KEY_Space = 44,
	KEY_Minus = 45,
	KEY_Equals = 46,
	KEY_LeftBracket = 47,
	KEY_RightBracket = 48,
	KEY_Backslash = 49,
	KEY_Semicolon = 51,
	KEY_Quote = 52,
	KEY_Grave = 53,
	KEY_Comma = 54,
	KEY_Period = 55,
	KEY_Slash = 56,
	KEY_CapsLock = 57,
	KEY_F1 = 58,
	KEY_F2 = 59,
	KEY_F3 = 60,
	KEY_F4 = 61,
	KEY_F5 = 62,
	KEY_F6 = 63,
	KEY_F7 = 64,
	KEY_F8 = 65,
	KEY_F9 = 66,
	KEY_F10 = 67,
	KEY_F11 = 68,
	KEY_F12 = 69,
	KEY_PrintScreen = 70,
	KEY_ScrollLock = 71,
	KEY_Pause = 72,
	KEY_Insert = 73,
	KEY_Home = 74,
	KEY_PageUp = 75,
	KEY_DeleteForward = 76,
	KEY_End = 77,
	KEY_PageDown = 78,
	KEY_Right = 79,
	KEY_Left = 80,
	KEY_Down = 81,
	KEY_Up = 82,
	KP_NumLock = 83,
	KP_Divide = 84,
	KP_Multiply = 85,
	KP_Subtract = 86,
	KP_Add = 87,
	KP_Enter = 88,
	KP_1 = 89,
	KP_2 = 90,
	KP_3 = 91,
	KP_4 = 92,
	KP_5 = 93,
	KP_6 = 94,
	KP_7 = 95,
	KP_8 = 96,
	KP_9 = 97,
	KP_0 = 98,
	KP_Point = 99,
	KEY_NonUSBackslash = 100,
	KP_Equals = 103,
	KEY_F13 = 104,
	KEY_F14 = 105,
	KEY_F15 = 106,
	KEY_F16 = 107,
	KEY_F17 = 108,
	KEY_F18 = 109,
	KEY_F19 = 110,
	KEY_F20 = 111,
	KEY_F21 = 112,
	KEY_F22 = 113,
	KEY_F23 = 114,
	KEY_F24 = 115,
	KEY_Help = 117,
	KEY_Menu = 118,
	KEY_LeftControl = 224,
	KEY_LeftShift = 225,
	KEY_LeftAlt = 226,
	KEY_LeftGUI = 227,
	KEY_RightControl = 228,
	KEY_RightShift = 229,
	KEY_RightAlt = 230,
	KEY_RightGUI = 231
};
void apple_input_keyboard_event(bool down,
		unsigned code, uint32_t character, uint32_t mod, unsigned device);
void apple_direct_input_keyboard_event(bool down,
		unsigned code, uint32_t character, uint32_t mod, unsigned device);
void apple_init_small_keyboard();
void menuToggle();
#endif

// Options
#define USE_SECOND_SCREEN "Move Display to Mirrored Display"
#define USE_RETROARCH_CONTROLLER "Use Retro Arch Controller Overlay"
#define ENABLE_ANALOG_KEY "Enable Keyboard Keys -> Joypad Controller Bindings"
#define ENABLE_NUM_KEY "Enable ZXCASDQWE/Arrow Keys -> Numpad Key Bindings"
#define ENABLE_ANALOG_DPAD "Enable Joypad Analog -> Dpad Bindings"
#define RETROARCH_PVOVERLAY "/RetroArch/overlays/pv_ui_overlay/pv_ui.cfg"
#define RETROARCH_DEFAULT_OVERLAY "/RetroArch/overlays/gamepads/neo-retropad/neo-retropad-clear.cfg"
