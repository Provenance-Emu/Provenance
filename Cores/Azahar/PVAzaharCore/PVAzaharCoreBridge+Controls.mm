#import "PVAzaharCoreBridge.h"
#import "PVAzaharCoreBridge+Private.h"
#include "Glue/AzaharEmuWindow.h"
#include <algorithm>
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

/// Analog the left stick (analog or digital directions) currently drives; PV3DSButtonAnalogMode flips it.
static int LeftStickTarget(PVAzaharCoreBridge *bridge) {
    return bridge->_leftStickDrivesCStick ? Settings::NativeAnalog::CStick : Settings::NativeAnalog::CirclePad;
}

@interface PVAzaharCoreBridge (Controls) <PV3DSSystemResponderClient>
@end

@implementation PVAzaharCoreBridge (Controls)


/// ButtonResponder requirement; this core takes input through the 3DS methods below, not a gamepad handler.
- (GCExtendedGamepadValueChangedHandler)valueChangedHandler { return nil; }

- (void)didPush3DSButton:(PV3DSButton)button forPlayer:(NSInteger)player {
    switch (button) {
        // The relayout reads the bridge properties, so the toggles live there (not in Settings directly).
        case PV3DSButtonSwap:
            self.swapScreens = !self.swapScreens;
            [self relayoutWindow];
            return;
        case PV3DSButtonRotate:
            self.layoutOption = (self.layoutOption + 1) % 5;   // PVAzaharLayoutOption indices
            [self relayoutWindow];
            return;
        case PV3DSButtonAnalogMode:
            _leftStickDrivesCStick = !_leftStickDrivesCStick;
            AzaharInput::SetAnalog(Settings::NativeAnalog::CirclePad, 0, 0);   // a held stick must not stay latched
            AzaharInput::SetAnalog(Settings::NativeAnalog::CStick, 0, 0);
            return;
        // Digital analog directions (keyboard/skin D-pad style)
        case PV3DSButtonLeftAnalogUp:    AzaharInput::SetAnalog(LeftStickTarget(self), 0, 1); return;
        case PV3DSButtonLeftAnalogDown:  AzaharInput::SetAnalog(LeftStickTarget(self), 0, -1); return;
        case PV3DSButtonLeftAnalogLeft:  AzaharInput::SetAnalog(LeftStickTarget(self), -1, 0); return;
        case PV3DSButtonLeftAnalogRight: AzaharInput::SetAnalog(LeftStickTarget(self), 1, 0); return;
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
            AzaharInput::SetAnalog(LeftStickTarget(self), 0, 0); return;
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
            AzaharInput::SetAnalog(LeftStickTarget(self), (float)x, (float)y); break;
        case PV3DSButtonRightAnalog:
            AzaharInput::SetAnalog(Settings::NativeAnalog::CStick, (float)x, (float)y); break;
        default: break;
    }
}

- (void)didMoveJoystick:(NSInteger)button withXValue:(CGFloat)x withYValue:(CGFloat)y forPlayer:(NSInteger)player {
    [self didMove3DSJoystickDirection:(PV3DSButton)button withXValue:x withYValue:y forPlayer:player];
}

#pragma mark - Bottom-screen touch from skins (PV3DSSystemResponderClient)

/// `point` is in 3DS bottom-screen pixels (320x240). The window layout lives on the emu thread, so
/// the mapping to window pixels happens there against the current bottom-screen rect.
- (void)touchScreenAtPoint:(CGPoint)point {
    const float nx = (float)std::clamp<CGFloat>(point.x / 319.0, 0, 1);
    const float ny = (float)std::clamp<CGFloat>(point.y / 239.0, 0, 1);
    [self runOnEmuThread:[self, nx, ny] {
        if (!_window) { return; }
        const auto& bottom = _window->GetFramebufferLayout().bottom_screen;
        _window->Touch(true, bottom.left + nx * bottom.GetWidth(), bottom.top + ny * bottom.GetHeight());
    }];
}

- (void)releaseScreenTouch {
    [self runOnEmuThread:[self] { if (_window) { _window->Touch(false, 0, 0); } }];
}

@end
