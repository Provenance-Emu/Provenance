/*
 Copyright (c) 2015, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "ATR800GameCore.h"

#import <PVSupport/OERingBuffer.h>
#import <PVSupport/DebugUtils.h>
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>

// ataria800 project includes
#include "afile.h"
#include "akey.h"
#include "antic.h"
#include "atari.h"
#include "cartridge.h"
#include "cassette.h"
#include "cfg.h"
#include "colours.h"
#include "colours_ntsc.h"
#include "config.h"
#include "devices.h"
#include "gtia.h"
#include "ide.h"
#include "input.h"
#include "memory.h"
#include "pbi.h"
#include "pia.h"
#include "platform.h"
#include "pokey.h"
#include "pokeysnd.h"
#include "rtime.h"
#include "sio.h"
#include "sound.h"
#include "statesav.h"
#include "sysrom.h"
#include "ui.h"

int UI_is_active = FALSE;
int UI_alt_function = -1;
int UI_n_atari_files_dir = 0;
int UI_n_saved_files_dir = 0;
char UI_atari_files_dir[UI_MAX_DIRECTORIES][FILENAME_MAX];
char UI_saved_files_dir[UI_MAX_DIRECTORIES][FILENAME_MAX];

typedef struct {
	int up;
	int down;
	int left;
	int right;
	int fire;
	int fire2;
	int start;
	int pause;
	int reset;
} ATR5200ControllerState;

@interface ATR800GameCore () <PVA8SystemResponderClient, PV5200SystemResponderClient>
{
	uint8_t *_videoBuffer;
    uint8_t *_soundBuffer;
	ATR5200ControllerState controllerStates[4];
}
- (void)renderToBuffer;
- (ATR5200ControllerState)controllerStateForPlayer:(NSUInteger)playerNum;
//int16_t convertSample(uint8_t);
@end

__weak static ATR800GameCore * _currentCore;

//void ATR800WriteSoundBuffer(uint8_t *buffer, unsigned int len);

@implementation ATR800GameCore

- (id)init
{
    if((self = [super init]))
    {
        _videoBuffer = calloc(1, Screen_WIDTH * Screen_HEIGHT * 4);
        _soundBuffer = calloc(1, 2048); // 4096 if stereo?
    }

    _currentCore = self;

    return self;
}

- (void)dealloc
{
	Atari800_Exit(false);
	free(_videoBuffer);
    free(_soundBuffer);
}

#pragma mark - Execution

// TODO: Make me real
-(NSString*)systemIdentifier {
    return @"com.provenance.5200";
}

-(NSString*)biosDirectoryPath {
    return self.BIOSPath;
}

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError *__autoreleasing *)error
{
    // Set the default palette (NTSC)
    NSString *palettePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"Default.act"];
    strcpy(COLOURS_NTSC_external.filename, [palettePath UTF8String]);
    COLOURS_NTSC_external.loaded = TRUE;

    Atari800_tv_mode = Atari800_TV_NTSC;

    /* It is necessary because of the CARTRIDGE_ColdStart (there must not be the
     registry-read value available at startup) */
    CARTRIDGE_main.type = CARTRIDGE_NONE;

    Colours_PreInitialise();

    if([[self systemIdentifier] isEqualToString:@"com.provenance.5200"])
    {
        // Set 5200.rom BIOS path
        char biosFileName[2048];
        NSString *biosDirectory = [self biosDirectoryPath];
        NSString *boisPath = [biosDirectory stringByAppendingPathComponent:@"5200.rom"];
        
        strcpy(biosFileName, [boisPath UTF8String]);
        
        SYSROM_SetPath(biosFileName, 1, SYSROM_5200);

        // Setup machine type
        Atari800_SetMachineType(Atari800_MACHINE_5200);
        MEMORY_ram_size = 16;
    }
    else if([[self systemIdentifier] isEqualToString:@"com.provenance.atari8bit"])
    {
        char basicFileName[2048], osbFileName[2048], xlFileName[2048];
        NSString *biosPath = [self biosDirectoryPath];
        strcpy(basicFileName, [[biosPath stringByAppendingPathComponent:@"ataribas.rom"] UTF8String]);
        strcpy(osbFileName, [[biosPath stringByAppendingPathComponent:@"atariosb.rom"] UTF8String]);
        strcpy(xlFileName, [[biosPath stringByAppendingPathComponent:@"atarixl.rom"] UTF8String]);

        SYSROM_SetPath(basicFileName, 1, SYSROM_BASIC_C);
        SYSROM_SetPath(osbFileName, 2, SYSROM_B_NTSC, SYSROM_800_CUSTOM);
        SYSROM_SetPath(xlFileName, 1, SYSROM_BB01R2);

        // Setup machine type as Atari 130XE
        Atari800_SetMachineType(Atari800_MACHINE_XLXE);
        MEMORY_ram_size = 128;
        Atari800_builtin_basic = TRUE;
        Atari800_keyboard_leds = FALSE;
        Atari800_f_keys = FALSE;
        Atari800_jumper = FALSE;
        Atari800_builtin_game = FALSE;
        Atari800_keyboard_detached = FALSE;

        // Disable on-screen disk activity indicator
        Screen_show_disk_led = FALSE;
    }

    int arg = 4;
    int *argc = &arg;
    char *argv[] = {"", "-sound", "-audio8", "-dsprate 44100"};
    
    if (
#if !defined(BASIC) && !defined(CURSES_BASIC)
        !Colours_Initialise(argc, argv) ||
#endif
        !Devices_Initialise(argc, argv)
        || !RTIME_Initialise(argc, argv)
#ifdef IDE
        || !IDE_Initialise(argc, argv)
#endif
        || !SIO_Initialise (argc, argv)
        || !CASSETTE_Initialise(argc, argv)
        || !PBI_Initialise(argc,argv)
#ifdef VOICEBOX
        || !VOICEBOX_Initialise(argc, argv)
#endif
#ifndef BASIC
        || !INPUT_Initialise(argc, argv)
#endif
#ifdef XEP80_EMULATION
        || !XEP80_Initialise(argc, argv)
#endif
#ifdef AF80
        || !AF80_Initialise(argc, argv)
#endif
#if SUPPORTS_CHANGE_VIDEOMODE
        || !VIDEOMODE_Initialise(argc, argv)
#endif
#ifndef DONT_DISPLAY
        /* Platform Specific Initialisation */
        || !PLATFORM_Initialise(argc, argv)
#endif
        || !Screen_Initialise(argc, argv)
        /* Initialise Custom Chips */
        || !ANTIC_Initialise(argc, argv)
        || !GTIA_Initialise(argc, argv)
        || !PIA_Initialise(argc, argv)
        || !POKEY_Initialise(argc, argv)
        ) {
        NSLog(@"Failed to initialize part of atari800");
        return NO;
    }

    if(!Atari800_InitialiseMachine()) {
        NSLog(@"** Failed to initialize machine");
        return NO;
    }

    // Open and try to automatically detect file type, not 100% accurate
    if(!AFILE_OpenFile([path UTF8String], 1, 1, FALSE))
    {
        NSLog(@"Failed to open file");
        NSDictionary *userInfo = @{
                                   NSLocalizedDescriptionKey: @"Failed to load game.",
                                   NSLocalizedFailureReasonErrorKey: @"atari800 failed to load ROM.",
                                   NSLocalizedRecoverySuggestionErrorKey: @"Check that file isn't corrupt and in format atari800 supports."
                                   };
        
        NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
                                                code:PVEmulatorCoreErrorCodeCouldNotLoadRom
                                            userInfo:userInfo];
        
        *error = newError;
        
        return NO;
    }

    // TODO - still need this?
    /* Install requested ROM cartridge */
    if (CARTRIDGE_main.type == CARTRIDGE_UNKNOWN)
    {
        CARTRIDGE_SetType(&CARTRIDGE_main, UI_SelectCartType(CARTRIDGE_main.size));
    }

    //POKEYSND_Init(POKEYSND_FREQ_17_EXACT, 44100, 1, POKEYSND_BIT16);

    return YES;
}

- (void)executeFrame
{
    if (self.controller1 || self.controller2) {
        [self pollControllers];
    }
    
    Atari800_Frame();

    unsigned int size = 44100 / (Atari800_tv_mode == Atari800_TV_NTSC ? 59.9 : 50) * 2;

    Sound_Callback(_soundBuffer, size);

    //NSLog(@"Sound_desired.channels %d frag_frames %d freq %d sample_size %d", Sound_desired.channels, Sound_desired.frag_frames, Sound_desired.freq, Sound_desired.sample_size);
    //NSLog(@"Sound_out.channels %d frag_frames %d freq %d sample_size %d", Sound_out.channels, Sound_out.frag_frames, Sound_out.freq, Sound_out.sample_size);

    [[self ringBufferAtIndex:0] write:_soundBuffer maxLength:size];

    [self renderToBuffer];
}

- (void)resetEmulation
{
	Atari800_Warmstart();
}

- (void)stopEmulation
{
    Atari800_Exit(false);
    [super stopEmulation];
}

- (NSTimeInterval)frameInterval
{
    return Atari800_tv_mode == Atari800_TV_NTSC ? Atari800_FPS_NTSC : Atari800_FPS_PAL;
}

#pragma mark - Video

- (const void *)videoBuffer
{
    return _videoBuffer;
}

- (CGSize)bufferSize
{
    return CGSizeMake(Screen_WIDTH, Screen_HEIGHT);
}

- (CGRect)screenRect
{
    return CGRectMake(24, 0, 336, 240);
//    return CGRectMake(24, 0, Screen_WIDTH, Screen_HEIGHT);
}

- (CGSize)aspectSize
{
    // TODO: fix PAR
    //return CGSizeMake(336 * (6.0 / 7.0), 240);
    return CGSizeMake(Screen_WIDTH, Screen_HEIGHT);
}

- (GLenum)pixelFormat
{
    return GL_BGRA;
}

- (GLenum)pixelType
{
    return GL_UNSIGNED_BYTE;
}

- (GLenum)internalPixelFormat
{
    return GL_RGBA;
}

#pragma mark - Audio

- (double)audioSampleRate
{
    return 44100;
}

- (NSUInteger)channelCount
{
    return 1;
}

#pragma mark - Save States
- (BOOL)saveStateToFileAtPath:(NSString *)fileName error:(NSError**)error {
    BOOL success = StateSav_SaveAtariState([fileName UTF8String], "wb", TRUE);
	if (!success) {
		NSDictionary *userInfo = @{
								   NSLocalizedDescriptionKey: @"Failed to save state.",
								   NSLocalizedFailureReasonErrorKey: @"ATR800 failed to create save state.",
								   NSLocalizedRecoverySuggestionErrorKey: @""
								   };

		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
												code:PVEmulatorCoreErrorCodeCouldNotSaveState
											userInfo:userInfo];

		*error = newError;
	}
	return success;
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    BOOL success = StateSav_SaveAtariState([fileName UTF8String], "wb", TRUE);
    if(block) block(success==YES, nil);
}

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName error:(NSError**)error {
    BOOL success = StateSav_ReadAtariState([fileName UTF8String], "rb");
	if (!success) {
		NSDictionary *userInfo = @{
								   NSLocalizedDescriptionKey: @"Failed to save state.",
								   NSLocalizedFailureReasonErrorKey: @"Core failed to load save state.",
								   NSLocalizedRecoverySuggestionErrorKey: @""
								   };

		NSError *newError = [NSError errorWithDomain:PVEmulatorCoreErrorDomain
												code:PVEmulatorCoreErrorCodeCouldNotLoadState
											userInfo:userInfo];

		*error = newError;
	}
	return success;
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    BOOL success = StateSav_ReadAtariState([fileName UTF8String], "rb");
    if(block) block(success==YES, nil);
}

#pragma mark - Input

- (void)mouseMovedAtPoint:(CGPoint)point
{

}

- (void)leftMouseDownAtPoint:(CGPoint)point
{

}

- (void)leftMouseUp
{

}

- (void)rightMouseDownAtPoint:(CGPoint)point
{

}

- (void)rightMouseUp
{

}

//- (void)keyDown:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
//{

//}

//- (void)keyUp:(unsigned short)keyHIDCode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers flags:(NSEventModifierFlags)modifierFlags
//{

//}

- (void)didPushA8Button:(PVA8Button)button forPlayer:(NSUInteger)player
{
    player--;

    switch (button)
    {
        case PVA8ButtonFire:
            controllerStates[player].fire = 1;
            break;
        case PVA8ButtonUp:
            controllerStates[player].up = 1;
            //INPUT_key_code = AKEY_UP ^ AKEY_CTRL;
            //INPUT_key_code = INPUT_STICK_FORWARD;
            break;
        case PVA8ButtonDown:
            controllerStates[player].down = 1;
            break;
        case PVA8ButtonLeft:
            controllerStates[player].left = 1;
            break;
        case PVA8ButtonRight:
            controllerStates[player].right = 1;
            break;
        default:
            break;
    }
}

- (void)didReleaseA8Button:(PVA8Button)button forPlayer:(NSUInteger)player
{
    player--;

    switch (button)
    {
        case PVA8ButtonFire:
            controllerStates[player].fire = 0;
            break;
        case PVA8ButtonUp:
            controllerStates[player].up = 0;
            //INPUT_key_code = AKEY_UP ^ AKEY_CTRL;
            //INPUT_key_code = INPUT_STICK_FORWARD;
            break;
        case PVA8ButtonDown:
            controllerStates[player].down = 0;
            break;
        case PVA8ButtonLeft:
            controllerStates[player].left = 0;
            break;
        case PVA8ButtonRight:
            controllerStates[player].right = 0;
            break;
        default:
            break;
    }
}

- (void)didPush5200Button:(PV5200Button)button forPlayer:(NSUInteger)player
{
	switch (button)
    {
		case PV5200ButtonFire1:
			controllerStates[player].fire = 1;
			break;
        case PV5200ButtonFire2:
            INPUT_key_shift = 1; //AKEY_SHFTCTRL
			break;
		case PV5200ButtonUp:
			controllerStates[player].up = 1;
            //INPUT_key_code = AKEY_UP ^ AKEY_CTRL;
            //INPUT_key_code = INPUT_STICK_FORWARD;
			break;
		case PV5200ButtonDown:
			controllerStates[player].down = 1;
			break;
		case PV5200ButtonLeft:
			controllerStates[player].left = 1;
			break;
		case PV5200ButtonRight:
			controllerStates[player].right = 1;
			break;
		case PV5200ButtonStart:
//			controllerStates[player].start = 1;
			INPUT_key_code = AKEY_5200_START;
			break;
        case PV5200ButtonPause:
//            controllerStates[player].pause = 1;
            INPUT_key_code = AKEY_5200_PAUSE;
            break;
        case PV5200ButtonReset:
//            controllerStates[player].reset = 1;
            INPUT_key_code = AKEY_5200_RESET;
            break;
        case PV5200ButtonNumber1:
            INPUT_key_code = AKEY_5200_1;
            break;
        case PV5200ButtonNumber2:
            INPUT_key_code = AKEY_5200_2;
            break;
        case PV5200ButtonNumber3:
            INPUT_key_code = AKEY_5200_3;
            break;
        case PV5200ButtonNumber4:
            INPUT_key_code = AKEY_5200_4;
            break;
        case PV5200ButtonNumber5:
            INPUT_key_code = AKEY_5200_5;
            break;
        case PV5200ButtonNumber6:
            INPUT_key_code = AKEY_5200_6;
            break;
        case PV5200ButtonNumber7:
            INPUT_key_code = AKEY_5200_7;
            break;
        case PV5200ButtonNumber8:
            INPUT_key_code = AKEY_5200_8;
            break;
        case PV5200ButtonNumber9:
            INPUT_key_code = AKEY_5200_9;
            break;
        case PV5200ButtonNumber0:
            INPUT_key_code = AKEY_5200_0;
            break;
        case PV5200ButtonAsterisk:
            INPUT_key_code = AKEY_5200_ASTERISK;
            break;
        case PV5200ButtonPound:
            INPUT_key_code = AKEY_5200_HASH;
            break;
		default:
			break;
	}
}

- (void)didRelease5200Button:(PV5200Button)button forPlayer:(NSUInteger)player
{
    switch (button)
    {
        case PV5200ButtonFire1:
            controllerStates[player].fire = 0;
            break;
        case PV5200ButtonFire2:
            INPUT_key_shift = 0;
            break;
        case PV5200ButtonUp:
            controllerStates[player].up = 0;
            //INPUT_key_code = 0xff;
            break;
        case PV5200ButtonDown:
            controllerStates[player].down = 0;
            break;
        case PV5200ButtonLeft:
            controllerStates[player].left = 0;
            break;
        case PV5200ButtonRight:
            controllerStates[player].right = 0;
            break;
        case PV5200ButtonStart:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonPause:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonReset:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber1:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber2:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber3:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber4:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber5:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber6:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber7:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber8:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber9:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonNumber0:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonAsterisk:
            INPUT_key_code = AKEY_NONE;
            break;
        case PV5200ButtonPound:
            INPUT_key_code = AKEY_NONE;
            break;
        default:
            break;
    }
}

- (void)pollControllers {
    for (NSInteger playerIndex = 0; playerIndex < 2; playerIndex++) {
        GCController *controller = nil;
        
        if (self.controller1 && playerIndex == 0) {
            controller = self.controller1;
        }
        else if (self.controller2 && playerIndex == 1)
        {
            controller = self.controller2;
        }
        
        if ([controller extendedGamepad]) {
            GCExtendedGamepad *gamepad     = [controller extendedGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            // DPAD
            controllerStates[playerIndex].up    = dpad.up.isPressed;
            controllerStates[playerIndex].down  = dpad.down.isPressed;
            controllerStates[playerIndex].left  = dpad.left.isPressed;
            controllerStates[playerIndex].right = dpad.right.isPressed;

            // Buttons
            // Fire 1
            controllerStates[playerIndex].fire = gamepad.buttonA.isPressed || gamepad.buttonX.isPressed;

            // Fire 2
            INPUT_key_shift = gamepad.buttonB.isPressed || gamepad.buttonY.isPressed;
            
            // The following buttons are on a shared bus. Only one at a time.
            // If none, state is reset. Since only one button can be registered
            // at a time, there has to be an preference of order.
            
            // Reset
            if (gamepad.leftTrigger.isPressed) {
                INPUT_key_code = AKEY_5200_START;
            }
            else if (gamepad.rightTrigger.isPressed) {
                INPUT_key_code = AKEY_5200_PAUSE;
            }
            else if (gamepad.leftShoulder.isPressed || gamepad.rightShoulder.isPressed) {
                INPUT_key_code = AKEY_5200_RESET;
            } else {
                INPUT_key_code = AKEY_NONE;
            }
        } else if ([controller gamepad]) {
            GCGamepad *gamepad = [controller gamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            // DPAD
            controllerStates[playerIndex].up    = dpad.up.isPressed;
            controllerStates[playerIndex].down  = dpad.down.isPressed;
            controllerStates[playerIndex].left  = dpad.left.isPressed;
            controllerStates[playerIndex].right = dpad.right.isPressed;
            
            // Buttons
            // Fire 1
            controllerStates[playerIndex].fire = gamepad.buttonA.isPressed || gamepad.buttonX.isPressed;
            
            // Fire 2
            INPUT_key_shift = gamepad.buttonB.isPressed;
            
            // The following buttons are on a shared bus. Only one at a time.
            // If none, state is reset. Since only one button can be registered
            // at a time, there has to be an preference of order.
            
            // Reset
            if (gamepad.leftShoulder.isPressed) {
                INPUT_key_code = AKEY_5200_START;
            }
            else if (gamepad.rightShoulder.isPressed) {
                INPUT_key_code = AKEY_5200_PAUSE;
            }
            else if (gamepad.buttonY.isPressed) {
                INPUT_key_code = AKEY_5200_RESET;
            } else {
                INPUT_key_code = AKEY_NONE;
            }
        }
#if TARGET_OS_TV
        else if ([controller microGamepad]) {
            GCMicroGamepad *gamepad = [controller microGamepad];
            GCControllerDirectionPad *dpad = [gamepad dpad];
            
            // DPAD
            controllerStates[playerIndex].up    = dpad.up.value > 0.5;
            controllerStates[playerIndex].down  = dpad.down.value > 0.5;
            controllerStates[playerIndex].left  = dpad.left.value > 0.5;
            controllerStates[playerIndex].right = dpad.right.value > 0.5;

            //Fire
            controllerStates[playerIndex].fire = gamepad.buttonA.isPressed;
            
            // Start
            INPUT_key_code = gamepad.buttonX.isPressed ? AKEY_5200_START : AKEY_NONE;
        }
#endif
    }
}


#pragma mark - Misc Helper Methods

- (void)renderToBuffer
{
    int i, j;
    UBYTE *source = (UBYTE *)(Screen_atari);
    UBYTE *destination = _videoBuffer;
    for (i = 0; i < Screen_HEIGHT; i++)
    {
        for (j = 0; j < Screen_WIDTH; j++)
        {
            UBYTE r,g,b;
            r = Colours_GetR(*source);
            g = Colours_GetG(*source);
            b = Colours_GetB(*source);
            *destination++ = b;
            *destination++ = g;
            *destination++ = r;
            *destination++ = 0xff;
            source++;
        }
        //		source += Screen_WIDTH - ATARI_VISIBLE_WIDTH;
    }
}

- (ATR5200ControllerState)controllerStateForPlayer:(NSUInteger)playerNum
{
    ATR5200ControllerState state = {0,0,0,0,0,0,0,0};
    if(playerNum < 4) {
        state = controllerStates[playerNum];
    }
    return state;
}

// Atari800 platform calls

int UI_SelectCartType(int k)
{
    NSLog(@"Cart size: %d", k);

    if([[_currentCore systemIdentifier] isEqualToString:@"com.provenance.atari8bit"])
    {
        // TODO: improve detection using MD5 lookup
        switch (k)
        {
            case 2:    return CARTRIDGE_STD_2;
            case 4:    return CARTRIDGE_STD_4;
            case 8:    return CARTRIDGE_STD_8;
            case 16:   return CARTRIDGE_STD_16;
            case 32:   return CARTRIDGE_XEGS_32;
            case 40:   return CARTRIDGE_BBSB_40;
            case 64:   return CARTRIDGE_XEGS_07_64;
            case 128:  return CARTRIDGE_XEGS_128;
            case 256:  return CARTRIDGE_XEGS_256;
            case 512:  return CARTRIDGE_XEGS_512;
            case 1024: return CARTRIDGE_ATMAX_1024;
            default:
                return CARTRIDGE_NONE;
        }
    }

    if([[_currentCore systemIdentifier] isEqualToString:@"com.provenance.5200"])
    {
        NSArray *One_Chip_16KB = @[@"a47fcb4eedab9418ea098bb431a407aa", // A.E. (Proto)
                                   @"45f8841269313736489180c8ec3e9588", // Activision Decathlon, The
                                   @"1913310b1e44ad7f3b90aeb16790a850", // Beamrider
                                   @"f8973db8dc272c2e5eb7b8dbb5c0cc3b", // BerZerk
                                   @"e0b47a17fa6cd9d6addc1961fca43414", // Blaster
                                   @"8123393ae9635f6bc15ddc3380b04328", // Blue Print
                                   @"3ff7707e25359c9bcb2326a5d8539852", // Choplifter!
                                   @"7c27d225a13e178610babf331a0759c0", // David Crane's Pitfall II - Lost Caverns
                                   @"2bb63d65efc8682bc4dfac0fd0a823be", // Final Legacy (Proto)
                                   @"f8f0e0a6dc2ffee41b2a2dd736cba4cd", // H.E.R.O.
                                   @"46264c86edf30666e28553bd08369b83", // Last Starfighter, The (Proto)
                                   @"1cd67468d123219201702eadaffd0275", // Meteorites
                                   @"84d88bcdeffee1ab880a5575c6aca45e", // Millipede (Proto)
                                   @"d859bff796625e980db1840f15dec4b5", // Miner 2049er Starring Bounty Bob
                                   @"296e5a3a9efd4f89531e9cf0259c903d", // Moon Patrol
                                   @"099706cedd068aced7313ffa371d7ec3", // Quest for Quintana Roo
                                   @"5dba5b478b7da9fd2c617e41fb5ccd31", // Robotron 2084
                                   @"802a11dfcba6229cc2f93f0f3aaeb3aa", // Space Shuttle - A Journey Into Space
                                   @"7dab86351fe78c2f529010a1ac83a4cf", // Super Pac-Man (Proto)
                                   @"496b6a002bc7d749c02014f7ec6c303c", // Tempest (Proto)
                                   @"33053f432f9c4ad38b5d02d1b485b5bd", // Track and Field (Proto)
                                   @"560b68b7f83077444a57ebe9f932905a", // Wizard of Wor
                                   @"dc45af8b0996cb6a94188b0be3be2e17"  // Zone Ranger
                                   ];

        NSArray *Two_Chip_16KB = @[@"bae7c1e5eb04e19ef8d0d0b5ce134332", // Astro Chase
                                   @"78ccbcbb6b4d17b749ebb012e4878008", // Atari PAM Diagnostics (v2.0)
                                   @"32a6d0de4f1728dee163eb2d4b3f49f1", // Atari PAM Diagnostics (v2.3)
                                   @"8576867c2cfc965cf152be0468f684a7", // Battlezone (Proto)
                                   @"a074a1ff0a16d1e034ee314b85fa41e9", // Buck Rogers - Planet of Zoom
                                   @"261702e8d9acbf45d44bb61fd8fa3e17", // Centipede
                                   @"5720423ebd7575941a1586466ba9beaf", // Congo Bongo
                                   @"1a64edff521608f9f4fa9d7bdb355087", // Countermeasure
                                   @"27d5f32b0d46d3d80773a2b505f95046", // Defender
                                   @"3abd0c057474bad46e45f3d4e96eecee", // Dig Dug
                                   @"14bd9a0423eafc3090333af916cfbce6", // Frisky Tom (Proto)
                                   @"d8636222c993ca71ca0904c8d89c4411", // Frogger II - Threeedeep!
                                   @"dacc0a82e8ee0c086971f9d9bac14127", // Gyruss
                                   @"936db7c08e6b4b902c585a529cb15fc5", // James Bond 007
                                   @"25cfdef5bf9b126166d5394ae74a32e7", // Joust
                                   @"bc748804f35728e98847da6cdaf241a7", // Jr. Pac-Man (Proto)
                                   @"834067fdce5d09b86741e41e7e491d6c", // Jungle Hunt
                                   @"796d2c22f8205fb0ce8f1ee67c8eb2ca", // Kangaroo
                                   @"d0a1654625dbdf3c6b8480c1ed17137f", // Looney Tunes Hotel (Proto)
                                   @"24348dd9287f54574ccc40ee40d24a86", // Microgammon SB (Proto)
                                   @"69d472a79f404e49ad2278df3c8a266e", // Miniature Golf (Proto)
                                   @"694897cc0d98fcf2f59eef788881f67d", // Montezuma's Revenge featuring Panama Joe
                                   @"ef9a920ffdf592546499738ee911fc1e", // Ms. Pac-Man
                                   @"f1a4d62d9ba965335fa13354a6264623", // Pac-Man
                                   @"fd0cbea6ad18194be0538844e3d7fdc9", // Pole Position
                                   @"dd4ae6add63452aafe7d4fa752cd78ca", // Popeye
                                   @"9b7d9d874a93332582f34d1420e0f574", // Qix
                                   @"a71bfb11676a4e4694af66e311721a1b", // RealSports Basketball (82-11-05) (Proto)
                                   @"022c47b525b058796841134bb5c75a18", // RealSports Football
                                   @"3074fad290298d56c67f82e8588c5a8b", // RealSports Soccer
                                   @"7e683e571cbe7c77f76a1648f906b932", // RealSports Tennis
                                   @"ddf7834a420f1eaae20a7a6255f80a99", // Road Runner (Proto)
                                   @"6e24e3519458c5cb95a7fd7711131f8d", // Space Dungeon
                                   @"993e3be7199ece5c3e03092e3b3c0d1d", // Sport Goofy (Proto)
                                   @"e2d3a3e52bb4e3f7e489acd9974d68e2", // Star Raiders
                                   @"c959b65be720a03b5479650a3af5a511", // Star Trek - Strategic Operations Simulator
                                   @"00beaa8405c7fb90d86be5bb1b01ea66", // Star Wars - The Arcade Game
                                   @"595703dc459cd51fed6e2a191c462969", // Stargate (Proto)
                                   @"4f6c58c28c41f31e3a1515fe1e5d15af"  // Xari Arena (Proto)
                                   ];

        // Set 5200 cart type to load based on size
        switch (k)
        {
            case 4: return CARTRIDGE_5200_4;
            case 8: return CARTRIDGE_5200_8;
            case 16:
                // Determine if 16KB cart is one-chip (NS_16) or two-chip (EE_16)
                if([One_Chip_16KB containsObject:[_currentCore.romMD5 lowercaseString]])
                    return CARTRIDGE_5200_NS_16;
                else
                    return CARTRIDGE_5200_EE_16;
            case 32: return CARTRIDGE_5200_32;
            case 40: return CARTRIDGE_5200_40; // Bounty Bob Strikes Back
            default:
                return CARTRIDGE_NONE;
        }
    }

    return CARTRIDGE_NONE;
}

void UI_Run(void)
{
}

int PLATFORM_Initialise(int *argc, char *argv[])
{
    Sound_Initialise(argc, argv);

    if (Sound_enabled) {
        /* Up to this point the Sound_enabled flag indicated that we _want_ to
         enable sound. From now on, the flag will indicate whether audio
         output is enabled and working. So, since the sound output was not
         yet initiated, we set the flag accordingly. */
        Sound_enabled = FALSE;
        /* Don't worry, Sound_Setup() will set Sound_enabled back to TRUE if
         it opens audio output successfully. But Sound_Setup() relies on the
         flag being set if and only if audio output is active. */
        if (Sound_Setup())
        /* Start sound if opening audio output was successful. */
            Sound_Continue();
    }

    //POKEYSND_stereo_enabled = TRUE;

    return TRUE;
}

int PLATFORM_Exit(int run_monitor)
{
    Sound_Exit();

    return FALSE;
}

int PLATFORM_PORT(int num)
{
    if(num < 4 && num >= 0) {
        ATR5200ControllerState state = [_currentCore controllerStateForPlayer:num];
        if(state.up == 1 && state.left == 1) {
            return INPUT_STICK_UL;
        }
        else if(state.up == 1 && state.right == 1) {
            return INPUT_STICK_UR;
        }
        else if(state.up == 1) {
            return INPUT_STICK_FORWARD;
        }
        else if(state.down == 1 && state.left == 1) {
            return INPUT_STICK_LL;
        }
        else if(state.down == 1 && state.right == 1) {
            return INPUT_STICK_LR;
        }
        else if(state.down == 1) {
            return INPUT_STICK_BACK;
        }
        else if(state.left == 1) {
            return INPUT_STICK_LEFT;
        }
        else if(state.right == 1) {
            return INPUT_STICK_RIGHT;
        }
        return INPUT_STICK_CENTRE;
    }
    return 0xff;
}

int PLATFORM_TRIG(int num)
{
    ATR5200ControllerState state = [_currentCore controllerStateForPlayer:num];

    return state.fire == 1 ? 0 : 1;
}

int PLATFORM_Keyboard(void)
{
    return 0;
}

void PLATFORM_DisplayScreen(void)
{
}

int PLATFORM_SoundSetup(Sound_setup_t *setup)
{
    int buffer_samples;

    if (setup->frag_frames == 0) {
        /* Set frag_frames automatically. */
        unsigned int val = setup->frag_frames = setup->freq / 50;
        unsigned int pow_val = 1;
        while (val >>= 1)
            pow_val <<= 1;
        if (pow_val < setup->frag_frames)
            pow_val <<= 1;
        setup->frag_frames = pow_val;
    }

    setup->sample_size = 2;

    buffer_samples = setup->frag_frames * setup->channels;
    setup->frag_frames = buffer_samples / setup->channels;

    return TRUE;
}

void PLATFORM_SoundExit(void){}

void PLATFORM_SoundPause(void){}

void PLATFORM_SoundContinue(void){}

void PLATFORM_SoundLock(void){}
void PLATFORM_SoundUnlock(void){}

//int16_t convertSample(uint8_t sample)
//{
//	float floatSample = (float)sample / 255;
//	return (int16_t)(floatSample * 65535 - 32768);
//}
//
//void ATR800WriteSoundBuffer(uint8_t *buffer, unsigned int len) {
//	int samples = len / sizeof(uint8_t);
//	NSUInteger newLength = len * sizeof(int16_t);
//	int16_t *newBuffer = malloc(len * sizeof(int16_t));
//	int16_t *dest = newBuffer;
//	uint8_t *source = buffer;
//	for(int i = 0; i < samples; i++) {
//		*dest = convertSample(*source);
//		dest++;
//		source++;
//	}
//    [[_currentCore ringBufferAtIndex:0] write:newBuffer maxLength:newLength];
//	free(newBuffer);
//}

@end
