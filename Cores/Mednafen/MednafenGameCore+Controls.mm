//
//  MednafenMultiDisc.m
//  PVMednafen
//
//  Created by Joseph Mattiello on 2/18/18.
//

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wall"
#pragma clang diagnostic ignored "-Wextra"
#include <mednafen/mednafen.h>
#include <mednafen/settings-driver.h>
#include <mednafen/state-driver.h>
#include <mednafen/mednafen-driver.h>
#include <mednafen/MemoryStream.h>
#pragma clang diagnostic pop

#import "MednafenGameCore.h"

#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX
#import <OpenGLES/gltypes.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGL.h>
#else
#import <OpenGL/OpenGL.h>
#import <GLUT/GLUT.h>
#endif


#import <Foundation/Foundation.h>
#import <PVSupport/OERingBuffer.h>
#import <PVSupport/PVSupport-Swift.h>
#import <PVSupport/PVEmulatorCore.h>
#import <PVLogging/PVLogging.h>

#import <mednafen/mempatcher.h>
#import <PVMednafen/PVMednafen-Swift.h>

@implementation MednafenGameCore (Controls)

#pragma mark - Input -

//Controller Stacks start here:

#pragma mark Atari Lynx
- (void)didPushLynxButton:(PVLynxButton)button forPlayer:(NSInteger)player {
    inputBuffer[player][0] |= 1 << LynxMap[button];
}

- (void)didReleaseLynxButton:(PVLynxButton)button forPlayer:(NSInteger)player {
    inputBuffer[player][0] &= ~(1 << LynxMap[button]);
}

- (NSInteger)LynxControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVLynxButtonUp:
                return DPAD_PRESSED(up);
            case PVLynxButtonDown:
                return DPAD_PRESSED(down);
            case PVLynxButtonLeft:
                return DPAD_PRESSED(left);
            case PVLynxButtonRight:
                return DPAD_PRESSED(right);
            case PVLynxButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed]?:[[[gamepad rightThumbstick] right] isPressed]?:[[gamepad rightTrigger] isPressed];
            case PVLynxButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed]?:[[[gamepad rightThumbstick] left] isPressed]?:[[gamepad leftTrigger] isPressed];
            case PVLynxButtonOption1:
                return [[gamepad leftShoulder] isPressed];
            case PVLynxButtonOption2:
                return [[gamepad rightShoulder] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVLynxButtonUp:
                return [[dpad up] isPressed];
            case PVLynxButtonDown:
                return [[dpad down] isPressed];
            case PVLynxButtonLeft:
                return [[dpad left] isPressed];
            case PVLynxButtonRight:
                return [[dpad right] isPressed];
            case PVLynxButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVLynxButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVLynxButtonOption1:
                return [[gamepad leftShoulder] isPressed];
            case PVLynxButtonOption2:
                return [[gamepad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad]) {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVLynxButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVLynxButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVLynxButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVLynxButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVLynxButtonB:
                return [[gamepad buttonA] isPressed];
                break;
            case PVLynxButtonA:
                return [[gamepad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

#pragma mark SNES
- (void)didPushSNESButton:(enum PVSNESButton)button forPlayer:(NSInteger)player {
    int mappedButton = SNESMap[button];
    inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseSNESButton:(enum PVSNESButton)button forPlayer:(NSInteger)player {
    inputBuffer[player][0] &= ~(1 << SNESMap[button]);
}

#pragma mark NES
- (void)didPushNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player {
    int mappedButton = NESMap[button];
    inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseNESButton:(enum PVNESButton)button forPlayer:(NSInteger)player {
    inputBuffer[player][0] &= ~(1 << NESMap[button]);
}

#pragma mark GB / GBC
- (void)didPushGBButton:(enum PVGBButton)button forPlayer:(NSInteger)player {
    int mappedButton = GBMap[button];
    inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseGBButton:(enum PVGBButton)button forPlayer:(NSInteger)player {
    inputBuffer[player][0] &= ~(1 << GBMap[button]);
}

#pragma mark GBA
- (void)didPushGBAButton:(enum PVGBAButton)button forPlayer:(NSInteger)player {
    int mappedButton = GBAMap[button];
    inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseGBAButton:(enum PVGBAButton)button forPlayer:(NSInteger)player {
    int mappedButton = GBAMap[button];
    inputBuffer[player][0] &= ~(1 << mappedButton);
}

#pragma mark Sega
- (void)didPushSegaButton:(enum PVGenesisButton)button forPlayer:(NSInteger)player {
    int mappedButton = GenesisMap[button];
    inputBuffer[player][0] |= 1 << mappedButton;
}

-(void)didReleaseSegaButton:(enum PVGenesisButton)button forPlayer:(NSInteger)player {
    inputBuffer[player][0] &= ~(1 << GenesisMap[button]);
}

#pragma mark Neo Geo
- (void)didPushNGPButton:(PVNGPButton)button forPlayer:(NSInteger)player
{
    inputBuffer[player][0] |= 1 << NeoMap[button];
}

- (void)didReleaseNGPButton:(PVNGPButton)button forPlayer:(NSInteger)player
{
    inputBuffer[player][0] &= ~(1 << NeoMap[button]);
}

#pragma mark PC-*
#pragma mark PCE aka TurboGFX-16 & SuperGFX
- (void)didPushPCEButton:(PVPCEButton)button forPlayer:(NSInteger)player
{
    if (button != PVPCEButtonMode) { // Check for six button mode toggle
        inputBuffer[player][0] |= 1 << PCEMap[button];
    } else {
        inputBuffer[player][0] ^= 1 << PCEMap[button];
    }
}

- (void)didReleasePCEButton:(PVPCEButton)button forPlayer:(NSInteger)player
{
    if (button != PVPCEButtonMode)
        inputBuffer[player][0] &= ~(1 << PCEMap[button]);
}

#pragma mark PCE-CD
- (void)didPushPCECDButton:(PVPCECDButton)button forPlayer:(NSInteger)player
{
    if (button != PVPCECDButtonMode) { // Check for six button mode toggle
        inputBuffer[player][0] |= 1 << PCEMap[button];
    } else {
        inputBuffer[player][0] ^= 1 << PCEMap[button];
    }
}

- (void)didReleasePCECDButton:(PVPCECDButton)button forPlayer:(NSInteger)player;
{
    if (button != PVPCECDButtonMode) {
        inputBuffer[player][0] &= ~(1 << PCEMap[button]);
    }
}

#pragma mark PCFX
- (void)didPushPCFXButton:(PVPCFXButton)button forPlayer:(NSInteger)player;
{
    if (button != PVPCFXButtonMode) { // Check for six button mode toggle
        inputBuffer[player][0] |= 1 << PCFXMap[button];
    } else {
        inputBuffer[player][0] ^= 1 << PCFXMap[button];
    }
}

- (void)didReleasePCFXButton:(PVPCFXButton)button forPlayer:(NSInteger)player;
{
    if (button != PVPCFXButtonMode) {
        inputBuffer[player][0] &= ~(1 << PCFXMap[button]);
    }
}

#pragma mark SS Sega Saturn
- (void)didMoveSaturnJoystickDirection:(PVSaturnButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    static float xAxis=0;
    static float yAxis=0;
    static float axisRounding = 0.66;
    yAxis =  yValue > axisRounding ? 1.0 : yValue < -axisRounding ? -1.0 : 0;
    xAxis =  xValue > axisRounding ? 1.0 : xValue < -axisRounding ? -1.0 : 0;
    if (yAxis < 0)
        [self didPushSSButton:PVSaturnButtonDown forPlayer:player];
    else if (yAxis > 0)
        [self didPushSSButton:PVSaturnButtonUp forPlayer:player];
    else {
        [self didReleaseSSButton:PVSaturnButtonDown forPlayer:player];
        [self didReleaseSSButton:PVSaturnButtonUp forPlayer:player];
    }
    if (xAxis > 0)
        [self didPushSSButton:PVSaturnButtonRight forPlayer:player];
    else if (xAxis < 0)
        [self didPushSSButton:PVSaturnButtonLeft forPlayer:player];
    else {
        [self didReleaseSSButton:PVSaturnButtonRight forPlayer:player];
        [self didReleaseSSButton:PVSaturnButtonLeft forPlayer:player];
    }
}
- (void)didPushSSButton:(enum PVSaturnButton)button forPlayer:(NSInteger)player
{
    //    int mappedButton = SSMap[button];
    //    inputBuffer[player][0] |= 1 << mappedButton;
    if (button == PVSaturnButtonStart) {
        DLOG("Start on");
        self.isStartPressed = true;
    }
    inputBuffer[player][0] |= 1 << SSMap[button];
}

-(void)didReleaseSSButton:(enum PVSaturnButton)button forPlayer:(NSInteger)player {
    //    inputBuffer[player][0] &= ~(1 << SSMap[button]);
    if (button == PVSaturnButtonStart) {
        DLOG("Start off");
        self.isStartPressed = false;
    }
    inputBuffer[player][0] &= ~(1 << SSMap[button]);
}

#pragma mark PSX
- (void)didPushPSXButton:(PVPSXButton)button forPlayer:(NSInteger)player;
{
    if (button == PVPSXButtonStart) {
        self.isStartPressed = true;
    } else if (button == PVPSXButtonSelect) {
        self.isSelectPressed = true;
    } else if (button == PVPSXButtonL3) {
        self.isL3Pressed = true;
    } else if (button == PVPSXButtonR3) {
        self.isR3Pressed = true;
    } else if (button == PVPSXButtonAnalogMode) {
        self.isAnalogModePressed = true;
    }
    inputBuffer[player][0] |= 1 << PSXMap[button];
}

- (void)didReleasePSXButton:(PVPSXButton)button forPlayer:(NSInteger)player;
{
    if (button == PVPSXButtonStart) {
        self.isStartPressed = false;
    } else if (button == PVPSXButtonSelect) {
        self.isSelectPressed = false;
    } else if (button == PVPSXButtonL3) {
        self.isL3Pressed = false;
    } else if (button == PVPSXButtonR3) {
        self.isR3Pressed = false;
    } else if (button == PVPSXButtonAnalogMode) {
        self.isAnalogModePressed = false;
    }
    inputBuffer[player][0] &= ~(1 << PSXMap[button]);
}

- (void)didMovePSXJoystickDirection:(PVPSXButton)button withXValue:(CGFloat)xValue withYValue:(CGFloat)yValue forPlayer:(NSInteger)player {
    // TODO
    // Fix the analog circle-to-square axis range conversion by scaling between a value of 1.00 and 1.50
    // We cannot use MDFNI_SetSetting("psx.input.port1.dualshock.axis_scale", "1.33") directly.
    // Background: https://mednafen.github.io/documentation/psx.html#Section_analog_range
    // double scaledValue = MIN(floor(0.5 + value * 1.33), 32767); // 30712 / cos(2*pi/8) / 32767 = 1.33
    float up = yValue > 0 ? fabs(yValue) : 0.0;
    float down = yValue < 0 ? fabs(yValue) : 0.0;
    float left = xValue < 0 ? fabs(xValue) : 0.0;
    float right = xValue > 0 ? fabs(xValue) : 0.0;
    
    up = fmin(up, 1.0);
    down = fmin(down, 1.0);
    left = fmin(left, 1.0);
    right = fmin(right, 1.0);

    up = fmax(up, 0.0);
    down = fmax(down, 0.0);
    left = fmax(left, 0.0);
    right = fmax(right, 0.0);
    
    NSDictionary *buttons = @{ @(PVPSXButtonLeftAnalogUp):@(up),
                               @(PVPSXButtonLeftAnalogDown):@(down),
                               @(PVPSXButtonLeftAnalogLeft):@(left),
                               @(PVPSXButtonLeftAnalogRight):@(right) };
    
    for (NSNumber *key in buttons) {
        int button = [(NSNumber *)key intValue];
        float value = [(NSNumber *)[buttons objectForKey:key] floatValue];
        
        uint16 modifiedValue = value * 32767;
        
        int analogNumber = PSXMap[button] - 17;
        int address = analogNumber;
        
        if (analogNumber % 2 != 0) {
            axis[analogNumber] = -1 * modifiedValue;
            address -= 1;
        }
        else {
            axis[analogNumber] = modifiedValue;
        }
        
        uint16 actualValue = 32767 + axis[analogNumber] + axis[analogNumber ^ 1];
        
        uint8 *buf = (uint8 *)inputBuffer[player];
        Mednafen::MDFN_en16lsb(&buf[3]+address, (uint16) actualValue);
    }
}

#pragma mark Virtual Boy
- (void)didPushVBButton:(PVVBButton)button forPlayer:(NSInteger)player;
{
    inputBuffer[player][0] |= 1 << VBMap[button];
}

- (void)didReleaseVBButton:(PVVBButton)button forPlayer:(NSInteger)player;
{
    inputBuffer[player][0] &= ~(1 << VBMap[button]);
}

#pragma mark WonderSwan
- (void)didPushWSButton:(PVWSButton)button forPlayer:(NSInteger)player;
{
    inputBuffer[player][0] |= 1 << WSMap[button];
}

- (void)didReleaseWSButton:(PVWSButton)button forPlayer:(NSInteger)player;
{
    inputBuffer[player][0] &= ~(1 << WSMap[button]);
}

- (NSInteger)controllerValueForButtonID:(unsigned)buttonID forPlayer:(NSInteger)player withAnalogMode:(bool)analogMode {
    GCController *controller = nil;
    
    if (player == 0) {
        controller = self.controller1;
    }
    else if (player == 1) {
        controller = self.controller2;
    }
    else if (player == 2) {
        controller = self.controller3;
    }
    else if (player == 3) {
        controller = self.controller4;
    }
    
    switch (self.systemType) {
        case MednaSystemSMS:
        case MednaSystemMD:
            // TODO: Unused since Mednafen sega support is 'low priority'
            return 0;
            break;
        case MednaSystemSS:
            return [self SSValueForButtonID:buttonID forController:controller];
            break;
        case MednaSystemGB:
            return [self GBValueForButtonID:buttonID forController:controller];
            break;
        case MednaSystemGBA:
            return [self GBAValueForButtonID:buttonID forController:controller];
            break;
        case MednaSystemSNES:
            return [self SNESValueForButtonID:buttonID forController:controller];
            break;
        case MednaSystemNES:
            return [self NESValueForButtonID:buttonID forController:controller];
            break;
        case MednaSystemNeoGeo:
            return [self NeoGeoValueForButtonID:buttonID forController:controller];
            break;
        case MednaSystemLynx:
            return [self LynxControllerValueForButtonID:buttonID forController:controller];
            break;
            
        case MednaSystemPCE:
        case MednaSystemPCFX:
            return [self PCEValueForButtonID:buttonID forController:controller];
            break;
            
        case MednaSystemPSX:
            return [self PSXcontrollerValueForButtonID:buttonID forController:controller withAnalogMode:analogMode];
            break;
            
        case MednaSystemVirtualBoy:
            return [self VirtualBoyControllerValueForButtonID:buttonID forController:controller];
            break;
            
        case MednaSystemWonderSwan:
            return [self WonderSwanControllerValueForButtonID:buttonID forController:controller];
            break;
            
        default:
            break;
    }
    
    return 0;
}
#pragma mark SS Buttons
- (NSInteger)SSValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *gamepad = controller.extendedGamepad; //[[controller extendedGamepad] capture];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        // Maps the Sega Saturn Controls to the 8BitDo M30 if enabled in Settings/Controller
        if (PVSettingsModel.shared.use8BitdoM30) {
            switch (buttonID) {
            case PVSaturnButtonUp:
                return DPAD_PRESSED(up);
            case PVSaturnButtonDown:
                return DPAD_PRESSED(down);
            case PVSaturnButtonLeft:
                return DPAD_PRESSED(left);
            case PVSaturnButtonRight:
                return DPAD_PRESSED(right);
            case PVSaturnButtonA:
                return [[gamepad buttonA] isPressed];
            case PVSaturnButtonB:
                return [[gamepad buttonB] isPressed];
            case PVSaturnButtonC:
                return [[gamepad rightShoulder] isPressed];
            case PVSaturnButtonX:
                return [[gamepad buttonX] isPressed];
            case PVSaturnButtonY:
                return [[gamepad buttonY] isPressed];
            case PVSaturnButtonZ:
                return [[gamepad leftShoulder] isPressed];
            case PVSaturnButtonL:
                return [[gamepad leftTrigger] isPressed];
            case PVSaturnButtonStart:
#if TARGET_OS_TV
                return self.isStartPressed || [[gamepad buttonMenu] isPressed];
            case PVSaturnButtonR:
                return [[gamepad rightTrigger] isPressed];
#else
                return self.isStartPressed || [[gamepad rightTrigger] isPressed];
                // no Access to the R Shoulder Button on the Saturn Controller using the M30 due to Start Mismapping on iOS, for now
#endif
            default:
                break;
            }
        } else { // Non 8BitdoM30
            GCDualSenseGamepad *dualSense = [gamepad isKindOfClass:[GCDualSenseGamepad class]] ? gamepad : nil;
            GCDualShockGamepad *dualShock = [gamepad isKindOfClass:[GCDualShockGamepad class]] ? gamepad : nil;
            GCXboxGamepad *xbox = [gamepad isKindOfClass:[GCXboxGamepad class]] ? gamepad : nil;

            
            switch (buttonID) {
                case PVSaturnButtonUp:
                    return DPAD_PRESSED(up);
                case PVSaturnButtonDown:
                    return DPAD_PRESSED(down);
                case PVSaturnButtonLeft:
                    return DPAD_PRESSED(left);
                case PVSaturnButtonRight:
                    return DPAD_PRESSED(right);
                case PVSaturnButtonA:
                    return [[gamepad buttonA] isPressed];
                case PVSaturnButtonB:
                    return [[gamepad buttonB] isPressed];
                case PVSaturnButtonC:
                    return [[gamepad leftShoulder] isPressed];
                case PVSaturnButtonX:
                    return [[gamepad buttonX] isPressed];
                case PVSaturnButtonY:
                    return [[gamepad buttonY] isPressed];
                case PVSaturnButtonZ:
                    return [[gamepad rightShoulder] isPressed];
                case PVSaturnButtonL:
                    return [[gamepad leftTrigger] isPressed];
                case PVSaturnButtonStart:
                {
                    BOOL isStart = NO;
                    if (dualSense) {
                        isStart = self.isStartPressed || dualSense.touchpadButton.isPressed;
                    } else if (dualShock) {
                        isStart = self.isStartPressed || dualShock.touchpadButton.isPressed;
                    } else if (xbox) {
                        isStart = self.isStartPressed || xbox.buttonShare.isPressed;
                    } else {
//                        if (!gamepad.buttonHome.isBoundToSystemGesture) {
//                            return gamepad.buttonHome.isPressed;
//                        }
                        if (gamepad.buttonOptions) {
                            isStart =  gamepad.buttonOptions.isPressed;
                        }

                        bool modifier1Pressed = [[gamepad leftShoulder] isPressed] && [[gamepad rightShoulder] isPressed];
                        bool modifier2Pressed = [[gamepad leftTrigger] isPressed] && [[gamepad rightTrigger] isPressed];
                        bool modifiersPressed = modifier1Pressed && modifier2Pressed;

                        isStart =  self.isStartPressed || (modifiersPressed && [[gamepad buttonX] isPressed]);
                    }
                    DLOG("isStart: %@", isStart ? @"Yes" : @"No");
                    return isStart;
                }
                case PVSaturnButtonR:
                    return [[gamepad rightTrigger] isPressed];
                default:
                    break;
            }}
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVSaturnButtonUp:
                return [[dpad up] isPressed];
            case PVSaturnButtonDown:
                return [[dpad down] isPressed];
            case PVSaturnButtonLeft:
                return [[dpad left] isPressed];
            case PVSaturnButtonRight:
                return [[dpad right] isPressed];
            case PVSaturnButtonA:
                return [[gamepad buttonA] isPressed];
            case PVSaturnButtonB:
                return [[gamepad buttonB] isPressed];
            case PVSaturnButtonC:
                return [[gamepad leftShoulder] isPressed];
            case PVSaturnButtonX:
                return [[gamepad buttonX] isPressed];
            case PVSaturnButtonY:
                return [[gamepad buttonY] isPressed];
            case PVSaturnButtonZ:
                return [[gamepad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVSaturnButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVSaturnButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVSaturnButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVSaturnButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVSaturnButtonA:
                return [[gamepad buttonA] isPressed];
                break;
            case PVSaturnButtonB:
                return [[gamepad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}
#pragma mark GB Buttons
- (NSInteger)GBValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVGBButtonUp:
                return DPAD_PRESSED(up);
            case PVGBButtonDown:
                return DPAD_PRESSED(down);
            case PVGBButtonLeft:
                return DPAD_PRESSED(left);
            case PVGBButtonRight:
                return DPAD_PRESSED(right);
            case PVGBButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVGBButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVGBButtonSelect:
                return [[gamepad leftShoulder] isPressed]?:[[gamepad leftTrigger] isPressed];
            case PVGBButtonStart:
                return [[gamepad rightShoulder] isPressed]?:[[gamepad rightTrigger] isPressed];
            default:
                NSLog(@"Unknown button %i", buttonID);
                break;
        }
        
        //        if (buttonID == GBMap[PVGBButtonUp]) {
        //            return [[dpad up] isPressed]?:[[[gamepad leftThumbstick] up] isPressed];
        //        }
        //        else if (buttonID == GBMap[PVGBButtonDown]) {
        //            return [[dpad down] isPressed]?:[[[gamepad leftThumbstick] down] isPressed];
        //        }
        //        else if (buttonID == GBMap[PVGBButtonLeft]) {
        //            return [[dpad left] isPressed]?:[[[gamepad leftThumbstick] left] isPressed];
        //        }
        //        else if (buttonID == GBMap[PVGBButtonRight]) {
        //            return [[dpad right] isPressed]?:[[[gamepad leftThumbstick] right] isPressed];
        //        }
        //        else if (buttonID == GBMap[PVGBButtonA]) {
        //            return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
        //        }
        //        else if (buttonID == GBMap[PVGBButtonB]) {
        //            return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
        //        }
        //        else if (buttonID == GBMap[PVGBButtonSelect]) {
        //            return [[gamepad leftShoulder] isPressed]?:[[gamepad leftTrigger] isPressed];
        //        }
        //        else if (buttonID == GBMap[PVGBButtonStart]) {
        //            return [[gamepad rightShoulder] isPressed]?:[[gamepad rightTrigger] isPressed];
        //        }
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVGBButtonUp:
                return [[dpad up] isPressed];
            case PVGBButtonDown:
                return [[dpad down] isPressed];
            case PVGBButtonLeft:
                return [[dpad left] isPressed];
            case PVGBButtonRight:
                return [[dpad right] isPressed];
            case PVGBButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVGBButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVGBButtonSelect:
                return [[gamepad leftShoulder] isPressed];
            case PVGBButtonStart:
                return [[gamepad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVGBButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVGBButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVGBButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVGBButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVGBButtonA:
                return [[gamepad buttonX] isPressed];
                break;
            case PVGBButtonB:
                return [[gamepad buttonA] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}
#pragma mark GBA Buttons
- (NSInteger)GBAValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVGBAButtonUp:
                return DPAD_PRESSED(up);
            case PVGBAButtonDown:
                return DPAD_PRESSED(down);
            case PVGBAButtonLeft:
                return DPAD_PRESSED(left);
            case PVGBAButtonRight:
                return DPAD_PRESSED(right);
            case PVGBAButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVGBAButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVGBAButtonL:
                return [[gamepad leftShoulder] isPressed];
            case PVGBAButtonR:
                return [[gamepad rightShoulder] isPressed];
            case PVGBAButtonSelect:
                return [[gamepad leftTrigger] isPressed];
            case PVGBAButtonStart:
                return [[gamepad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVGBAButtonUp:
                return [[dpad up] isPressed];
            case PVGBAButtonDown:
                return [[dpad down] isPressed];
            case PVGBAButtonLeft:
                return [[dpad left] isPressed];
            case PVGBAButtonRight:
                return [[dpad right] isPressed];
            case PVGBAButtonB:
                return [[gamepad buttonA] isPressed];
            case PVGBAButtonA:
                return [[gamepad buttonB] isPressed];
            case PVGBAButtonL:
                return [[gamepad leftShoulder] isPressed];
            case PVGBAButtonR:
                return [[gamepad rightShoulder] isPressed];
            case PVGBAButtonSelect:
                return [[gamepad buttonX] isPressed];
            case PVGBAButtonStart:
                return [[gamepad buttonY] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVGBAButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVGBAButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVGBAButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVGBAButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVGBAButtonA:
                return [[gamepad buttonX] isPressed];
                break;
            case PVGBAButtonB:
                return [[gamepad buttonA] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

#pragma mark SNES Buttons
- (NSInteger)SNESValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVSNESButtonUp:
                return DPAD_PRESSED(up);
            case PVSNESButtonDown:
                return DPAD_PRESSED(down);
            case PVSNESButtonLeft:
                return DPAD_PRESSED(left);
            case PVSNESButtonRight:
                return DPAD_PRESSED(right);
            case PVSNESButtonB:
                return [[gamepad buttonA] isPressed];
            case PVSNESButtonA:
                return [[gamepad buttonB] isPressed];
            case PVSNESButtonX:
                return [[gamepad buttonY] isPressed];
            case PVSNESButtonY:
                return [[gamepad buttonX] isPressed];
            case PVSNESButtonTriggerLeft:
                return [[gamepad leftShoulder] isPressed];
            case PVSNESButtonTriggerRight:
                return [[gamepad rightShoulder] isPressed];
            case PVSNESButtonSelect:
                return [[gamepad leftTrigger] isPressed];
            case PVSNESButtonStart:
                return [[gamepad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVSNESButtonUp:
                return [[dpad up] isPressed];
            case PVSNESButtonDown:
                return [[dpad down] isPressed];
            case PVSNESButtonLeft:
                return [[dpad left] isPressed];
            case PVSNESButtonRight:
                return [[dpad right] isPressed];
            case PVSNESButtonB:
                return [[gamepad buttonA] isPressed];
            case PVSNESButtonA:
                return [[gamepad buttonB] isPressed];
            case PVSNESButtonX:
                return [[gamepad buttonY] isPressed];
            case PVSNESButtonY:
                return [[gamepad buttonX] isPressed];
            case PVSNESButtonTriggerLeft:
                return [[gamepad leftShoulder] isPressed];
            case PVSNESButtonTriggerRight:
                return [[gamepad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVSNESButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVSNESButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVSNESButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVSNESButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVSNESButtonA:
                return [[gamepad buttonX] isPressed];
                break;
            case PVSNESButtonB:
                return [[gamepad buttonA] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}
#pragma mark NES Buttons
- (NSInteger)NESValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVNESButtonUp:
                return DPAD_PRESSED(up);
            case PVNESButtonDown:
                return DPAD_PRESSED(down);
            case PVNESButtonLeft:
                return DPAD_PRESSED(left);
            case PVNESButtonRight:
                return DPAD_PRESSED(right);
            case PVNESButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVNESButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVNESButtonSelect:
                return [[gamepad leftShoulder] isPressed]?:[[gamepad leftTrigger] isPressed];
            case PVNESButtonStart:
                return [[gamepad rightShoulder] isPressed]?:[[gamepad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVNESButtonUp:
                return [[dpad up] isPressed];
            case PVNESButtonDown:
                return [[dpad down] isPressed];
            case PVNESButtonLeft:
                return [[dpad left] isPressed];
            case PVNESButtonRight:
                return [[dpad right] isPressed];
            case PVNESButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVNESButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVNESButtonSelect:
                return [[gamepad leftShoulder] isPressed];
            case PVNESButtonStart:
                return [[gamepad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVNESButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVNESButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVNESButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVNESButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVNESButtonA:
                return [[gamepad buttonX] isPressed];
                break;
            case PVNESButtonB:
                return [[gamepad buttonA] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}
#pragma mark NEOGEOPOCKET Buttons
- (NSInteger)NeoGeoValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad]) {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVNGPButtonUp:
                return DPAD_PRESSED(up);
            case PVNGPButtonDown:
                return DPAD_PRESSED(down);
            case PVNGPButtonLeft:
                return DPAD_PRESSED(left);
            case PVNGPButtonRight:
                return DPAD_PRESSED(right);
            case PVNGPButtonB:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVNGPButtonA:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVNGPButtonOption:
                return [[gamepad leftShoulder] isPressed]?:[[gamepad leftTrigger] isPressed] ?: [[gamepad rightShoulder] isPressed]?:[[gamepad rightTrigger] isPressed];
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVNGPButtonUp:
                return [[dpad up] isPressed];
            case PVNGPButtonDown:
                return [[dpad down] isPressed];
            case PVNGPButtonLeft:
                return [[dpad left] isPressed];
            case PVNGPButtonRight:
                return [[dpad right] isPressed];
            case PVNGPButtonB:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVNGPButtonA:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVNGPButtonOption:
                return [[gamepad leftShoulder] isPressed] ?: [[gamepad rightShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVNGPButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVNGPButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVNGPButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVNGPButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVNGPButtonA:
                return [[gamepad buttonA] isPressed];
                break;
            case PVNGPButtonB:
                return [[gamepad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}
#pragma mark PCE Buttons
- (NSInteger)PCEValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        if (PVSettingsModel.shared.use8BitdoM30) // M30 Mode
        {switch (buttonID) {
                // D-Pad
            case PVPCEButtonUp:
                return [[[gamepad leftThumbstick] up] value] > DEADZONE;
            case PVPCEButtonDown:
                return [[[gamepad leftThumbstick] down] value] > DEADZONE;
            case PVPCEButtonLeft:
                return [[[gamepad leftThumbstick] left] value] > DEADZONE;
            case PVPCEButtonRight:
                return [[[gamepad leftThumbstick] right] value] > DEADZONE;
                
                // Select + Run
            case PVPCEButtonSelect:
                return [[gamepad leftTrigger] isPressed];
            case PVPCEButtonRun:
                return [[gamepad rightTrigger] isPressed];
                
                // NEC Avenue 6 button layout
            case PVPCEButtonButton1:
                return [[gamepad rightShoulder] isPressed];
            case PVPCEButtonButton2:
                return [[gamepad buttonB] isPressed];
            case PVPCEButtonButton3:
                return [[gamepad buttonA] isPressed];
            case PVPCEButtonButton4:
                return [[gamepad buttonX] isPressed];
            case PVPCEButtonButton5:
                return [[gamepad buttonY] isPressed];
            case PVPCEButtonButton6:
                return [[gamepad leftShoulder] isPressed];
                
                // Toggle to the 6 Button Mode when the Extended Buttons are pressed
            case PVPCEButtonMode:
                return [[gamepad buttonB] isPressed] || [[gamepad buttonX] isPressed] || [[gamepad buttonY] isPressed] || [[gamepad leftShoulder] isPressed] || [[gamepad buttonA] isPressed] || [[gamepad rightShoulder] isPressed];
            default:
                break;
        }}
        {switch (buttonID) { // Non M30 mode
                // D-Pad
            case PVPCEButtonUp:
                return DPAD_PRESSED(up);
            case PVPCEButtonDown:
                return DPAD_PRESSED(down);
            case PVPCEButtonLeft:
                return DPAD_PRESSED(left);
            case PVPCEButtonRight:
                return DPAD_PRESSED(right);
                
                // Standard Buttons
            case PVPCEButtonButton1:
                return [[gamepad buttonB] isPressed];
            case PVPCEButtonButton2:
                return [[gamepad buttonA] isPressed];
                
            case PVPCEButtonSelect:
                return [[gamepad leftTrigger] isPressed];
            case PVPCEButtonRun:
                return [[gamepad rightTrigger] isPressed];
                
                // Extended Buttons
            case PVPCEButtonButton3:
                return [[gamepad buttonX] isPressed];
            case PVPCEButtonButton4:
                return [[gamepad leftShoulder] isPressed];
            case PVPCEButtonButton5:
                return [[gamepad buttonY] isPressed];
            case PVPCEButtonButton6:
                return [[gamepad rightShoulder] isPressed];
                
                // Toggle the Mode: Extended Buttons are pressed
            case PVPCEButtonMode:
                return [[gamepad buttonX] isPressed] || [[gamepad leftShoulder] isPressed] || [[gamepad buttonY] isPressed] || [[gamepad rightShoulder] isPressed];
            default:
                break;
        }}
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
                // D-Pad
            case PVPCEButtonUp:
                return [[dpad up] isPressed];
            case PVPCEButtonDown:
                return [[dpad down] isPressed];
            case PVPCEButtonLeft:
                return [[dpad left] isPressed];
            case PVPCEButtonRight:
                return [[dpad right] isPressed];
                
                // Standard Buttons
            case PVPCEButtonButton1:
                return [[gamepad buttonB] isPressed];
            case PVPCEButtonButton2:
                return [[gamepad buttonA] isPressed];
                
            case PVPCEButtonSelect:
                return [[gamepad leftShoulder] isPressed];
            case PVPCEButtonRun:
                return [[gamepad rightShoulder] isPressed];
                
                // Extended Buttons
            case PVPCEButtonButton3:
                return [[gamepad buttonX] isPressed];
            case PVPCEButtonButton4:
                return [[gamepad buttonY] isPressed];
                
                // Toggle the Mode: Extended Buttons are pressed
            case PVPCEButtonMode:
                return [[gamepad buttonX] isPressed] || [[gamepad buttonY] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVPCEButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVPCEButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVPCEButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVPCEButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVPCEButtonButton1:
                return [[gamepad buttonA] isPressed];
                break;
            case PVPCEButtonButton2:
                return [[gamepad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    
    return 0;
}
#pragma mark PSX Buttons
- (float)PSXAnalogControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        switch (buttonID) {
            case PVPSXButtonLeftAnalogUp:
                return [gamepad leftThumbstick].up.value;
            case PVPSXButtonLeftAnalogDown:
                return [gamepad leftThumbstick].down.value;
            case PVPSXButtonLeftAnalogLeft:
                return [gamepad leftThumbstick].left.value;
            case PVPSXButtonLeftAnalogRight:
                return [gamepad leftThumbstick].right.value;
            case PVPSXButtonRightAnalogUp:
                return [gamepad rightThumbstick].up.value;
            case PVPSXButtonRightAnalogDown:
                return [gamepad rightThumbstick].down.value;
            case PVPSXButtonRightAnalogLeft:
                return [gamepad rightThumbstick].left.value;
            case PVPSXButtonRightAnalogRight:
                return [gamepad rightThumbstick].right.value;
            default:
                break;
        }
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        switch (buttonID) {
            case PVPSXButtonLeftAnalogUp:
                return [gamepad dpad].up.value;
            case PVPSXButtonLeftAnalogDown:
                return [gamepad dpad].down.value;
            case PVPSXButtonLeftAnalogLeft:
                return [gamepad dpad].left.value;
            case PVPSXButtonLeftAnalogRight:
                return [gamepad dpad].right.value;
            default:
                break;
        }
    }
    return 0;
}

- (NSInteger)PSXcontrollerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller withAnalogMode:(bool)analogMode {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *gamepad = [[controller extendedGamepad] capture];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        
        if (@available(iOS 14, *)) {
            
            if ([gamepad isKindOfClass:[GCDualSenseGamepad class]]) {
                GCDualSenseGamepad *dualSense = gamepad;
            } else if ([gamepad isKindOfClass:[GCDualShockGamepad class]]) {
                GCDualShockGamepad *dualShock = gamepad;
                
            } else if ([gamepad isKindOfClass:[GCXboxGamepad class]]) {
                GCXboxGamepad *xboxGamepad = gamepad;
            }
        }
        
        GCDualSenseGamepad *dualSense = [gamepad isKindOfClass:[GCDualSenseGamepad class]] ? gamepad : nil;
        
        bool modifier1Pressed = [[gamepad leftShoulder] isPressed] && [[gamepad rightShoulder] isPressed];
        bool modifier2Pressed = [[gamepad leftTrigger] isPressed] && [[gamepad rightTrigger] isPressed];
        bool modifiersPressed = modifier1Pressed && modifier2Pressed;
        
        switch (buttonID) {
            case PVPSXButtonUp:
                return ([[dpad up] isPressed] || (!analogMode && [[[gamepad leftThumbstick] up] isPressed]));
            case PVPSXButtonDown:
                return ([[dpad down] isPressed] || (!analogMode && [[[gamepad leftThumbstick] down] isPressed])) && !modifiersPressed;
            case PVPSXButtonLeft:
                return ([[dpad left] isPressed] || (!analogMode && [[[gamepad leftThumbstick] left] isPressed]));
            case PVPSXButtonRight:
                return ([[dpad right] isPressed] || (!analogMode && [[[gamepad leftThumbstick] right] isPressed])) && !modifiersPressed;
            case PVPSXButtonLeftAnalogUp:
                return analogMode ? [gamepad leftThumbstick].up.value : [gamepad leftThumbstick].up.pressed;
            case PVPSXButtonLeftAnalogDown:
                return analogMode ? [gamepad leftThumbstick].down.value : [gamepad leftThumbstick].down.pressed;
            case PVPSXButtonLeftAnalogLeft:
                return analogMode ? [gamepad leftThumbstick].left.value : [gamepad leftThumbstick].left.pressed;
            case PVPSXButtonLeftAnalogRight:
                return analogMode ? [gamepad leftThumbstick].right.value : [gamepad leftThumbstick].right.pressed;
            case PVPSXButtonSquare:
                return [[gamepad buttonX] isPressed] && !modifiersPressed;
            case PVPSXButtonTriangle:
                return [[gamepad buttonY] isPressed];
            case PVPSXButtonCross:
                return [[gamepad buttonA] isPressed] && !modifiersPressed;
            case PVPSXButtonCircle:
                return [[gamepad buttonB] isPressed] && !modifiersPressed;
            case PVPSXButtonL1:
                return [[gamepad leftShoulder] isPressed] && !modifier2Pressed;
            case PVPSXButtonL2:
                return [[gamepad leftTrigger] isPressed] && !modifier1Pressed;
            case PVPSXButtonL3:
                return self.isL3Pressed || [[gamepad leftThumbstickButton] isPressed] || (modifiersPressed && [[dpad down] isPressed]);
            case PVPSXButtonR1:
                return [[gamepad rightShoulder] isPressed] && !modifier2Pressed;
            case PVPSXButtonR2:
                return [[gamepad rightTrigger] isPressed] && !modifier1Pressed;
            case PVPSXButtonR3:
                return self.isR3Pressed || [[gamepad rightThumbstickButton] isPressed] || (modifiersPressed && [[gamepad buttonA] isPressed]);
            case PVPSXButtonSelect:
                return self.isSelectPressed || (modifiersPressed && [[dpad right] isPressed]);
            case PVPSXButtonStart:
                return self.isStartPressed || (modifiersPressed && [[gamepad buttonX] isPressed]);
            case PVPSXButtonAnalogMode:
                return self.isAnalogModePressed || (modifiersPressed && [[gamepad buttonB] isPressed]);
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        bool modifierPressed = [[gamepad leftShoulder] isPressed] && [[gamepad rightShoulder] isPressed];
        
        switch (buttonID) {
            case PVPSXButtonUp:
                return [[dpad up] isPressed] && !modifierPressed;
            case PVPSXButtonDown:
                return [[dpad down] isPressed] && !modifierPressed;
            case PVPSXButtonLeft:
                return [[dpad left] isPressed];
            case PVPSXButtonRight:
                return [[dpad right] isPressed] && !modifierPressed;
            case PVPSXButtonSquare:
                return [[gamepad buttonX] isPressed] && !modifierPressed;
            case PVPSXButtonTriangle:
                return [[gamepad buttonY] isPressed] && !modifierPressed;
            case PVPSXButtonCross:
                return [[gamepad buttonA] isPressed] && !modifierPressed;
            case PVPSXButtonCircle:
                return [[gamepad buttonB] isPressed] && !modifierPressed;
            case PVPSXButtonL1:
                return [[gamepad leftShoulder] isPressed];
            case PVPSXButtonL2:
                return modifierPressed && [[dpad up] isPressed];
            case PVPSXButtonL3:
                return self.isL3Pressed || modifierPressed && [[dpad down] isPressed];
            case PVPSXButtonR1:
                return [[gamepad rightShoulder] isPressed];
            case PVPSXButtonR2:
                return modifierPressed && [[gamepad buttonY] isPressed];
            case PVPSXButtonR3:
                return self.isR3Pressed || modifierPressed && [[gamepad buttonA] isPressed];
            case PVPSXButtonSelect:
                return self.isSelectPressed || (modifierPressed && [[dpad right] isPressed]);
            case PVPSXButtonStart:
                return self.isStartPressed || (modifierPressed && [[gamepad buttonX] isPressed]);
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVPSXButtonUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVPSXButtonDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVPSXButtonLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVPSXButtonRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVPSXButtonCross:
                return [[gamepad buttonA] isPressed];
                break;
            case PVPSXButtonCircle:
                return [[gamepad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}
#pragma mark VirtualBoy Buttons
- (NSInteger)VirtualBoyControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVVBButtonLeftUp:
                return DPAD_PRESSED(up);
            case PVVBButtonLeftDown:
                return DPAD_PRESSED(down);
            case PVVBButtonLeftLeft:
                return DPAD_PRESSED(left);
            case PVVBButtonLeftRight:
                return DPAD_PRESSED(right);
            case PVVBButtonRightUp:
                return [[[gamepad rightThumbstick] up] isPressed];
            case PVVBButtonRightDown:
                return [[[gamepad rightThumbstick] down] isPressed];
            case PVVBButtonRightLeft:
                return [[[gamepad rightThumbstick] left] isPressed];
            case PVVBButtonRightRight:
                return [[[gamepad rightThumbstick] right] isPressed];
            case PVVBButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVVBButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVVBButtonL:
                return [[gamepad leftShoulder] isPressed];
            case PVVBButtonR:
                return [[gamepad rightShoulder] isPressed];
            case PVVBButtonStart:
                return [[gamepad rightTrigger] isPressed];
            case PVVBButtonSelect:
                return [[gamepad leftTrigger] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVVBButtonLeftUp:
                return [[dpad up] isPressed];
            case PVVBButtonLeftDown:
                return [[dpad down] isPressed];
            case PVVBButtonLeftLeft:
                return [[dpad left] isPressed];
            case PVVBButtonLeftRight:
                return [[dpad right] isPressed];
            case PVVBButtonA:
                return [[gamepad buttonB] isPressed];
            case PVVBButtonB:
                return [[gamepad buttonA] isPressed];
            case PVVBButtonL:
                return [[gamepad leftShoulder] isPressed];
            case PVVBButtonR:
                return [[gamepad rightShoulder] isPressed];
            case PVVBButtonStart:
                return [[gamepad buttonY] isPressed];
            case PVVBButtonSelect:
                return [[gamepad buttonX] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVVBButtonLeftUp:
                return [[dpad up] value] > 0.5;
                break;
            case PVVBButtonLeftDown:
                return [[dpad down] value] > 0.5;
                break;
            case PVVBButtonLeftLeft:
                return [[dpad left] value] > 0.5;
                break;
            case PVVBButtonLeftRight:
                return [[dpad right] value] > 0.5;
                break;
            case PVVBButtonA:
                return [[gamepad buttonA] isPressed];
                break;
            case PVVBButtonB:
                return [[gamepad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}
#pragma mark Wonderswan Buttons
- (NSInteger)WonderSwanControllerValueForButtonID:(unsigned)buttonID forController:(GCController*)controller {
    if ([controller extendedGamepad])
    {
        GCExtendedGamepad *gamepad = [controller extendedGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
                /* WonderSwan has a Top (Y) D-Pad and a lower (X) D-Pad. MFi controllers
                 may have the Joy Stick and Left D-Pad in either Top/Bottom configuration.
                 Another Option is to map to Left/Right Joystick and Make left D-Pad same as
                 left JoyStick, but if the games require using Left/Right hand at same time it
                 may be difficult to his the right d-pad and action buttons at the same time.
                 -joe M */
            case PVWSButtonX1:
                return [[[gamepad leftThumbstick] up] isPressed];
            case PVWSButtonX3:
                return [[[gamepad leftThumbstick] down] isPressed];
            case PVWSButtonX4:
                return [[[gamepad leftThumbstick] left] isPressed];
            case PVWSButtonX2:
                return [[[gamepad leftThumbstick] right] isPressed];
            case PVWSButtonY1:
                return [[dpad up] isPressed];
            case PVWSButtonY3:
                return [[dpad down] isPressed];
            case PVWSButtonY4:
                return [[dpad left] isPressed];
            case PVWSButtonY2:
                return [[dpad right] isPressed];
            case PVWSButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVWSButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVWSButtonStart:
                return [[gamepad rightShoulder] isPressed]?:[[gamepad rightTrigger] isPressed];
            case PVWSButtonSound:
                return [[gamepad leftShoulder] isPressed];
            default:
                break;
        }
    }
    else if ([controller gamepad])
    {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVWSButtonX1:
                return [[dpad up] isPressed];
            case PVWSButtonX3:
                return [[dpad down] isPressed];
            case PVWSButtonX4:
                return [[dpad left] isPressed];
            case PVWSButtonX2:
                return [[dpad right] isPressed];
            case PVWSButtonA:
                return [[gamepad buttonB] isPressed]?:[[gamepad buttonX] isPressed];
            case PVWSButtonB:
                return [[gamepad buttonA] isPressed]?:[[gamepad buttonY] isPressed];
            case PVWSButtonStart:
                return [[gamepad rightShoulder] isPressed];
            case PVWSButtonSound:
                return [[gamepad leftShoulder] isPressed];
            default:
                break;
        }
    }
#if TARGET_OS_TV
    else if ([controller microGamepad])
    {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        switch (buttonID) {
            case PVWSButtonX1:
                return [[dpad up] value] > 0.5;
                break;
            case PVWSButtonX3:
                return [[dpad down] value] > 0.5;
                break;
            case PVWSButtonX4:
                return [[dpad left] value] > 0.5;
                break;
            case PVWSButtonX2:
                return [[dpad right] value] > 0.5;
                break;
            case PVWSButtonA:
                return [[gamepad buttonA] isPressed];
                break;
            case PVWSButtonB:
                return [[gamepad buttonX] isPressed];
                break;
            default:
                break;
        }
    }
#endif
    return 0;
}

//- (void)didPush:(NSInteger)button forPlayer:(NSInteger)player {
//
//}
//
//- (void)didRelease:(NSInteger)button forPlayer:(NSInteger)player {
//
//}
//
//- (void)didMoveJoystick:(NSInteger)button withValue:(CGFloat)value forPlayer:(NSInteger)player {
//
//}

@end
