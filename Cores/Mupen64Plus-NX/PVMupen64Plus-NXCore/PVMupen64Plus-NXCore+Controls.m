
#import "MupenGameNXCore+Controls.h"
#import <PVMupen64Plus-NX/PVMupen64Plus-NX-Swift.h>

#import "api/config.h"
#import "api/m64p_common.h"
#import "api/m64p_config.h"
#import "api/m64p_frontend.h"
#import "api/m64p_vidext.h"
#import "api/callbacks.h"
#import "osal/dynamiclib.h"
#import "Plugins/Core/src/main/version.h"
#import "Plugins/Core/src/plugin/plugin.h"
//#import "rom.h"
//#import "savestates.h"
//#import "memory.h"
//#import "mupen64plus-core/src/main/main.h"
@import Dispatch;
@import PVSupport;
#if TARGET_OS_MACCATALYST
@import OpenGL.GL3;
@import GLUT;
#else
@import OpenGLES.ES3;
@import GLKit;
#endif

#import <dlfcn.h>

void MupenGetKeys(int Control, BUTTONS *Keys) {
    GET_CURRENT_AND_RETURN();
    
    if (Control == 0) {
        [current pollControllers];
    }

    Keys->U_DPAD = current->padData[Control][PVN64ButtonDPadUp];
    Keys->D_DPAD = current->padData[Control][PVN64ButtonDPadDown];
    Keys->L_DPAD = current->padData[Control][PVN64ButtonDPadLeft];
    Keys->R_DPAD = current->padData[Control][PVN64ButtonDPadRight];
    
    Keys->START_BUTTON = current->padData[Control][PVN64ButtonStart];
    
    Keys->Z_TRIG = current->padData[Control][PVN64ButtonZ];
    
    Keys->B_BUTTON = current->padData[Control][PVN64ButtonB];
    Keys->A_BUTTON = current->padData[Control][PVN64ButtonA];
    
    Keys->L_CBUTTON = current->padData[Control][PVN64ButtonCLeft];
    Keys->R_CBUTTON = current->padData[Control][PVN64ButtonCRight];
    Keys->D_CBUTTON = current->padData[Control][PVN64ButtonCDown];
    Keys->U_CBUTTON = current->padData[Control][PVN64ButtonCUp];
  
    Keys->L_TRIG = current->padData[Control][PVN64ButtonL];
    Keys->R_TRIG = current->padData[Control][PVN64ButtonR];

    Keys->X_AXIS = current->xAxis[Control];
    Keys->Y_AXIS = current->yAxis[Control];
}

void MupenInitiateControllers (CONTROL_INFO ControlInfo) {
    GET_CURRENT_OR_RETURN();

    bool p2Present = current.controller2 != nil || current.dualJoystick;

    ControlInfo.Controls[0].Present = 1;
    ControlInfo.Controls[0].Plugin = current->controllerMode[0];
    ControlInfo.Controls[1].Present = p2Present;
    ControlInfo.Controls[1].Plugin = current->controllerMode[1];
    ControlInfo.Controls[2].Present = current.controller3 != nil;
    ControlInfo.Controls[2].Plugin = current->controllerMode[2];
    ControlInfo.Controls[3].Present = current.controller4 != nil || (current.controller3 != nil && current.dualJoystick);
    ControlInfo.Controls[3].Plugin = current->controllerMode[3];
}

/******************************************************************
 Function: ControllerCommand
 Purpose:  To process the raw data that has just been sent to a
 specific controller.
 input:    - Controller Number (0 to 3) and -1 signalling end of
 processing the pif ram.
 - Pointer of data to be processed.
 output:   none
 note:     This function is only needed if the DLL is allowing raw
 data, or the plugin is set to raw
 the data that is being processed looks like this:
 initilize controller: 01 03 00 FF FF FF
 read controller:      01 04 01 FF FF FF FF
 *******************************************************************/
void MupenControllerCommand(int Control, unsigned char *Command) {
        // Some stuff from n-rage plugin
#define RD_GETSTATUS        0x00        // get status
#define RD_READKEYS         0x01        // read button values
#define RD_READPAK          0x02        // read from controllerpack
#define RD_WRITEPAK         0x03        // write to controllerpack
#define RD_RESETCONTROLLER  0xff        // reset controller
#define RD_READEEPROM       0x04        // read eeprom
#define RD_WRITEEPROM       0x05        // write eeprom

#define PAK_IO_RUMBLE       0xC000      // the address where rumble-commands are sent to

    GET_CURRENT_OR_RETURN();

    unsigned char *Data = &Command[5];

    if (Control == -1)
    return;

    switch (Command[2])
    {
        case RD_GETSTATUS:
        break;
        case RD_READKEYS:
        break;
        case RD_READPAK: {
//        if (controller[Control].control->Plugin == PLUGIN_RAW)
//        {
            unsigned int dwAddress = (Command[3] << 8) + (Command[4] & 0xE0);

            if(( dwAddress >= 0x8000 ) && ( dwAddress < 0x9000 ) )
            memset( Data, 0x80, 32 );
            else
            memset( Data, 0x00, 32 );

            Data[32] = DataCRC( Data, 32 );
//        }
        break;
        }
        case RD_WRITEPAK: {
//        if (controller[Control].control->Plugin == PLUGIN_RAW)
//        {
            unsigned int dwAddress = (Command[3] << 8) + (Command[4] & 0xE0);
//            Data[32] = DataCRC( Data, 32 );
//
            if ((dwAddress == PAK_IO_RUMBLE) )//&& (rumble.set_rumble_state))
            {
                if (*Data)
                {
                    [current rumble];
//                    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
//                    rumble.set_rumble_state(Control, RETRO_RUMBLE_WEAK, 0xFFFF);
//                    rumble.set_rumble_state(Control, RETRO_RUMBLE_STRONG, 0xFFFF);
                }
                else
                {
//                    rumble.set_rumble_state(Control, RETRO_RUMBLE_WEAK, 0);
//                    rumble.set_rumble_state(Control, RETRO_RUMBLE_STRONG, 0);
                }
            }
//        }

        break;
        }
        case RD_RESETCONTROLLER:
        break;
        case RD_READEEPROM:
        break;
        case RD_WRITEEPROM:
        break;
    }
}


//NSString *MupenControlNames[] = {
//    @"N64_DPadU", @"N64_DPadD", @"N64_DPadL", @"N64_DPadR",
//    @"N64_CU", @"N64_CD", @"N64_CL", @"N64_CR",
//    @"N64_B", @"N64_A", @"N64_R", @"N64_L", @"N64_Z", @"N64_Start"
//}; // FIXME: missing: joypad X, joypad Y, mempak switch, rumble switch

#define N64_ANALOG_MAX 80

@implementation MupenGameNXCore (Controls)

-(void)setMode:(NSInteger)mode forController:(NSInteger)controller {
    NSAssert(controller < 4, @"Out of index");
    self->controllerMode[controller] = mode;
}

- (void)pollController:(GCController* _Nullable)controller forIndex:(NSInteger)playerIndex {
    if (!controller) {
        return;
    }
    if (LIKELY(controller.extendedGamepad)) {
        GCExtendedGamepad *gamepad     = [controller extendedGamepad];
        GCDualSenseGamepad *dualSense = [gamepad isKindOfClass:[GCDualSenseGamepad class]] ? gamepad : nil;

        GCControllerDirectionPad *dpad = [gamepad dpad];
        
        BOOL dualModeOverrides = self.dualJoystick && (playerIndex == 0 || playerIndex == 2);

        // Left Joystick → Joystick
        xAxis[playerIndex] = gamepad.leftThumbstick.xAxis.value * N64_ANALOG_MAX;
        yAxis[playerIndex] = gamepad.leftThumbstick.yAxis.value * N64_ANALOG_MAX;

        // MFi-D-Pad → D-Pad
        padData[playerIndex][PVN64ButtonDPadUp] = dpad.up.isPressed;
        padData[playerIndex][PVN64ButtonDPadDown] = dpad.down.isPressed;
        padData[playerIndex][PVN64ButtonDPadLeft] = dpad.left.isPressed;
        padData[playerIndex][PVN64ButtonDPadRight] = dpad.right.isPressed;

        if(dualModeOverrides) {
            // MFi-R2 → P2.Z
            padData[playerIndex+1][PVN64ButtonZ] = gamepad.rightTrigger.isPressed;
            
            // MFi-L2 → P1.Z
            padData[playerIndex][PVN64ButtonZ] = gamepad.leftTrigger.isPressed;

            if (dualSense) {
                padData[playerIndex][PVN64ButtonStart] = dualSense.touchpadButton.touched;
            }
        } else {
            if (dualSense) {
                // DualShock-TouchPad → Start
                padData[playerIndex][PVN64ButtonStart] = dualSense.touchpadButton.touched;
                // DualShock-Either Trigger → Z
                padData[playerIndex][PVN64ButtonZ] = gamepad.leftTrigger.isPressed || gamepad.rightTrigger.isPressed;
            } else {
                // MFi-L2 → Start
                padData[playerIndex][PVN64ButtonStart] = gamepad.leftTrigger.isPressed;

                // MFi-R2 → Z
                padData[playerIndex][PVN64ButtonZ] = gamepad.rightTrigger.isPressed;
            }
        }
        
        // If MFi-L2 is not pressed… MFi-L1 → L
        if (!gamepad.rightShoulder.isPressed) {
            padData[playerIndex][PVN64ButtonL] = gamepad.leftShoulder.isPressed;
        }
        
        // If MFi-L1 is not pressed… MFi-R1 → R
        if (!gamepad.leftShoulder.isPressed) {
            padData[playerIndex][PVN64ButtonR] = gamepad.rightShoulder.isPressed;
        }
        // If not C-Mode… MFi-X,A → A,B MFi-Y,B → C←,C↓
        if (!(gamepad.leftShoulder.isPressed && gamepad.rightShoulder.isPressed)) {
            padData[playerIndex][PVN64ButtonA] = gamepad.buttonA.isPressed;
            padData[playerIndex][PVN64ButtonB] = gamepad.buttonX.isPressed;
            padData[playerIndex][PVN64ButtonCLeft] = gamepad.buttonY.isPressed;
            padData[playerIndex][PVN64ButtonCDown] = gamepad.buttonB.isPressed;
        }
        
        //C-Mode: MFi-X,Y,A,B -> C←,C↑,C↓,C→
        if (gamepad.leftShoulder.isPressed && gamepad.rightShoulder.isPressed) {
            padData[playerIndex][PVN64ButtonCLeft] = gamepad.buttonX.isPressed;
            padData[playerIndex][PVN64ButtonCUp] = gamepad.buttonY.isPressed;
            padData[playerIndex][PVN64ButtonCDown] = gamepad.buttonA.isPressed;
            padData[playerIndex][PVN64ButtonCRight] = gamepad.buttonB.isPressed;
        }

        // Right Joystick → C Buttons
        if(dualModeOverrides) {
            xAxis[playerIndex+1] = gamepad.rightThumbstick.xAxis.value * N64_ANALOG_MAX;
            yAxis[playerIndex+1] = gamepad.rightThumbstick.yAxis.value * N64_ANALOG_MAX;
        } else {
            float rightJoystickDeadZone = 0.45;
            if (!(gamepad.leftShoulder.isPressed && gamepad.rightShoulder.isPressed) && !(gamepad.buttonY.isPressed || gamepad.buttonB.isPressed)) {
                padData[playerIndex][PVN64ButtonCUp] = gamepad.rightThumbstick.up.value > rightJoystickDeadZone;
                padData[playerIndex][PVN64ButtonCDown] = gamepad.rightThumbstick.down.value > rightJoystickDeadZone;
                padData[playerIndex][PVN64ButtonCLeft] = gamepad.rightThumbstick.left.value > rightJoystickDeadZone;
                padData[playerIndex][PVN64ButtonCRight] = gamepad.rightThumbstick.right.value > rightJoystickDeadZone;
            }
        }
    } else if ([controller gamepad]) {
        GCGamepad *gamepad = [controller gamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        
        if (!gamepad.rightShoulder.isPressed) {
            // Default
            xAxis[playerIndex] = (dpad.left.value > 0.5 ? -N64_ANALOG_MAX : 0) + (dpad.right.value > 0.5 ? N64_ANALOG_MAX : 0);
            yAxis[playerIndex] = (dpad.down.value > 0.5 ? -N64_ANALOG_MAX : 0) + (dpad.up.value > 0.5 ? N64_ANALOG_MAX : 0);
            
            padData[playerIndex][PVN64ButtonA] = gamepad.buttonA.isPressed;
            padData[playerIndex][PVN64ButtonB] = gamepad.buttonX.isPressed;
            
            padData[playerIndex][PVN64ButtonCLeft] = gamepad.buttonY.isPressed;
            padData[playerIndex][PVN64ButtonCDown] = gamepad.buttonB.isPressed;
        } else {
            // Alt-Mode
            padData[playerIndex][PVN64ButtonDPadUp] = dpad.up.isPressed;
            padData[playerIndex][PVN64ButtonDPadDown] = dpad.down.isPressed;
            padData[playerIndex][PVN64ButtonDPadLeft] = dpad.left.isPressed;
            padData[playerIndex][PVN64ButtonDPadRight] = dpad.right.isPressed;
            
            padData[playerIndex][PVN64ButtonCLeft] = gamepad.buttonX.isPressed;
            padData[playerIndex][PVN64ButtonCUp] = gamepad.buttonY.isPressed;
            padData[playerIndex][PVN64ButtonCDown] = gamepad.buttonA.isPressed;
            padData[playerIndex][PVN64ButtonCRight] = gamepad.buttonB.isPressed;
        }
        
        padData[playerIndex][PVN64ButtonZ] = gamepad.leftShoulder.isPressed;
        padData[playerIndex][PVN64ButtonR] = gamepad.rightShoulder.isPressed;
        
    }
#if TARGET_OS_TV
    else if ([controller microGamepad]) {
        GCMicroGamepad *gamepad = [controller microGamepad];
        GCControllerDirectionPad *dpad = [gamepad dpad];
        
        xAxis[playerIndex] = (dpad.left.value > 0.5 ? -N64_ANALOG_MAX : 0) + (dpad.right.value > 0.5 ? N64_ANALOG_MAX : 0);
        yAxis[playerIndex] = (dpad.down.value > 0.5 ? -N64_ANALOG_MAX : 0) + (dpad.up.value > 0.5 ? N64_ANALOG_MAX : 0);
        
        padData[playerIndex][PVN64ButtonB] = gamepad.buttonA.isPressed;
        padData[playerIndex][PVN64ButtonA] = gamepad.buttonX.isPressed;
    }
#endif
}

- (void)pollControllers {
#define USE_CAPTURE 1
#define USE_QUEUE 1

#if USE_CAPTURE
#define controllerForNum(num) [self.controller##num capture]
#else
#define controllerForNum(num) self.controller##num
#endif

#if USE_QUEUE
        //    const NSOperationQueue *queue = [NSOperationQueue currentQueue];
            [_inputQueue cancelAllOperations];
            NSMutableArray<NSBlockOperation*>* ops = [NSMutableArray arrayWithCapacity:4];
        #define CHECK_CONTROLLER(num) \
            if(self.controller##num) [ops addObject:[NSBlockOperation blockOperationWithBlock:^{[self pollController:controllerForNum(num) forIndex:(num - 1)];}]]

            CHECK_CONTROLLER(1);
            CHECK_CONTROLLER(2);
            CHECK_CONTROLLER(3);
            CHECK_CONTROLLER(4);

            [_inputQueue addOperations:ops waitUntilFinished:NO];
#else
#define CHECK_CONTROLLER(num) if(self.controller##num) [self pollController:controllerForNum(num) forIndex:(num - 1)]

    CHECK_CONTROLLER(1);
    CHECK_CONTROLLER(2);
    CHECK_CONTROLLER(3);
    CHECK_CONTROLLER(4);
#endif
#undef CHECK_CONTROLLER
#undef controllerForNum
}

- (void)didMoveN64JoystickDirection:(PVN64Button)button withValue:(CGFloat)value forPlayer:(NSUInteger)player {
    if (self.dualJoystickOption && player == 0) {
        player = 1;
    }
    switch (button) {
        case PVN64ButtonAnalogUp:
//            NSLog(@"Up: %f", round(value * N64_ANALOG_MAX));
            yAxis[player] = round(value * N64_ANALOG_MAX);
            break;
        case PVN64ButtonAnalogDown:
//            NSLog(@"Down: %f", value * -N64_ANALOG_MAX);
            yAxis[player] = value * -N64_ANALOG_MAX;
            break;
        case PVN64ButtonAnalogLeft:
            xAxis[player] = value * -N64_ANALOG_MAX;
            break;
        case PVN64ButtonAnalogRight:
            xAxis[player] = value * N64_ANALOG_MAX;
            break;
        default:
            break;
    }
}

- (void)didPushN64Button:(PVN64Button)button forPlayer:(NSUInteger)player {
    padData[player][button] = 1;
}

- (void)didReleaseN64Button:(PVN64Button)button forPlayer:(NSUInteger)player {
    padData[player][button] = 0;
}

@end

@implementation MupenGameNXCore (Rumble)

- (BOOL)supportsRumble {
    return YES;
}

@end
