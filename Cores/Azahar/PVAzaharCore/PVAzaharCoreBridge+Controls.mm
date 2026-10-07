#import "PVAzaharCoreBridge.h"
#import "PVAzaharCoreBridge+Private.h"
#import "PVAzaharCoreBridge+Video.h"
@import PVCoreBridge;
#include "Glue/AzaharInput.h"
#include "common/settings.h"
#include "core/core.h"

static int NativeButtonFor(PV3DSButton button) {
    using namespace Settings::NativeButton;
    switch (button) {
        case PV3DSButtonUp: return Up;       case PV3DSButtonDown: return Down;
        case PV3DSButtonLeft: return Left;   case PV3DSButtonRight: return Right;
        case PV3DSButtonA: return A;         case PV3DSButtonB: return B;
        case PV3DSButtonX: return X;         case PV3DSButtonY: return Y;
        case PV3DSButtonL: return L;         case PV3DSButtonR: return R;
        case PV3DSButtonZl: return ZL;       case PV3DSButtonZr: return ZR;
        case PV3DSButtonStart: return Start; case PV3DSButtonSelect: return Select;
        case PV3DSButtonHome: return Home;
        default: return -1;
    }
}

/// Default -> Single -> Large -> Side -> Hybrid -> Default. SeparateWindows and CustomLayout are not
/// reachable from the UI, so a stray value falls back to Default.
static Settings::LayoutOption NextLayout(Settings::LayoutOption current) {
    using L = Settings::LayoutOption;
    switch (current) {
        case L::Default: return L::SingleScreen;
        case L::SingleScreen: return L::LargeScreen;
        case L::LargeScreen: return L::SideScreen;
        case L::SideScreen: return L::HybridScreen;
        default: return L::Default;
    }
}

// The protocol methods are declared by the primary class's conformance but, by design, defined here.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
@implementation PVAzaharCoreBridge (Controls)

/// Layout settings are read by the emu thread, so the write and ApplySettings happen there; the
/// window relayout is queued behind it.
- (void)changeLayoutOnEmuThread:(std::function<void()>)change {
    [self runOnEmuThread:[change = std::move(change)] {
        change();
        Core::System::GetInstance().ApplySettings();
    }];
    [self relayoutWindow];
}

/// ButtonResponder requirement; this core takes input through the 3DS methods below, not a gamepad handler.
- (GCExtendedGamepadValueChangedHandler)valueChangedHandler { return nil; }

- (void)didPush3DSButton:(PV3DSButton)button forPlayer:(NSInteger)player {
    switch (button) {
        case PV3DSButtonSwap:
            [self changeLayoutOnEmuThread:[] {
                Settings::values.swap_screen.SetValue(!Settings::values.swap_screen.GetValue());
            }];
            return;
        case PV3DSButtonRotate:
            [self changeLayoutOnEmuThread:[] {
                Settings::values.layout_option.SetValue(NextLayout(Settings::values.layout_option.GetValue()));
            }];
            return;
        case PV3DSButtonAnalogMode: _leftStickDrivesCStick = !_leftStickDrivesCStick; return;
        // Digital analog directions (keyboard/skin D-pad style)
        case PV3DSButtonLeftAnalogUp:    AzaharInput::SetAnalog(Settings::NativeAnalog::CirclePad, 0, 1); return;
        case PV3DSButtonLeftAnalogDown:  AzaharInput::SetAnalog(Settings::NativeAnalog::CirclePad, 0, -1); return;
        case PV3DSButtonLeftAnalogLeft:  AzaharInput::SetAnalog(Settings::NativeAnalog::CirclePad, -1, 0); return;
        case PV3DSButtonLeftAnalogRight: AzaharInput::SetAnalog(Settings::NativeAnalog::CirclePad, 1, 0); return;
        case PV3DSButtonRightAnalogUp:    AzaharInput::SetAnalog(Settings::NativeAnalog::CStick, 0, 1); return;
        case PV3DSButtonRightAnalogDown:  AzaharInput::SetAnalog(Settings::NativeAnalog::CStick, 0, -1); return;
        case PV3DSButtonRightAnalogLeft:  AzaharInput::SetAnalog(Settings::NativeAnalog::CStick, -1, 0); return;
        case PV3DSButtonRightAnalogRight: AzaharInput::SetAnalog(Settings::NativeAnalog::CStick, 1, 0); return;
        default: break;
    }
    const int native = NativeButtonFor(button);
    if (native >= 0) { AzaharInput::SetButton(native, true); }
}

- (void)didRelease3DSButton:(PV3DSButton)button forPlayer:(NSInteger)player {
    switch (button) {
        case PV3DSButtonLeftAnalogUp: case PV3DSButtonLeftAnalogDown:
        case PV3DSButtonLeftAnalogLeft: case PV3DSButtonLeftAnalogRight:
            AzaharInput::SetAnalog(Settings::NativeAnalog::CirclePad, 0, 0); return;
        case PV3DSButtonRightAnalogUp: case PV3DSButtonRightAnalogDown:
        case PV3DSButtonRightAnalogLeft: case PV3DSButtonRightAnalogRight:
            AzaharInput::SetAnalog(Settings::NativeAnalog::CStick, 0, 0); return;
        default: break;
    }
    const int native = NativeButtonFor(button);
    if (native >= 0) { AzaharInput::SetButton(native, false); }
}

- (void)didMove3DSJoystickDirection:(PV3DSButton)button withXValue:(CGFloat)x withYValue:(CGFloat)y forPlayer:(NSInteger)player {
    // PV gives y with +1 = up; azahar's analog also uses +1 = up.
    switch (button) {
        case PV3DSButtonLeftAnalog:
            AzaharInput::SetAnalog(_leftStickDrivesCStick ? Settings::NativeAnalog::CStick : Settings::NativeAnalog::CirclePad, (float)x, (float)y); break;
        case PV3DSButtonRightAnalog:
            AzaharInput::SetAnalog(Settings::NativeAnalog::CStick, (float)x, (float)y); break;
        default: break;
    }
}

- (void)didMoveJoystick:(NSInteger)button withXValue:(CGFloat)x withYValue:(CGFloat)y forPlayer:(NSInteger)player {
    [self didMove3DSJoystickDirection:(PV3DSButton)button withXValue:x withYValue:y forPlayer:player];
}

@end
#pragma clang diagnostic pop
